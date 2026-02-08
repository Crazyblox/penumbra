--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mini: Nova [Source: https://www.shadertoy.com/view/WfGSRD]
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	--//Horizontally centered and scaled coordinates
	local p:vec = (fragCoord*2.-(iRes.x*vec(1,1)))/iRes.y
	--//Distance to circle edge (radius of 1)
	local l:f64 = 1.-length(p)
	local fragMult:f64 = .1/max(l/.1,-l)
	fragColor = vec(
		tanh( ( 1.2 + sin( p.x + iTime ) ) * fragMult ),
		tanh( ( 1.2 + sin( p.x + iTime + 2 ) ) * fragMult ),
		tanh( ( 1.2 + sin( p.x + iTime + 4 ) ) * fragMult )
	)
	return fragColor
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
