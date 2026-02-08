--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mini: Squircle [Source: https://www.shadertoy.com/view/WcGXRD]
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	--//Centered and scale to fit vertically
	local p:vec = (fragCoord*2.-iRes)/iRes.y
	--//Distance to squircle (squared-radius of 0.4)
	local d:f64 = length(p*p) - .4
	--//Cubed coordinates for rounded edges
	--//Rotate the light vector (11 is approximately 270 degrees)
	local l:f64 = dot(p*p*p,vec(cos(iTime),cos(iTime+11)))
	--//Tanh for soft edge filtering and divide for edge curvature
	l *= (1.-tanh(.5*d*iRes.y)) / (.51-d)
	--//Add lighting and coloring with tanh for tonemapping
	return vec( 
		tanh( l + 1. + p.x ) * .5 + .5,
		tanh( l + 1. + p.y ) * .5 + .5,
		tanh( l + 1. + -p.x ) * .5 + .5
	)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
