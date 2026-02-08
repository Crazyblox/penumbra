--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mini: Mosaic [Source: https://www.shadertoy.com/view/W33GRX]
local texture = Sampler_Linear
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	--//Resolution for scaling
	local r:vec = iRes
	--//Centered and scaled to fit vertically [-3, +3]
	local p:vec = 3. * ( fragCoord * 2. - r ) / r.y
	--//Doubled coordinates
	local v:vec = p + p + ( vec(iTime,iTime) + r ) * vec(
		cos(r.y+ceil(p.y+sin(p.y*5))),
		cos(r.x+ceil(p.x+sin(p.x*5)))
	)
	--//Set brightness using distance to points
	local l:f64 = length(vec(.9+sin(v.x),.9+sin(v.y)))
	--//Colour output
	return vec(
		tanh(.1* (cos(.6*p.x+.4*sin(v.y)+0)+1.) /l),
		tanh(.1* (cos(.6*p.x+.4*sin(v.y)+1)+1.) /l),
		tanh(.1* (cos(.6*p.x+.4*sin(v.y)+2)+1.) /l)
	)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
