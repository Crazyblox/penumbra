--!strict
--!native
-- Penumbra: Expanded Template --
--[[
	Notes:
		This is an expanded template fragment shader module for Penumbra.
	This template includes constant values for use by the module & shader,
	aliased function naming more resemblent of GLSL (Reducing abstraction),
	texture sampling functions and the returning shader wrapper function,
	which all play a role in enabling performant processing of a given
	fragment shader function.
]]

-- [[ REQUIRES ]] --
local S, Textures = require( "../../../Settings" ), require( "../../../Textures" )
-- [[ TYPES ]] --
type f64=number; type vec=vector
-- [[ LOCALS ]] --
local vec =	vector.create
local vec_1, vec_0_5, vec_0 = vec(1,1,1), vec(.5,.5,.5), vec(0,0)
local iResolution:vec =		vec(S.Display_Res.x,S.Display_Res.y)
local iResolution_div:vec =	iResolution+vec(0,0,1)

local radians, degrees, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, pow, exp, log, exp2, log2, sqrt, inversesqrt, abs, sign, floor, ceil, fract, mod, modf, min, max, clamp, mix, step, smoothstep, length, distance, dot, cross, normalize = -- Requiring implementation: asinh, acosh, atanh, exp2, inversesqrt, trunc, step, smoothstep, distance, faceforward, reflect, refract, determinant, outerProduct, matrixCompMult, inverse, transpose
	math.rad, math.deg, math.sin, math.cos, math.tan, math.asin, math.acos, math.atan, math.sinh, math.cosh, math.tanh, math.pow, math.exp, math.log, math.exp, function( n:f64 ):f64 return math.log( n, 2. ) end, math.sqrt, math.sqrt, math.abs, math.sign, math.floor, math.ceil, function( n:f64 ):f64 return n - math.floor(n) end, function( n:f64, m:f64 ):f64 return n % m end, math.modf, math.min, math.max, math.clamp, math.lerp, function( edge:f64, x:f64 ):f64 return x end, function(e0:f64,e1:f64,x:f64):f64 local t:f64=math.clamp((x-e0)/(e1-e0),0.,1.) return t*t*(3-2*t) end, vector.magnitude, vector.magnitude, vector.dot, vector.cross, vector.normalize  
-- Requiring implementation: asinh, acosh, atanh, exp2, inversesqrt, trunc, step, smoothstep, distance, faceforward, reflect, refract, determinant, outerProduct, matrixCompMult, inverse, transpose 

-- [[ TEXTURES ]] --
local iChannel0: Textures.Texture =	Textures.Load.Base( {{ Name = "VFlip" }}, "Abstract3" )

-- [[ SAMPLERS ]] --
local function Sampler_Nearest_Repeat( t:Textures.Texture, UV:vec ): vec
	UV = vec( UV.x % 1, UV.y % 1 ) // t.FD	-- Repeat -> Expand Resolution
	return t[ UV.x + UV.y * t.Width ]		-- Return Index
