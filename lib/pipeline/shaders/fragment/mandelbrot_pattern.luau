--!strict
--!native
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
-- Penumbra: Fragment Shader - Mandelbrot Pattern Decoration [Source: https://www.shadertoy.com/view/ttscWn]
-- VARIABLES
local AA:f64 = 2
local AA0:f64 = AA - 1
local AA2_Reciprocal:f64 = 1 / (AA*AA)
local iter:f64 = 128
local fog:vec = vec_0
-- preprocessables
local ttm:f64, c:f64, s:f64, zm:f64

-- FUNCTIONS
local function xzy(v: vec): vec return vec(v.x, v.z, v.y) end
local function yxz(v: vec): vec return vec(v.y, v.x, v.z) end

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	fragColor = vec_0 -- Set to black.

	for j = 0, AA0 do
		for i = 0, AA0 do
			local p = (fragCoord + vec(i, j)/AA - iRes*.5)/iRes.y
			p = vec(c * p.x - s * p.y, s * p.x + c * p.y)
			p -= vec(cos(iTime/2.)/2., sin(iTime/3.)/5.)

			local cc = vec(-.57735 + .004, .57735) + p/zm
			local z, dz = vec_0, vec_0

			local ik:f64 = 128
			local zDot:f64
			for k = 0, iter - 1 do
				dz = vec((z.x * dz.x - z.y * dz.y) * 2. + 1., (z.y * dz.x + z.x * dz.y) * 2.)
				z = vec(z.x * z.x - z.y * z.y, 2. * z.x * z.y) + cc
				zDot = dot(z, z)
				if zDot > 1/.005 then
					ik = k
					break
				end
			end

			local ln = step(0, length(z)/15.5 - 1)
			local d = sqrt(1/max(length(dz), .0001))*log(zDot)
			d = clamp(d*50, 0, 1)

			local dir = if mod(ik, 2) < .5 then -1 else 1
			local sh = (iter-ik)/iter
			local tuv = z/320

			local tm = (-ttm*sh*sh*16)
			local c = cos(tm)
			local s = sin(tm)

			tuv = vec(c * tuv.x - s * tuv.y, s * tuv.x + c * tuv.y)
			tuv = vec(
				abs(mod(tuv.x, 1/8) - 1/16),
				abs(mod(tuv.y, 1/8) - 1/16)
			)

			local pat = smoothstep(0, 1/length(dz), length(tuv) - 1/32)
			pat = min(pat, smoothstep(0, 1/length(dz), abs(max(tuv.x, tuv.y) - 1/16) - .04/16))

			local minVal = min(d * .85, .96)
			local lCol:vec = vector.min( vec( 1.5, 1, 1 ) * minVal, vec( 1, 3, 16 ) )
			lCol = vec( pow(lCol.x, 1), pow(lCol.y, 3), pow(lCol.z, 16) )
			lCol *= 1.15

			lCol =
				if dir < 0 then
				lCol * min(pat, ln)
				else
				vec(sqrt(lCol.x) * 0.5 + 0.7, sqrt(lCol.y) * 0.5 + 0.7, sqrt(lCol.z) * 0.5 + 0.7) * max(1 - pat, 1 - ln)

			local rd = normalize(vec(p.x, p.y, 1))
			rd = rd - 2 * dot(vec(0, 0, -1), rd) * vec(0, 0, -1)

			local diff = clamp(dot(z*.5 + vec_0_5, vec(rd.x, rd.y, 0)), 0, 1)*d

			tuv = z/200
			tm = -tm/1.5 + .5
			local c = cos(tm)
			local s = sin(tm)
			tuv = vec(c * tuv.x - s * tuv.y, s * tuv.x + c * tuv.y)
			tuv = vec(
				abs(mod(tuv.x, 1/8) - 1/16),
				abs(mod(tuv.y, 1/8) - 1/16)
			)
			pat = smoothstep(0., 1./length(dz), length(tuv) - 1./32.);
			pat = min(pat, smoothstep(0., 1./length(dz), abs(max(tuv.x, tuv.y) - 1./16.) - .04/16.));

			local gloss:vec = vector.lerp(lCol, vec_1 * ln, .5)
			gloss = gloss * diff * diff * .5 * (pat * .6 + .6)
			lCol += gloss

			lCol = if mod(ik, 6) < .5 then yxz(lCol) else lCol

			local d_factor:f64 = d / 1.2
			lCol *= d_factor
			lCol += xzy(lCol) * (1 - d_factor)

			local fringe_factor = (1 - step(0, -(length(z) * .05 * ik / iter - 1))) * .95
			lCol *= 1 - fringe_factor

			local mixFactor = sh * d
			lCol *= mixFactor
			lCol += fog * ( 1 - mixFactor )

			fragColor += vector.min(lCol, vec_1)
		end
	end

	fragColor *= AA2_Reciprocal

	fragColor = ( vec_1 - vec( exp( -fragColor.x ), exp( -fragColor.y ), exp( -fragColor.z ) ) ) * 1.25

	local uv:vec = fragCoord/iRes
	fragColor *= pow( 16 * ( 1 - uv.x ) * ( 1 - uv.y ) * uv.x * uv.y, 1/8 ) * 1.15

	return vector.max( vec( sqrt( fragColor.x ), sqrt( fragColor.y ), sqrt( fragColor.z ) ), vec_0 )
end

local function preprocess( iTime:f64 ): f64
	ttm = cos(sin(iTime/8.))*6.2831
	c = cos(ttm)
	s = sin(ttm)
	zm = (200 + sin(iTime/7)*50)
	return iTime
end
local iRes0:vec =	iRes-vec(1,1)
local iRes0_div:vec =iRes0+vec(0,0,1)
local tStart0:vec =	vec(0,S.Actor_Res.y*(S.Actor_RenderNum-1))
local tRes1:vec =	S.Actor_Res
local tRes0:vec =	S.Actor_Res-vec(1,1)
local tEnd0:vec =	tStart0+tRes0
local IL_Start:f64 = tStart0.y % 2

-- Interlace data & function
local IL = { x = { ext = {tStart0.y % 2, 2}, int = {0, 2} }, y = { ext = {0, 2}, int = {0, 1} } }
local function InterlaceStep(): (f64, f64, f64, f64)
	-- X: Internal clock, external clock
	IL.x.int[1] += 1; IL.x.int[1] %= IL.x.int[2]
	IL.x.ext[1] += ( IL.x.int[1] == 0 ) and 1 or 0; IL.x.ext[1] %= IL.x.ext[2]
	-- Y: Internal clock, external clock
	IL.y.int[1] += 1; IL.y.int[1] %= IL.y.int[2]
	IL.y.ext[1] += ( IL.y.int[1] == 0 ) and 1 or 0; IL.y.ext[1] %= IL.y.ext[2]
	-- Return XY offsets, XY steps
	Sampler_IL_Offset = vec( -.333 + IL.y.ext[1] * .666,  -.333 + IL.x.ext[1] * .666 )
	return IL.x.ext[1], IL.y.ext[1], IL.x.ext[2], IL.y.ext[2]
end

for i = 1, IL_Start do
	InterlaceStep()
end

local function ShaderCall( T:f64, In:buffer, Out:buffer, c:f64, X_i:f64, Y_i:f64 )
	--vec3_buffer( Out, c, main( buffer_vec3( In, c ), vec( X_i, Y_i ), T ) )
	-- ^^^ For inputting previous shader as fragColor
	vec3_buffer( Out, c, main( vec_1, vec( X_i, Y_i ), T ) )
	-- ^^^ For inputting blank white (More performance)
end

return function( T:f64, In:buffer, Out:buffer, InterlaceOn: boolean? )
	T = preprocess(T)
	-- Set steps & offsets
	local X_Off:f64, Y_Off:f64, X_Jump:f64, Y_Jump:f64 = 0, 0, 1, 1
	if InterlaceOn then X_Off, Y_Off, X_Jump, Y_Jump = InterlaceStep() end
	-- Set XY byte increments
	local X_Jump_Bytes:f64 = u32B
	local Y_Jump_Bytes:f64 = iRes.x * u32B
	-- Set XY byte start offsets byte offsets
	local X_Off_Bytes:f64 = X_Jump_Bytes * X_Off
	local Y_Off_Bytes:f64 = Y_Jump_Bytes * Y_Off
	local c:f64 = X_Off_Bytes + Y_Off_Bytes
	-- X_Jump_Bytes always needs to increment; our 'c' cursor depends on this.
	X_Jump_Bytes += X_Jump_Bytes * (X_Jump-1)
	Y_Jump_Bytes *= (Y_Jump-1)
	for Y_i:f64 = iRes0.y - tStart0.y - Y_Off, iRes0.y - tEnd0.y, -Y_Jump do
		for X_i:f64 = tStart0.x + X_Off, tEnd0.x, X_Jump do
			ShaderCall( T, In, Out, c, X_i, Y_i )
			c += X_Jump_Bytes
		end
		c += Y_Jump_Bytes
	end
end
