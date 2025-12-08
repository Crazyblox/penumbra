--!strict
--!native
--[[ Penumbra - Render ]]
--[[ Requires ]]
local Settings =	require( "../lib/Settings" )
local VM =			require( "../plugin/vm" )
local Event =		require( "../plugin/event" )
local Textures =	require( "../lib/Textures/init" )
local Pipeline =	require( "../lib/Pipeline/init" )
--[[ Locals ]]
local Program: Pipeline.Program
local PipelineThread: thread
local Received_Above, Received_Below = false, false
local Number_Above: number = math.clamp( Settings.Actor_RenderNum - 1, 1, Settings.Render_Threads )
local Number_Below: number = math.clamp( Settings.Actor_RenderNum + 1, 1, Settings.Render_Threads )
local VM_NoneAbove: boolean = VM.Process == VM.GetVMFromName( `VM_Render_{ Number_Above }` ) 
local VM_NoneBelow: boolean = VM.Process == VM.GetVMFromName( `VM_Render_{ Number_Below }` )
-- Buffers
local Out_Buffer: buffer = Pipeline.MakeBuffer.Buffer()
local Out_Buffer_C: number = buffer.len( Out_Buffer ) * ( Settings.Actor_RenderNum - 1 )
local In_Vector: {vector} = Pipeline.MakeBuffer.Vector()
-- Convert `{vector} -> buffer` via auto-floor & less math vs dot bitpacking (~42% faster)
local function VectorToBuffer( In: {vector}, Out: buffer )
	for c = 0, ( #In * 4 ) - 1, 4 do
		local RGB: vector = In[ ( c * 0.25 ) + 1 ] * 0xFF
		buffer.writeu8( Out,	c,		RGB.x )
		buffer.writeu8( Out,	c+1,	RGB.y )
		buffer.writeu8( Out,	c+2,	RGB.z )
	end
end
-- Checks if 'PipelineThread' can be resumed once all data is shared.
local function ResumeAfterSharing()
	if not ( Received_Above and Received_Below ) then return end
	Received_Above, Received_Below = false, false
	if coroutine.status( PipelineThread ) == "suspended" then
		coroutine.resume( PipelineThread )
	end
end
-- Called once by the Pajamas project handler
return function()
	-- Create program from pipeline
	Program = Pipeline.CreateProgram( require( `../lib/Pipeline/Profile` ) )
	-- Listens for signal to execute 'Run' function (Extras which can't be hooked here during require)
	VM.Process:Bind( "Run", function()
		-- Copies to 'External_Above'. Resumes program once both above and below are shared.
		VM.Process:BindParallel( "FromAbove", function( FB ) -- Copy to External_Above
			table.move( FB, 1, #FB, 1 + #Pipeline.Shared.External_Above - #FB, Pipeline.Shared.External_Above )
			FB = nil :: any			-- Mark for garbage collection
			Received_Above = true	-- Mark 1 of 2 flags
			ResumeAfterSharing()	-- Check if we can resume
		end)
		-- Copies to 'External_Below'. Resumes program once both above and below are shared.
		VM.Process:BindParallel( "FromBelow", function( FB ) -- Copy to External_Below
			table.move( FB, 1, #FB, 1, Pipeline.Shared.External_Below )
			FB = nil :: any			-- Mark for garbage collection
			Received_Below = true	-- Mark 1 of 2 flags
			ResumeAfterSharing()	-- Check if we can resume
		end)
		-- Executes the given shader program before returning to main.
		Event( function()
			PipelineThread = coroutine.running()
			local Result: {vector} = Program:Execute( In_Vector )
			VectorToBuffer( Result, Out_Buffer )
			VM.MainProcess:Send( "Present", Out_Buffer_C, Out_Buffer )
		end, "Loop" ):Connect( true )
	end)
	-- Send message to main; we're ready
	VM.MainProcess:Send( "Ready", Settings.Actor_RenderNum )
end