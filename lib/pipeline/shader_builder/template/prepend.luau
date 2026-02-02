--!nocheck
--!nolint
--/INLINE
type f64 = number; type vec = vector
local S = require( `../../../../` )()
local Textures = require( `../../../textures` )
local vec =	vector.create
local vec_1, vec_0_5, vec_0 = vec( 1, 1, 1 ), vec( .5, .5, .5 ), vec( 0, 0 )
local iRes:vec = vec( S.Display_Res.x, S.Display_Res.y )
local iRes_div:vec = iRes + vec( 0, 0, 1 )
local Sampler_IL_Offset:vec

-- RGBAu8/vec3 buffer read/write functions
local u32B: number = 4
local buffer_vec3 = function(b: buffer ,i: number ): vector
	local n:number = buffer.readu32(b,i)
	return vector.create(bit32.band(n,0x000000FF),bit32.rshift(bit32.band(n,0x0000FF00),8),bit32.rshift(bit32.band(n,0x00FF0000),16))*.00392156862745098
end
local vec3_buffer = function(b: buffer, i: number, v: vector)
	v*=0xFF
	buffer.writeu32(b,i,v.x+bit32.lshift(v.y,8)+bit32.lshift(v.z,16)+0xFF000000)
end

-- Texture sampling functions
local function Sampler_Nearest(t: Textures.Texture, UV: vector ): vector
	UV *= vector.create( t.Width, t.Height )		-- Expand resolution
	UV //= 1										-- Set top-left UV integer
	local x:number	= UV.x % t.Width				-- Wrap U to texture width
	local y:number	= ( UV.y % t.Height ) * t.Width	-- Wrap V to texture height
	local i:number	= (x + y) * u32B				-- Set index value
	return buffer_vec3(t.Buffer, i)					-- Return read value
end
-- Texture sampling functions
local function Sampler_Nearest_IL(t: Textures.Texture, UV: vector ): vector
	UV *= vector.create( t.Width, t.Height )		-- Expand resolution
	UV += Sampler_IL_Offset							-- Add interlace jitter
	UV //= 1										-- Set top-left UV integer
	local x:number	= UV.x % t.Width				-- Wrap U to texture width
	local y:number	= ( UV.y % t.Height ) * t.Width	-- Wrap V to texture height
	local i:number	= (x + y) * u32B				-- Set index value
	return buffer_vec3(t.Buffer, i)					-- Return read value
end
local function Sampler_Linear( t: Textures.Texture, UV: vector ): vector
	UV *=				vector.create(t.Width, t.Height)-- Expand resolution
	UV -=				vector.create( .5, .5 )			-- Shifts texture origin from top-left to middle of pixel
	local UV_0:vector =	UV // 1							-- Set top-left UV integer
	local UV_1:vector =	UV_0 + vec_1					-- Set bottom-right UV integer
	local A:vector =	UV - UV_0						-- Fetch XY lerp alpha
	local S0:number =	UV_0.x % t.Width				-- Fetch X0 index
	local S2:number =	UV_1.x % t.Width				-- Fetch X1 index
	local S1:number =	( UV_0.y % t.Height ) * t.Width	-- Fetch Y0 index
	local S3:number =	( UV_1.y % t.Height ) * t.Width	-- Fetch Y1 index
	local b:buffer =	t.Buffer						-- Fetch texture buffer
	S0, S1, S2, S3 = S0+S1, S2+S1, S0+S3, S2+S3			-- Calculate sample indexes
	S0 *= u32B; S1 *= u32B; S2 *= u32B; S3 *= u32B		-- Multiply sample indexes
	return vector.lerp(		
		vector.lerp( buffer_vec3( b, S0 ), buffer_vec3( b, S1 ), A.x ),	-- Lerp X0Y0 -> X1Y0
		vector.lerp( buffer_vec3( b, S2 ), buffer_vec3( b, S3 ), A.x ),	-- Lerp X0Y1 -> X1Y1
		A.y																-- Lerp rows Y0 and Y1
	)
end

-- Math aliases
local radians, degrees, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, pow, exp, log, exp2, log2, sqrt, inversesqrt, abs, sign, floor, ceil, fract, mod, modf, min, max, clamp, mix, step, smoothstep, length, distance, dot, cross, normalize = -- Requiring implementation: asinh, acosh, atanh, exp2, inversesqrt, trunc, step, smoothstep, distance, faceforward, reflect, refract, determinant, outerProduct, matrixCompMult, inverse, transpose
	math.rad, math.deg, math.sin, math.cos, math.tan, math.asin, math.acos, math.atan, math.sinh, math.cosh, math.tanh, math.pow, math.exp, math.log, math.exp, function( n:f64 ):f64 return math.log( n, 2. ) end, math.sqrt, math.sqrt, math.abs, math.sign, math.floor, math.ceil, function( n:f64 ):f64 return n - math.floor(n) end, function( n:f64, m:f64 ):f64 return n % m end, math.modf, math.min, math.max, math.clamp, math.lerp, function( edge:f64, x:f64 ):f64 return x end, function(e0:f64,e1:f64,x:f64):f64 local t:f64=math.clamp((x-e0)/(e1-e0),0.,1.) return t*t*(3-2*t) end, vector.magnitude, vector.magnitude, vector.dot, vector.cross, vector.normalize
