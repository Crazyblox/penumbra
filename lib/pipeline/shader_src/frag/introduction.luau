--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Shader Art Coding Introduction [Source: https://www.shadertoy.com/view/mtyGWy]
local e:f64 = 2.71828183
local a:vec,b:vec,c:vec,d:vec = vec(.5,.5,.5),vec(.5,.5,.5),vec(1,1,1),vec(.263,.416,.557)
local function palette( t:f64 ):vec
	local tau_ctd:vec = 6.28318 * (c*t+d)
	return a + b * vec(cos(tau_ctd.x),cos(tau_ctd.y),cos(tau_ctd.z)) 
end
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local uv:vec = ( fragCoord * 2 - iRes ) / iRes.y
	local uv0:vec = uv
	local finalColor:vec = vec_0
	for i = 0, 3 do
		uv *= 1.5
		uv -= uv // 1
		uv -= vec_0_5
		local d:f64 = length(uv) * (e^-length(uv0))
		local col:vec = palette(length(uv0) + i * .4 + iTime * .4 )
		d = sin( d * 8 + iTime ) / 8
		d = abs(d)
		d = pow( 0.01 / d, 1.2 )
		finalColor += col * d
	end
	return vector.min( finalColor, vec_1 )	
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
