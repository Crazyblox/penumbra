--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Fractal Pyramid [Source: https://www.shadertoy.com/view/tsXBzS]
--[[ SHADER ]]--
local reinhardBurn:vec = vector.one * .225
local up_vector:vec = vec(0, 1, 0)
local const_ro:vec = vec(0, 0, -50)
local ro_xz:vec = vec(const_ro.x, const_ro.z)
local iTime_cos:f64 = 0
local iTime_sin:f64 = 0
local pal0:vec = vec(.2, .7, .9)
local pal1:vec = vec(1, 0, 1)
local rm_Count:f64 = 51 -- Default is 63
local rm_Map:f64 = 5 -- Default is 7
local rm_Div:f64 = ( 400 / 64 ) * ( rm_Count + 1 ) -- Default is 400

-- Preprocessor - main
local xz:vec, ro:vec, cf:vec, cs:vec, cu:vec, cf3:vec
-- Preprocessor - map
local c0:f64, c1:f64, s0:f64, s1:f64, iResY_Div_R:f64, iRes_Offset:vec = 0, 0, 0, 0, 1 / ( iRes.y * 1.25 ), iRes * .5

local function vec2_mat2( p: vec, c: f64, s: f64 )
	return vec(
		c * p.x + -s * p.y,
		s * p.x + c * p.y
	)
end

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local v2:vec = (fragCoord - iRes_Offset) * iResY_Div_R
	v2 = cf3 + v2.x*cs + v2.y*cu 
	v2 = normalize(v2 - ro)
	local d:f64 = 0
	local t:f64 = 0
	local R:vec, p:vec, q:vec
	-- Perform raymarching
	for rm:f64 = 0, rm_Count do
		p = ro + v2*t
		q = p
		-- Perform mapping
		for map:f64 = 0, rm_Map do
			-- Set XZ and rotate vec2 against mat2
			R = vec(q.x, q.z)
			R = vec2_mat2( R, c0, s0 )
			-- Perform 2nd mat2 rotation
			q = vec( R.x, q.y, R.y )
			R = vec2_mat2( q, c1, s1 )
			q = vec( abs(R.x), R.y, abs(q.z) )
			q -= vec(.5, 0, .5)
		end
		d = dot(vector.sign(q), q) * .1
		fragColor += vector.lerp(pal0, pal1, length(p) * .1) / (rm_Div * d) 
		t += d
	end
	fragColor *= vector.max(fragColor, vec_0)
	return fragColor / ( fragColor + reinhardBurn )
end

local function preprocess( iTime: f64 ): f64
	-- for main
	xz = vec2_mat2(ro_xz, cos(iTime), sin(iTime))
	ro = vec( xz.x, const_ro.y, xz.y )
	cf = normalize(-ro)
	cs = normalize(cross(cf, up_vector))
	cu = normalize(cross(cf, cs))
	cf3 = ro+cf*3
	-- for map
	iTime *= .2
	c0,s0 = cos(iTime), sin(iTime)
	c1,s1 = cos(iTime*1.89), sin(iTime*1.89)
	return iTime
end
