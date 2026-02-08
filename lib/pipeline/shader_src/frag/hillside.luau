--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mini: Hillside [Source: https://www.shadertoy.com/view/3fySDD]
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local p:vec = (fragCoord*2.-iRes)/iRes.y
	--//Quick noise pattern
	local n:f64 = (dot(fragCoord, vec(sin(fragCoord.y),sin(fragCoord.x))))%.1
	--//RGBA wave frequencies
	local f:vec = vec(.7,1,1.3)
	--//RGBA wave offsets
	local o:vec = vec(0,1,2)
	--//Distance to circle edge (radius of 1)
	local l:f64 = 1.-length(p)
	local fragMult:f64 = .1/max(l/.1,-l)
	--//Tanh for tonemapping
	--//https://www.shadertoy.com/view/ms3BD7
	--//https://mini.gmshaders.com/p/func-tanh
	local col:vec = vec(
		tanh(.2/abs(p.y+.3*cos(iTime+n+p.x*f.x+o.x))),
		tanh(.2/abs(p.y+.3*cos(iTime+n+p.x*f.y+o.y))),
		tanh(.2/abs(p.y+.3*cos(iTime+n+p.x*f.z+o.z)))
	)
	return col*vector.lerp(col,vec_1,.5)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
