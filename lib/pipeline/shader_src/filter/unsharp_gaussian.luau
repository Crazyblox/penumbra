--!nocheck
--!nolint
--/INLINE
-- Gaussian Unsharp Mask 3x3 Kernel
local function Sampler_Unsharp(t: Textures.Texture, UV: vector): vector
	local b = t.Buffer
	local tW:number, tH:number = t.Width, t.Height
	UV = (UV * vector.create(tW,tH) + vector.create(.5,.5) ) // 1
	-- X1Y1
	local x:number	= UV.x % tW 			* u32B	-- Wrap U to texture width
	local y:number	= ( UV.y % tH ) * tW	* u32B	-- Wrap V to texture height
	local OG:vector = buffer_vec3(b, x+y)
	local S:vector = OG * 13
	-- X0Y0
	UV += vector.create(-1, -1)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)
	-- X1Y0
	UV += vector.create(1, 0)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)* 2
	-- X2Y0
	UV += vector.create(1, 0)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)
	-- X0Y1
	UV += vector.create(-2, 1)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)* 2
	-- X0Y1
	UV += vector.create(2, 0)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)* 2
	-- X0Y2
	UV += vector.create(-2, 1)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)
	-- X1Y2
	UV += vector.create(1, 0)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)* 2
	-- X2Y2
	UV += vector.create(1, 0)
	x = UV.x % tW 			* u32B	-- Wrap U to texture width
	y = ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	S -= buffer_vec3(b, x+y)
	-- Return
	return vector.lerp( OG, vector.clamp( S, vec_0, vec_1 ), .2 )
end
local texture = Sampler_Unsharp

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local pixel_to_uv: vec = fragCoord/iRes;
	return texture(FB_Full, pixel_to_uv)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
