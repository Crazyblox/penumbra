--!nocheck
--!nolint
--/INLINE
DoInterlace = false
local function Sampler_BoxBlur(t: Textures.Texture, UV: vector): vector
	local tW:number, tH:number = t.Width, t.Height
	UV = (UV * vector.create(tW,tH) + vector.create(.5,.5) ) // 1	
	local x0:number	= UV.x % tW 			* u32B	-- Wrap U to texture width
	local y0:number	= ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	UV += vec_1										-- Get bottom-right
	local x1:number	= UV.x % tW 			* u32B	-- Wrap U to texture width
	local y1:number	= ( UV.y % tH ) * tW 	* u32B	-- Wrap V to texture height
	return (
		buffer_vec3(t.Buffer, x0+y0) +				-- Sample top-left
			buffer_vec3(t.Buffer, x1+y0) +			-- Sample top-right
			buffer_vec3(t.Buffer, x0+y1) +			-- Sample bottom-left
			buffer_vec3(t.Buffer, x1+y1)			-- Sample bottom-right
	) * .25
end
local texture = Sampler_BoxBlur

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local pixel_to_uv: vec = fragCoord/iRes;
	return texture(FB_Full, pixel_to_uv)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
