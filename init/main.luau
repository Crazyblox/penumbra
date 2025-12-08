--!strict
--!native
--[[ Penumbra - Render ]]
--[[ Requires ]]
local Settings =	require( `../lib/Settings` )
local Text =		require( `../lib/Text` )
local Textures =	require( `../lib/Textures/init` )
local VM =			require( `../plugin/vm` )
local Display =		require( `../plugin/display` )
local Input =		require( `../plugin/input` )
local Event =		require( `../plugin/event` )
local Task =		require( `../plugin/task` )
--[[ Locals ]]
local StatsOpen: boolean
local TrackFPS: boolean = false
local LastFrame: number = os.clock()
local Frames: { number } = {}
local Output = Display.New( Settings )
--[[ Functions ]]
-- Primitive wrapper that, over the course of a frame, stitches buffers from multiple render threads into 1.
local Framebuffer: buffer = Output.Framebuffer
local function CopyToBuffer( ... ) buffer.copy( Framebuffer, ... ) end

-- Used to validate if the whole text rendering system is working correctly
local TESTSTRING: string = ""
for i = 0x00, 0xFF do TESTSTRING ..= string.char(i) end
local Font_Texture: Textures.Texture = Textures.Load.Base( {}, "Font_Codepage437" )
local Font_DisplayRes: vector = vector.create(Settings.Display_Res.x//(Font_Texture.Width/0x100),Settings.Display_Res.y//Font_Texture.Height)

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
	-- RESYNC: Retains sync with RenderThreads based on parallel comms --
	Task.synchronize()
	for resync = 1, #{} + 1 do
		Task.desynchronize(); Task.synchronize()
	end
	-- Configure output text & draw to screen
	if StatsOpen then
		Text( Output.Framebuffer, `Penumbra - Luau Graphics` )
		Text( Output.Framebuffer, `FPS:{#Frames}, MS:{ ( ( os.clock() - LastFrame ) * 1000 ) // 1 }`, true, vector.create( 0, 1 ) )
		Text( Output.Framebuffer, `X:{ Settings.Display_Res.x }, Y:{ Settings.Display_Res.y }`, true, vector.create( 0, 2 ) )
	end
	Text( Output.Framebuffer, `{ StatsOpen and "<" or ">" }T`, true, vector.create( 0, StatsOpen and 3 or 0 ) )
	Output:Present()
	-- Used to measure frametimes
	LastFrame = os.clock()
end
-- Provides serial source of truth for elapsed time for when a frame begins processing.
local InitTime: number = os.clock()
local FrameTime: VM.SharedData = VM.RequireShared( "FrameTime", 8 ) -- Single fp64 value
local function SetTime()
	buffer.writef64( FrameTime.Buffer, 0, os.clock() - InitTime )
	FrameTime:SyncTo()
end
SetTime()
-- Toggler
StatsOpen = true
Input:KeyDown( "T", function() StatsOpen = not StatsOpen end )
-- VM_ReadyCheck: Called every time that a render thread reports that it's ready
local ReadyVMs: number = 0 -- How many VMs we have received the ready signal from.
local Render_VMs = {}
local function VM_ReadyCheck()
	ReadyVMs += 1
	-- Exit early if we're still waiting for VMs to be ready.
	if ReadyVMs ~= Settings.Render_Threads then return end
	-- Begin tracking FPS
	TrackFPS = true
	-- Hooks
	Event( SetTime, "Loop" ):Connect()				-- Serial hook to update global time for renderer.
	Event( DisplayImage, "Loop" ):Connect( true )	-- Hooks up DisplayImage to parallel 'Loop' event
	-- Send 'Run' message to all render threads.
	for Thread = 1, #Render_VMs do Render_VMs[ Thread ]:Send( "Run" ) end
	-- Time that system has 'begun'...
	InitTime = os.clock()
	SetTime()
	print( `{ VM.Process.Name }: Running`)
end
-- Return function called by Pajamas handler
return function()
	-- Hooks
	VM.Process:Bind( "Ready", VM_ReadyCheck )			-- Performs ready check per readied VM
	VM.Process:BindParallel( "Present", CopyToBuffer )	-- Receives & stitches buffers from render VMs (For presenting) 
	-- Setup render VMs
	print( `{ VM.Process.Name }: Readying { Settings.Render_Threads } render threads...` )
	for i: number = 1, Settings.Render_Threads do
		table.insert(
			Render_VMs,
			VM.New( `VM_Render_{ tostring( i ) }`, { Init = "render" }, { RenderNum = i } )
		)
	end
	-- Tell each RenderVM to run per frame to prevent script exhaustion
	for _, RenderVM in Render_VMs do
		RenderVM:Run()
		Task.wait()
	end
end