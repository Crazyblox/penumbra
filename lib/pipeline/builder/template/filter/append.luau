--!nocheck
--!nolint
--/INLINE
local iRes0:vec =	iRes-vec(1,1)
local iRes0_div:vec=iRes0+vec(0,0,1)
local tStart0:vec =	vec(0,S.Actor_Res.y*(S.Actor_RenderNum-1))
local tRes1:vec =	S.Actor_Res
local tRes0:vec =	S.Actor_Res-vec(1,1)
local tEnd0:vec =	tStart0+tRes0
local IL_Start:f64 = tStart0.y % 2

-- Interlace data & function
local IL = { x = { ext = {tStart0.y % 2, 2}, int = {0, 2} }, y = { ext = {0, 2}, int = {0, 1} } }
local function InterlaceStep(): (f64, f64, f64, f64)
	-- X: Internal clock, external clock
	IL.x.int[1] += 1; IL.x.int[1] %= IL.x.int[2]
	IL.x.ext[1] += ( IL.x.int[1] == 0 ) and 1 or 0; IL.x.ext[1] %= IL.x.ext[2]
	-- Y: Internal clock, external clock
	IL.y.int[1] += 1; IL.y.int[1] %= IL.y.int[2]
	IL.y.ext[1] += ( IL.y.int[1] == 0 ) and 1 or 0; IL.y.ext[1] %= IL.y.ext[2]
	-- Return XY offsets, XY steps
	Sampler_IL_Offset = vec( -.333 + IL.y.ext[1] * .666,  -.333 + IL.x.ext[1] * .666 )
	return IL.x.ext[1], IL.y.ext[1], IL.x.ext[2], IL.y.ext[2]
end

for i = 1, IL_Start do
	InterlaceStep()
end

local function ShaderCall( T: f64, FB_Slice_In: buffer, FB_Slice_Out: buffer, c: f64, X_i: f64, Y_i: f64 )
	--vec3_buffer( Out, c, main( buffer_vec3( In, c ), vec( X_i, Y_i ), T ) )
	-- ^^^ For inputting previous shader as fragColor
	vec3_buffer( FB_Slice_Out, c, main( vec_0, vec( X_i, Y_i ), T ) )
	-- ^^^ For inputting blank white (More performance)
end

return function( T: f64, FB_Slice_In: buffer, FB_Slice_Out: buffer, InterlaceOn: boolean, FB_Full_New: Textures.Texture )
	FB_Full = FB_Full_New
	T = preprocess(T)
	-- Set steps & offsets
	local X_Off:f64, Y_Off:f64, X_Jump:f64, Y_Jump:f64 = 0, 0, 1, 1
	--if InterlaceOn then X_Off, Y_Off, X_Jump, Y_Jump = InterlaceStep() end
	-- Set XY byte increments
	local X_Jump_Bytes:f64 = u32B
	local Y_Jump_Bytes:f64 = iRes.x * u32B
	-- Set XY byte start offsets byte offsets
	local X_Off_Bytes:f64 = X_Jump_Bytes * X_Off
	local Y_Off_Bytes:f64 = Y_Jump_Bytes * Y_Off
	local c:f64 = X_Off_Bytes + Y_Off_Bytes
	-- X_Jump_Bytes always needs to increment; our 'c' cursor depends on this.
	X_Jump_Bytes += X_Jump_Bytes * (X_Jump-1)
	Y_Jump_Bytes *= (Y_Jump-1)
	for Y_i:f64 = tStart0.y + Y_Off, tEnd0.y, Y_Jump do
		--for Y_i:f64 = iRes0.y - tStart0.y - Y_Off, iRes0.y - tEnd0.y, -Y_Jump do
		for X_i:f64 = tStart0.x + X_Off, tEnd0.x, X_Jump do
			ShaderCall( T, FB_Slice_In, FB_Slice_Out, c, X_i, Y_i )
			c += X_Jump_Bytes
		end
		c += Y_Jump_Bytes
	end
end
