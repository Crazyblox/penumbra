--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mandelbrot
local texture = Sampler_Linear
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local uv:vec = (vec(fragCoord.x/iRes.x,fragCoord.y/iRes.y)-vec(.5,.5))*2.
	uv *= vec(iRes.x/iRes.y,1.)
	local c:vec = uv * 0.8 + vec(-.5,0.) + vec( .2 * sin( iTime * .3 ), 0. )
	local z:vec = vec_0
	local it:f64 = 0.
	for i = 0, 39 do
		if dot(z,z) > 4 then break end
		z = vec( z.x * z.x - z.y * z.y, 2. * z.x * z.y ) + c
		it += 1.
	end
	local t:f64 = it / 40.
	return vec( t * t, t * .6, sqrt( t ) )
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
