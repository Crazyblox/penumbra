--!nocheck
--!nolint
--/INLINE
local iChannel0: Textures.Texture = Textures.Load.Base( {}, "rustymetal" )
local texture = Sampler_Nearest -- Sampler_Nearest_IL, Sampler_Linear

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	-- Gradient - Sourced from [https://www.shadertoy.com/new]
	local grad:vec = ( fragCoord / iResolution ) + vec_1 * iTime
	grad = vec(cos(grad.x),cos(grad.y+2.),cos(grad.x+4.)) * .5 + vec_0_5
	-- Sample texture
	local uv:vec = ( fragCoord + vec(.5,.5) ) / iResolution
	local sample:vec = texture( iChannel0, uv + vec( sin(iTime) * .5, cos(iTime) * .5 ) )
	-- Return gradient-multiplied sample
	return sample * grad 
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
