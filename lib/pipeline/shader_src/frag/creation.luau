--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Creation [Source: https://www.shadertoy.com/view/XsXXDn]
local iChannel0: Textures.Texture =	Textures.Load.Base( {}, "abstract3" )
local texture = Sampler_Linear
local reinhardBurn:vec = vector.one * .225
local c = {0,0,0}
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local uv:vec = fragCoord/iRes
	local c = c
	c[1], c[2], c[3] = 0, 0, 0
	local l:f64, z:f64 = iTime, iTime
	for i = 1, 3 do
		local p:vec = fragCoord/iRes
		p=vec(p.x,p.y)
		local cuv:vec = p
		p -= vec(.5,.5)
		p *= vec(iRes.x/iRes.y,1,1)
		z += .07
		l = length(p)
		cuv += p / l * ( sin( z ) + 1 ) * abs( sin( l * 9 - z - z ) )
		c[i] = .01 / length( cuv - ( cuv // 1 ) - vec(.5,.5) )
	end
	fragColor = ( vec(c[1],c[2],c[3]) / l )
	fragColor /= fragColor + reinhardBurn
	return fragColor
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