end
local function Sampler_Nearest_Clamp( t:Textures.Texture, UV:vec ): vec
	UV = vector.clamp( UV // t.FD, vec_0, vec( t.Width0, t.Height0 ) )	-- Expand Resolution -> 0-Based Clamp
	return t[ UV.x + UV.y * t.Width ]									-- Return Index
end
local function Sampler_Linear_Repeat( t:Textures.Texture, UV:vec ):vec
	UV *=				vec( t.Width, t.Height )		-- Expand Resolution
	UV -=				vec( .5, .5 )					-- Shifts texture origin from top-left to middle of pixel
	local UV_0:vec =	vector.floor( UV )				-- Fetch Top Left (X0Y0) dimensions
	local UV_1:vec =	vector.ceil( UV )				-- Fetch Bottom Right (X1Y1) dimensions
	local A:vec =		UV - UV_0						-- Fetch XY lerp alpha
	local X0:f64 =		UV_0.x % t.Width				-- Fetch X0 index
	local X1:f64 =		UV_1.x % t.Width				-- Fetch X1 index
	local Y0:f64 =		( UV_0.y % t.Height ) * t.Width	-- Fetch Y0 index
	local Y1:f64 =		( UV_1.y % t.Height ) * t.Width	-- Fetch Y1 index
	return vector.lerp(									-- Return Index
		vector.lerp( t[X0+Y0], t[X1+Y0], A.x ),			-- Lerp X0Y0 -> X1Y0
		vector.lerp( t[X0+Y1], t[X1+Y1], A.x ),			-- Lerp X0Y1 -> X1Y1
		A.y												-- Lerp Above Via Alpha.Y
	)
end
local function Sampler_Linear_Clamp( t:Textures.Texture, UV:vec ):vec
	UV *=				vec( t.Width, t.Height )					-- Expand Resolution
	UV -=				vec( .5, .5 )								-- Shifts texture origin from top-left to middle of pixel
	local UV_0:vec =	vector.floor( UV )							-- Fetch UV_0 (Top Left) dimensions
	local UV_1:vec =	vector.ceil( UV )							-- Fetch UV_1 (Bottom Right) dimensions
	UV_0 = vector.clamp( UV_0, vec_0, vec( t.Width0, t.Height0 ) )	-- Clamp UV_0
	UV_1 = vector.clamp( UV_1, vec_0, vec( t.Width0, t.Height0 ) )	-- Clamp UV_1
	local A:vec =		UV - UV_0									-- Fetch XY lerp alpha
	local X0:f64 =		UV_0.x % t.Width							-- Fetch X0 index
	local X1:f64 =		UV_1.x % t.Width							-- Fetch X1 index
	local Y0:f64 =		( UV_0.y % t.Height ) * t.Width				-- Fetch Y0 index
	local Y1:f64 =		( UV_1.y % t.Height ) * t.Width				-- Fetch Y1 index
	return vector.lerp(												-- Return Index
		vector.lerp( t[X0+Y0], t[X1+Y0], A.x ),						-- Lerp X0Y0 -> X1Y0
		vector.lerp( t[X0+Y1], t[X1+Y1], A.x ),						-- Lerp X0Y1 -> X1Y1
		A.y															-- Lerp Above Via Alpha.Y
	)
end
local texture = Sampler_Linear_Repeat

--[[ SHADER ]]--
local function Shader( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	-- Gradient - Sourced from [https://www.shadertoy.com/new]
	local grad:vec = ( fragCoord / iResolution ) + vec_1 * iTime
	grad = vec(cos(grad.x),cos(grad.y+2.),cos(grad.x+4.)) * .5 + vec_0_5
	-- Sample texture
	local uv:vec = ( fragCoord + vec(.5,.5) ) / iResolution
	local sample:vec = texture( iChannel0, uv + vec( sin(iTime) * .5, cos(iTime) * .5 ) )
	-- Return gradient-multiplied sample
	return sample * grad 
end

local iResolution0:vec =	iResolution-vec(1,1)
local iResolution0_div:vec =iResolution0+vec(0,0,1)
local tStart0:vec =	vec(0,S.Actor_Res.y*(S.Actor_RenderNum-1))
local tRes1:vec =	S.Actor_Res --vec(S.Actor_Res.x,S.Actor_Res.y)
local tRes0:vec =	S.Actor_Res-vec(1,1)
local tEnd0:vec =	tStart0+tRes0
local tScale:f64 =	1
local C_Start:f64 = 1 + (
	( 
		(
			tStart0.y // tScale * tScale -- Y_Start
		) - tStart0.y
	) * iResolution.x
)


--[[ MODULE / WRAPPER ]]--
return function( T:f64, In:{vec}, Out:{vec} )	
	local c:f64 = C_Start
	-- Shading routine
	local i_Res0_y:f64 = iResolution0.y
	for Y:f64 = tStart0.y // tScale * tScale, tEnd0.y, tScale do
		for X:f64 = tStart0.x, tEnd0.x, tScale do
			Out[ c ] = Shader( In[ c ], vec( X, i_Res0_y - Y ), T ) 
			c += tScale
		end
		c += iResolution.x * ( tScale - 1 )
	end
	-- Pixel-fill routine
	if tScale <= 1 then return end
	c = C_Start
	for Y:f64 = 0, tRes0.y do
		for X:f64 = tStart0.x, tEnd0.x do
			local uv:vec = vec( X, Y ) // tScale * tScale
			Out[ c ] = Out[ uv.x + uv.y * iResolution.x + 1 ]
			c += 1
		end
	end
end