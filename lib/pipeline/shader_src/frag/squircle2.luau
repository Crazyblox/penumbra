--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mini: Squircle 2 [Source: https://www.shadertoy.com/view/WfySDD]
local function mat2(v:vec,a:f64,b:f64,c:f64,d:f64):vec return vec(a*v.x+b*v.y,c*v.x+d*v.y)end
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	--//Centered and scale to fit vertically
	local p:vec = (fragCoord*2.-iRes)/iRes.y
	--//Shortened time variable
	local t:f64 = iTime
	--//Rotate coordinates using sine tricks
	--//33 is approximately 90 degrees and 11 is approximately 270
	local c:vec = mat2( p,
		cos(iTime / 4. - sin(iTime) / 4. + 0),
		cos(iTime / 4. - sin(iTime) / 4. + 33),
		cos(iTime / 4. - sin(iTime) / 4. + 11),
		cos(iTime / 4. - sin(iTime) / 4. + 0)
	)
	--//Distance field waves for rotated squircle
	local l:f64 = cos(sqrt(length(c*c)) / 0.1- t)
	--//Generate color waves
	local w:vec = vec(
		sin(3. * length(c) + 2. * c.y + t + 6),
		sin(3. * length(c) + 2. * c.y + t + 1),
		sin(3. * length(c) + 2. * c.y + t + 2)
	)
	--//Color calculation with sine oscillations, scaled and tonemapped
	return vec(
		tanh((0.6 + 0.5 * w.x) / max(l/ 0.2, -l)),
		tanh((0.6 + 0.5 * w.y) / max(l/ 0.2, -l)),
		tanh((0.6 + 0.5 * w.z) / max(l/ 0.2, -l))
	)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
