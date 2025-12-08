--!strict
--!native
--[[ Requires ]]
local Settings =	require( "../Settings" )
local Deepfreeze =	require( "../../lib/Deepfreeze" )
local VM =			require( "../../plugin/vm" )
local Task =		require( "../../plugin/task" )
-- Types/Export
local Types =			require( "./Types" )
export type Shader = 	Types.Shader
export type Swapchain = Types.Swapchain
export type Program = 	Types.Program
--[[ Locals ]]
local Pipeline = {}
local SyncList = { "Sync" }
--[[ Functions ]]
-- Functions for generating types of buffers; all initialized to opaque/white when applicable
local MakeBuffer = table.freeze( {
	Vector = function(): {vector} return table.create( Settings.Actor_Res.x * Settings.Actor_Res.y, vector.one ) end,
	Buffer = function(): buffer
		local NewBuffer: buffer = buffer.create( Settings.Actor_Res.x * Settings.Actor_Res.y * 4 )
		buffer.fill( NewBuffer, 0, 0xFF )
		return NewBuffer
	end
} )
Pipeline.MakeBuffer = MakeBuffer
-- Shared: Localised framebuffer slices from other render threads which get updated thru './init/render.luau' after SyncFunction is called.
Pipeline.Shared = table.freeze( {
	External_Above = table.create( Settings.Actor_Res.x * Settings.Actor_Res.y, vector.zero ),
	External_Below = table.create( Settings.Actor_Res.x * Settings.Actor_Res.y, vector.zero ),
	Send_Above = table.create( Settings.Actor_Res.x * 2, vector.zero ),
	Send_Below = table.create( Settings.Actor_Res.x * 2, vector.zero )
} )
-- Kernel indexes; used by some sync-based filters.
Pipeline.Kernels = require( `./Kernels` )
-- SyncFunction
local VM_IntendedNeighbor_Above: number = math.clamp( Settings.Actor_RenderNum - 1, 1, Settings.Render_Threads )
local VM_IntendedNeighbor_Below: number = math.clamp( Settings.Actor_RenderNum + 1, 1, Settings.Render_Threads )
local VM_AboveNeighbor = VM.GetVMFromName( `VM_Render_{ VM_IntendedNeighbor_Above }` )
local VM_BelowNeighbor = VM.GetVMFromName( `VM_Render_{ VM_IntendedNeighbor_Below }` )
local VM_NoneAbove: boolean = VM.Process == VM_AboveNeighbor 
local VM_NoneBelow: boolean = VM.Process == VM_BelowNeighbor
local SyncFunction = function( T: number, In: {vector}, Out: {vector} )
	debug.profilebegin("Sync - Send")
	-- Copy # of own framebuffer into all of Send_Below.
	-- Applies #Send_Below offset to cursor so lower portion is accurately selected.
	table.move( In, 1 + Settings.Actor_Res.x * ( Settings.Actor_Res.y - 2 ), #Pipeline.Shared.Send_Below, 1, Pipeline.Shared.Send_Below )
	-- Copy # of own framebuffer into all of Send_Above
	table.move( In, 1, #Pipeline.Shared.Send_Above, 1, Pipeline.Shared.Send_Above )
	-- Send data
	VM_AboveNeighbor:Send( VM_NoneAbove and "FromAbove" or "FromBelow", Pipeline.Shared.Send_Above )
	VM_BelowNeighbor:Send( VM_NoneBelow and "FromBelow" or "FromAbove", Pipeline.Shared.Send_Below )
	debug.profileend()
	-- Yields thread running function; ensures that sync occurs before resuming thread
	coroutine.yield( coroutine.running() )
	return In
end
-- ExecuteProgram: Executes a program (Collection of shaders) before returning output data. 
local PipelineThread: thread
local ReceivedAbove, ReceivedBelow = false, false
local Shared_T: VM.SharedData = VM.RequireShared( "FrameTime" )
local function ExecuteProgram( self: Program, In: {vector}? ): {vector}
	-- Set thread
	PipelineThread = coroutine.running()
	-- Sync & read from global FrameTime 
	Shared_T:SyncFrom()						
	local T: number = buffer.readf64( Shared_T.Buffer, 0 )
	-- Grab Read/Write Swapchain buffers
	local Read: {vector}, Write: {vector} =	self.Swapchain:Swap()
	-- Execute shaders in order
	for iShader: number = 1, #self.Shaders do		
		Read, Write = self.Swapchain:Swap(
			self.Shaders[ iShader ]( T, Read, Write )
		)
	end
	-- Program complete; return resulting data
	return Read								
end
-- Iterates through given profile to create shader array, inserting steps like 'Sync' along the way if needed.
local function FetchShaders( Profile: {string} ): {Shader}
	local Shaders: {Shader} = {}
	local HasTonemapper: boolean = false
	for _, Filter: string in Profile do
		local ShaderDir: string = string.split( Filter, `/` )[1]
		if table.find( SyncList, ShaderDir ) then table.insert( Shaders, SyncFunction ) end
		table.insert( Shaders, require( `./Shaders/{ Filter }` ) :: any )
		HasTonemapper = ShaderDir == "Tone" or HasTonemapper
	end
	if not HasTonemapper then warn("No tonemapper provided; unbound values may cause integer under/overflow in output") end
	return table.freeze( Shaders )
end
-- Called by './init/render.luau' prior to each successive shader call
-- Providing 'ReadFrom' allows the calling script to provide a starting buffer.
local function Swap( self: Swapchain, ReadFrom: {vector}? ): ( {vector}, {vector} )
	self.Bool = if ReadFrom then self.Bool else not self.Bool
	return ReadFrom or self.Buffers[ self.Bool ], self.Buffers[ not self.Bool ]
end
-- Makes Swapchain
local function MakeSwap(): Swapchain
	return {
		Bool = false,
		Swap = Swap,
		Buffers = table.freeze({[true]=MakeBuffer.Vector(),[false]=MakeBuffer.Vector()})
	} :: Swapchain
end
-- Creates a program with the given shader profile
local ProgramIDsCreated: number = 0
function Pipeline.CreateProgram( Profile: {string} ): Program
	local NewProgram: Program = {
		Name = `Program`,
		Execute = ExecuteProgram,
		Swapchain = MakeSwap(),
		Shaders = FetchShaders( Profile )
	} 
	return NewProgram 
end
-- Return
return Pipeline