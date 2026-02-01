--!strict
--!native

--[[
	Penumbra: main.luau
	
	This module is responsible for receiving and presenting framebuffer data
	from the render threads that it starts up based on the launch parameters given.
]]

local Text =	require( `./lib/text` )
local VM =		require( `./../plugin/process` )
local Display =	require( `./../plugin/display` )
local Input =	require( `./../plugin/input` )
local Event =	require( `./../plugin/event` )
local Task =	require( `./../plugin/task` )

-- Loads in configured settings and launch parameters
local Settings, Params = require(`./`)()

local StatsOpen: boolean
local TrackFPS: boolean = false
local LastFrame: number = os.clock()
local Frames: { number } = {}
local Output = Display.New( Settings :: {[string]: any} )

-- Buffer copy function that render threads call in order for the main thread to stitch all results together.
local Framebuffer: buffer = Output.Framebuffer
local function CopyToBuffer(Cursor: number, Slice: buffer)
	buffer.copy(Framebuffer, Cursor, Slice)
end

-- Frame presentation, text drawing, FPS tracking & frametime
local function DisplayImage()
	-- FPS Counter
	if not TrackFPS then return end
	local ThisFrameTime: number = os.clock()
	table.insert( Frames, ThisFrameTime )
	for Frame: number = #Frames, 1, -1 do
		if ThisFrameTime - 1 > Frames[ Frame ] then
			table.remove(Frames, Frame)
		end
	end
	
	-- Sync/Desync/Sync: Ensures that all render threads carry out their work first before displaying content.
	Task.synchronize()
	for resync = 1, #{} + 1 do
		Task.desynchronize(); Task.synchronize()
	end
	
	-- Configure output text & draw to screen
	debug.profilebegin("Draw text")
	if StatsOpen then
		Text( Output.Framebuffer, `Penumbra - Luau Graphics` )
		Text( Output.Framebuffer, `Thr:{Settings.Render_Threads}, FPS:{#Frames}, MS:{ ( ( os.clock() - LastFrame ) * 1000 ) // 1 }`, true, vector.create( 0, 1 ) )
		Text( Output.Framebuffer, `X:{ Settings.Display_Res.x }, Y:{ Settings.Display_Res.y }`, true, vector.create( 0, 2 ) )
	end
	Text( Output.Framebuffer, `{ StatsOpen and "<" or ">" }T`, true, vector.create( 0, StatsOpen and 3 or 0 ) )
	debug.profileend()
	Output:Present()
	
	-- Used to measure frametimes
	LastFrame = os.clock()
end

-- Writes elapsed time to a shared data entry where render threads can read from to render with identical timestamps.
local InitTime: number = os.clock()
local FrameTime: VM.SharedData = VM.RequireShared( "FrameTime", 8 ) -- Single fp64 value, 8 bytes.
local function SetTime()
	buffer.writef64( FrameTime.Buffer, 0, os.clock() - InitTime )
	FrameTime:SyncTo()
end
SetTime()

-- Toggler
StatsOpen = true
Input:KeyDown( "T", function() StatsOpen = not StatsOpen end )

-- Process_ReadyCheck: Called every time that a render thread reports that it's ready
local ReadyProcesses: number = 0 -- How many VMs we have received the ready signal from.
local Render_Processes: {VM.Process} = {}
local function Process_ReadyCheck()
	ReadyProcesses += 1
	
	-- Exit early if we're still waiting for VMs to be ready.
	if ( ReadyProcesses :: any ) ~= Settings.Render_Threads then
		return
	end
	
	-- Begin tracking FPS
	TrackFPS = true
	
	-- Hooks
	Event( SetTime, "Loop" ):Connect()				-- Serial hook to update global time for renderer.
	Event( DisplayImage, "Loop" ):Connect( true )	-- Parallel hook to execute DisplayImage, responsible for outputting the finished frame.
	
	-- Send 'Run' message to start all render threads.
	for Thread = 1, #Render_Processes do
		Render_Processes[ Thread ]:Send( "Run" )
	end
	
	-- Mark time that the render threads started running
	InitTime = os.clock()
	SetTime()
	print( `{ VM.Process.Name }: Running`)
end

-- Return function called by Pajamas handler
return function()
	-- Hooks
	VM.Process:Bind( "Ready", Process_ReadyCheck )		-- Performs ready check per readied VM
	VM.Process:BindParallel( "Present", CopyToBuffer )	-- Receives & stitches buffers from render VMs (For presenting) 
	
	-- Setup render VMs
	print( `{ VM.Process.Name }: Readying { Settings.Render_Threads } render threads...` )
	
	-- Build i-based params
	local iP = {}
	for k,v in Params do iP[k] = v end 
	for i: number = 1, ( Settings.Render_Threads :: any ) :: number do
		iP.i[6] = i
		iP.i[1] = "render"
		table.insert(
			Render_Processes,
			VM.New( `Process_Render_{ tostring( i ) }`, iP.i )
		)
	end
	
	-- Tell each RenderVM to run per frame to prevent script exhaustion
	for _, RenderProcess in Render_Processes do
		RenderProcess:Run()
		Task.wait()
	end
end
