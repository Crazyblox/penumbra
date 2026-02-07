--!strict
--!native
--[[ Requires ]]
local Settings = 	require(`../`)()
local Deepfreeze =	require( `./deepfreeze` )
local VM =			require( `../../plugin/process` )
local Task =		require( `../../plugin/task` )
local Textures =	require( `./textures` )

-- Types/Export
local Types =			require( "@self/types" )
export type Shader = 	Types.Shader
export type ShaderModule = Types.ShaderModule
export type Swapchain = Types.Swapchain
export type Program = 	Types.Program

--[[ Locals ]]
local Pipeline = {}
local SyncList = { "Sync" }

--[[ Functions ]]
-- Functions for generating types of buffers; all initialized to opaque/white when applicable
Pipeline.Buffers = table.freeze( {
	RGBAu8_Slice = function(): buffer
		local b = buffer.create( Settings.Actor_Res.x * Settings.Actor_Res.y * 4)
		buffer.fill( b, 0, 0xFF )
		return b
	end,
	RGBAu8_Display = function(): buffer
		local b = buffer.create( Settings.Display_Res.x * Settings.Display_Res.y * 4)
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

local PipelineExecutionThread: thread = coroutine.running()
local FB_Slice_Count: number = Pipeline.Buffers.RGBAu8_Length()
local FB_Full_Slice_Cursor: number = FB_Slice_Count * (Settings.Actor_RenderNum-1)
local FB_Full_Sync: Textures.Texture
local Shared_T: VM.SharedData = VM.RequireShared("FrameTime")
local Sync = {
	Slice = function(FB_Slice: buffer, Present: boolean)
		VM.MainProcess:Send(
			if Present == true then "FB_Slice_Sync_Present" else "FB_Slice_Sync",
			FB_Full_Slice_Cursor,
			FB_Slice 
		)
		-- Gets resumed by 'main.luau' invoking Sync.Full
		coroutine.yield(PipelineExecutionThread)
	end,
	-- Update full framebuffer & resume PipelineExecutionThread
	Full = function(FB_Full_In: buffer)
		-- Assign full framebuffer and make texture from it
		FB_Full_Sync = Textures.Load.FromBuffer( "FB", FB_Full_In, Settings.Display_Res )
		-- Resume execution of shader program
		coroutine.resume(PipelineExecutionThread)
	end
}
Sync.Full(Pipeline.Buffers.RGBAu8_Display())
Pipeline.Sync = Sync

local FB_Full_Start: Textures.Texture = Textures.Load.FromBuffer(
	"FB",
	Pipeline.Buffers.RGBAu8_Display(),
	Settings.Display_Res
)
-- Set to black, but provide full alpha
for c = 0, buffer.len(FB_Full_Start.Buffer)-1, 4 do
	buffer.writeu32(FB_Full_Start.Buffer, c, 0x000000FF)
end

-- ExecuteProgram: Executes a program (Collection of shaders) before returning output data.
local FB_Slice_Read: buffer = Pipeline.Buffers.RGBAu8_Slice()
local function ExecuteProgram( self: Program, In: buffer? )
	-- Parallel is a MUST for performance, this affirms for sanity.
	Task.desynchronize()
	-- Grab the thread by which this program is being executed.
	PipelineExecutionThread = coroutine.running()
	-- Update then read frametime from shared buffer, set by main.luau
	local T: number = buffer.readf64( Shared_T:SyncFrom().Buffer, 0 )
	-- Localise starting sliced framebuffer as it will be updated after executing a shader.
	local FB_Slice_Read: buffer = FB_Slice_Read
	-- Execute shaders in order
	for i: number, Shader: Shader in self.Shaders do
		Shader.Run(
			T,									-- Shader deltaTime; Value is provided by main.luau via Process.SharedData .
			FB_Slice_Read,						-- For start of program, provides a blank or explicitly-provided starting sliced framebuffer.
			Shader.FB_Slice_Write,				-- The shaders own sliced framebuffer that will be written to.
			true,								-- Tells shader that, if supported, we would prefer to use 2D interlacing for performance.
			if i == 1 then FB_Full_Start		-- For start of program, provides a blank or explicitly-provided full framebuffer .
			else FB_Full_Sync					-- For sub-sequent shaders, provide the synchronized full framebuffer from main.luau.
		)
		Sync.Slice(
			Shader.FB_Slice_Write,				-- Passes shaders own sliced framebuffer which was written to, for syncing with full framebuffer.
			i >= #self.Shaders					-- Lets Sync.Slice decide if PipelineExecutionThread needs to yield for main.luau to perform syncing.
		)
		FB_Slice_Read = Shader.FB_Slice_Write	-- Pass Assign shader's FB_Slice_Write to FB_Slice_Read
	end					
end

-- Iterates through given profile to create shader array.
local function FetchShaders(Profile: {[number]: string}): {[number]: Shader}
	local Shaders: {Shader} = {}
	for _, Filter: string in Profile do
		local Shader_New = {
			Run = require( `@self/shaders/{ Filter }` ) :: ShaderModule,
			FB_Slice_Write = Pipeline.Buffers.RGBAu8_Slice()
		}
		table.freeze( Shader_New )
		table.insert( Shaders, Shader_New :: Shader )
	end
	return table.freeze( Shaders )
end

-- Creates a program with the given shader profile
local ProgramIDsCreated: number = 0
function Pipeline.CreateProgram( Profile: {string} ): Program
	local NewProgram: Program = {
		Name = `Program`,
		Execute = ExecuteProgram,
		WriteBuffer = Pipeline.Buffers.RGBAu8_Slice(),
		Shaders = FetchShaders( Profile )
	} 
	return NewProgram 
end

return Pipeline
