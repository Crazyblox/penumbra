--!strict
--!native
--[[ Requires ]]
local Settings = 	require(`../`)()
local Deepfreeze =	require( `./deepfreeze` )
local VM =			require( `../../plugin/process` )
local Task =		require( `../../plugin/task` )

-- Types/Export
local Types =			require( "@self/types" )
export type Shader = 	Types.Shader
export type Swapchain = Types.Swapchain
export type Program = 	Types.Program

--[[ Locals ]]
local Pipeline = {}
local SyncList = { "Sync" }

--[[ Functions ]]
-- Functions for generating types of buffers; all initialized to opaque/white when applicable
local Buffers = table.freeze( {
	RGBAu8_Make = function(): buffer
		local b = buffer.create( Settings.Actor_Res.x * Settings.Actor_Res.y * 4)
		buffer.fill( b, 0, 0xFF )
		return b
	end,
	RGBAu8_Length = function()
		return Settings.Actor_Res.x * Settings.Actor_Res.y * 4
	end,
	Vector = function(): {vector}
		return table.create( Settings.Actor_Res.x * Settings.Actor_Res.y, vector.one )
	end
} )
Pipeline.Buffers = Buffers

-- Shared: Localised framebuffer slices from other render threads which get updated thru './init/render.luau' after SyncFunction is called.
Pipeline.Shared = table.freeze( {
	External_Above = Pipeline.Buffers.RGBAu8_Make( Settings.Actor_Res.x * Settings.Actor_Res.y ),
	External_Below = Pipeline.Buffers.RGBAu8_Make( Settings.Actor_Res.x * Settings.Actor_Res.y )
} )

-- Kernel indexes; used by some sync-based filters.
--Pipeline.Kernels = require( `@self/kernels` )

-- SyncFunction
local Process_IntendedNeighbor_Above: number = math.clamp( Settings.Actor_RenderNum - 1, 1, Settings.Render_Threads )
local Process_IntendedNeighbor_Below: number = math.clamp( Settings.Actor_RenderNum + 1, 1, Settings.Render_Threads )
local Process_AboveNeighbor: VM.Process = VM.GetProcessFromName( `Process_Render_{ Process_IntendedNeighbor_Above }` )
local Process_BelowNeighbor: VM.Process = VM.GetProcessFromName( `Process_Render_{ Process_IntendedNeighbor_Below }` )
local Process_NoneAbove: boolean = VM.Process == Process_AboveNeighbor 
local Process_NoneBelow: boolean = VM.Process == Process_BelowNeighbor

-- !! UNSUPPORTED: Pending global buffer sharing revamp
local SyncFunction = function( T: number, In: buffer, Out: buffer )
	-- Send this render thread's framebuffer data to other threads.
	Process_AboveNeighbor:Send( Process_NoneAbove and "FromAbove" or "FromBelow", In )
	Process_BelowNeighbor:Send( Process_NoneBelow and "FromBelow" or "FromAbove", In )
	-- Yields thread running function; the render worker now waits for word from the others via 'main.luau'
	coroutine.yield( coroutine.running() )
	return In
end

-- ExecuteProgram: Executes a program (Collection of shaders) before returning output data. 
local PipelineThread: thread
local ReceivedAbove, ReceivedBelow = false, false
local Shared_T: VM.SharedData = VM.RequireShared( "FrameTime" )
local function ExecuteProgram( self: Program, In: buffer? ): buffer
	-- Set thread
	PipelineThread = coroutine.running()
	-- Sync & read from global FrameTime 
	Shared_T:SyncFrom()						
	local T: number = buffer.readf64( Shared_T.Buffer, 0 )
	-- Grab Read/Write Swapchain buffers
	local Read: buffer, Write: buffer =	self.Swapchain:Swap()
	-- Execute shaders in order
	for iShader: number = 1, #self.Shaders do		
		Read, Write = self.Swapchain:Swap(
			self.Shaders[ iShader ]( T, Read, Write, true )
		)
	end
	-- Program complete; return the finishing buffer
	return Read								
end

-- Iterates through given profile to create shader array.
local function FetchShaders( Profile: {string} ): {Shader}
	local Shaders: {Shader} = {}
	for _, Filter: string in Profile do
		table.insert( Shaders, require( `@self/shaders/{ Filter }` ) :: Shader )
	end
	return table.freeze( Shaders )
end

-- Called by 'render.luau' prior to each successive shader call
-- Providing 'ReadFrom' allows the caller to provide a starting buffer.
local function Swap( self: Swapchain, ReadFrom: buffer? ): ( buffer, buffer )
	self.Bool = if ReadFrom then self.Bool else not self.Bool
	return ReadFrom or self.Buffers[ self.Bool ], self.Buffers[ not self.Bool ]
end

-- Makes swapchain
local function MakeSwap(): Swapchain
	return {
		Bool = false,
		Swap = Swap,
		Buffers = table.freeze({
			[true] = Buffers.RGBAu8_Make(),
			[false] = Buffers.RGBAu8_Make()
		})
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

return Pipeline
