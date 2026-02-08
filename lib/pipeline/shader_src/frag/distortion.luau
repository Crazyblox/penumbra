--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Distortion
local texture = Sampler_Linear
local blob1:vec = vec(127.1,311.7,0)
local blob2:vec = vec(269.5,183.3,0)
local blob3:vec = vec(419.2,317.9,0)
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local vec_noPreCalc:vec = vec(.5,.5)*(iTime*2.)+vec(.0,2.)
	local p_noPreCalc:vec = vec(.5,.5)-(vec(.5,.5)*vec(cos(vec_noPreCalc.x),cos(vec_noPreCalc.y)))
	for i = 1, 3 do
		p_noPreCalc = p_noPreCalc*p_noPreCalc*(vec(3,3)-vec(2,2)*p_noPreCalc)
	end
	local k_noPreCalc:f64 = 1 + 63 * pow(1.-p_noPreCalc.y,6.)

	local u:f64 = p_noPreCalc.x
	local v:f64 = p_noPreCalc.y

	local uv:vec = fragCoord/iRes.x 
	local p2:vec = uv * 24
	local i:vec = vector.floor(p2)
	local f:vec = vec(fract(p2.x),fract(p2.y))

	local a:f64 = 0
	local b:f64 = 0
	for y2 = -2, 2 do
		for x2 = -2, 2 do
			local g:vec = vec(x2,y2)
			local thing:vec = i + g
			local q:vec = vec(dot(thing,blob1),dot(thing,blob2),dot(thing,blob3))
			local o:vec = (vec(cos(q.x),cos(q.y),cos(q.z)))*43758.5453
			o = vec(fract(o.x),fract(o.y),fract(o.z))
			local o:vec = o*vec(u,u,1)
			local d:vec = g - f + vec(o.x,o.y)
			local w_noPreCalc:f64 = pow(1.-smoothstep(0.,1.414,length(d)),k_noPreCalc)
			a += o.z * w_noPreCalc
			b += w_noPreCalc
		end
	end

	local f:f64 = a/b
	local ratio:vec = f*((fragCoord-(iRes/2.))/iRes)
	ratio = vector.abs(ratio)

	return vec(sin(ratio.x),sin(ratio.y),sin(ratio.x+ratio.y))
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
