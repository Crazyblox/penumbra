--!strict
--!native

--[[
	Penumbra: render.luau
	
	This module is responsible for carrying out partial (Or complete, if only 1 worker was specified)
	rendering of the specified shaders, handled via pipeline.luau.
	
	When 1 shader pass completes, the render thread then sends the data off to
	the main thread 'main.luau', to be stitched together before sending back to
	the render thread, and present the frame if it was the final shader in the list.
]]

local Settings =	require(`./`)()
local Pipeline =	require(`./lib/pipeline`)
local VM =			require(`../plugin/process`)
local Event =		require(`../plugin/event`)

-- Called via the init module if path launch parameter resolves to this module.
return function()
	-- Ask 'pipeline/init.luau' to make a shader program for us via what 'profile.luau' returns.
	local Program: Pipeline.Program = Pipeline.CreateProgram( require( `./lib/pipeline/profile` ) )
	-- When told to run by the main process, hook the program execution to the parallel loop event
	VM.ThisProcess:Bind("Run", function() Event(function() Program:Execute() end, "Loop"):Connect() end)
	-- Tells 'main.luau' that this render thread is ready.
	VM.MainProcess:Send("Ready", Settings.Actor_RenderNum)
	-- Hook full framebuffer sync broadcast to 'pipeline/init.luau'
	VM.Listen("FB_Full_Sync"):ConnectParallel(Pipeline.Sync.Full)
end
