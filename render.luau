--!strict
--!native

--[[
	Penumbra: render.luau
	
	This module is responsible for carrying out partial (Or complete, if only 1 worker was specified)
	rendering of the specified shaders, handled via pipeline.luau.
	
	Once rendering has completed, the render thread then sends the data off to
	the main thread which is running 'main.luau', where it will stitch together
	all resulting data sent by the render threads.
]]

local VM =			require( `./../plugin/process` )
local Event =		require( `./../plugin/event` )
local Textures =	require( `./lib/textures` )
local Pipeline =	require( `./lib/pipeline` )

-- Loads in configured settings and launch parameters
local Settings, Params = require(`./`)()

local Program: Pipeline.Program
local PipelineThread: thread
local Received_Above: boolean = false
local Received_Below: boolean = false
local Number_Above: number = math.clamp( Settings.Actor_RenderNum - 1, 1, Settings.Render_Threads )
local Number_Below: number = math.clamp( Settings.Actor_RenderNum + 1, 1, Settings.Render_Threads )
local Process_NoneAbove: boolean = VM.Process == VM.GetProcessFromName( `Process_Render_{ Number_Above }` ) 
local Process_NoneBelow: boolean = VM.Process == VM.GetProcessFromName( `Process_Render_{ Number_Below }` )

-- Get correct buffer offset so that when we send to the worker running 'main.luau', it can copy into the correct position
local Buffer_Cursor_Offset: number = Pipeline.Buffers.RGBAu8_Length() * ( Settings.Actor_RenderNum - 1 )

-- !! UNSUPPORTED: Called by FromAbove/FromBelow to see if the thread executing the shader program can resume.
local function ResumeAfterSharing()
	if not ( Received_Above and Received_Below ) then return end
	Received_Above, Received_Below = false, false
	if coroutine.status( PipelineThread ) == "suspended" then
		coroutine.resume( PipelineThread )
	end
end

-- Called via the init module if path launch parameter resolves to this module.
return function()
	-- Ask 'pipeline.luau' to make a shader program for us via what 'profile.luau' returns.
	Program = Pipeline.CreateProgram( require( `./lib/pipeline/profile` ) )
	-- Listens for signal to execute 'Run' function (Extras which can't be hooked here during require)
	VM.Process:Bind( "Run", function()
		-- FromAbove/FromBelow: Accepts buffer data from said relatively positioned render thread (Or itself)
		VM.Process:BindParallel( "FromAbove", function( Data: buffer ) 
			buffer.copy( Pipeline.Shared.External_Above, 0, Data )
			Data = nil :: any; Received_Above = true; ResumeAfterSharing()	
		end)
		VM.Process:BindParallel( "FromBelow", function( Data: buffer )
			buffer.copy( Pipeline.Shared.External_Above, 0, Data )
			Data = nil :: any; Received_Below = true; ResumeAfterSharing()
		end)
		-- Hook the execution of the created program to the 'Loop' event.
		Event( function()
			PipelineThread = coroutine.running()
			local Result: buffer = Program:Execute()
			VM.MainProcess:Send( "Present", Buffer_Cursor_Offset, Result )
		end, "Loop" ):Connect( true )
	end)
	-- Tells 'main.luau' that this render thread is ready.
	VM.MainProcess:Send( "Ready", Settings.Actor_RenderNum )
end
