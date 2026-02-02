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
-- Fragment Shader - Cloudy Tunnel [Source: https://www.shadertoy.com/view/llSfRK]

--// origo and lookat points
local o:vec
local t:vec
local oSquareTotal:f64
local sampleCount:f64 = 2
local W:f64 = 4.0
local T:f64 = 0.05
local texture = Sampler_Nearest_IL

-- Values
local iChannel0: Textures.Texture = Textures.Load.Base(
	{ { Name = "From_BT709" }, { Name = "To_sRGB" }, { Name = "VFlip" }, { Name = "GaussianBlur" } },
	"clouds_1024"
)

-- Functions
local function smoothstep(e0:f64,e1:f64,x:f64):f64
	--// Scale, and clamp x to 0..1 range
	x = clamp((x-e0)/(e1-e0),0,1)
	return x*x*(3-2*x)
end

local function filmic_reinhard_curve(x:f64):f64
	local q:f64 = (T+1.0)*x*x
	return q / (q + x + T);
end

local function filmic_reinhard(x:vec):vec
	local w:f64 = filmic_reinhard_curve(W)
	local q:vec = (T+1.0)*x*x
	return (q / (q + x + (vec_1*T)))/w
end

local function mul_vecmat3(v:vec,r0:vec,r1:vec,r2:vec):vec
	return
		vec(r0.x,r1.x,r2.x)*v.x +
		vec(r0.y,r1.y,r2.y)*v.y +
		vec(r0.z,r1.z,r2.z)*v.z
end

local function orient(v:vec, d:vec): (vec, vec, vec)
	v = normalize(v)
	local i:vec = normalize(cross(v, normalize(d)))
	return i, cross(i,v), v
end

local function main( fragColor: vec, fragCoord: vec, iTime: f64 ): vec
	local uv:vec = -vec_1+((vec_1*2)*fragCoord) / iRes
	uv = vec(uv.x * (iRes.x/iRes.y), uv.y)
	
	--// oriented direction vectors (up-vector)
	local d:vec = normalize( mul_vecmat3( vec( uv.x, uv.y, 2.0 ), orient( t, normalize( vec( 0, 1, 2 ) ) ) ) ) 
	--
	local tv:vec = vec_1
	local ac:vec = vec_0
	local i:vec = vec_0
	local aid:f64 = 0
	--
	local a:f64 = d.x*d.x + d.y*d.y
	local b:f64 = 2 * ( o.x*d.x + o.y*d.y )
	--// Sample iteration
	for l = 1, sampleCount do
		local off:f64 = 3 * ( 1 * ( length(tv) ^ 2 ) ) 
		aid += off
		local r:f64 = 32 - off
		local c:f64 = oSquareTotal - r*r
		local delta:f64 = sqrt( b*b - 4*a*c )
		local t:f64 = min( (-b-delta)/(2*a), (-b+delta)/(2*a) )
		t = if math.isnan(t) then 0 else t
		i = o + t*d;
		local i_atan:f64 = math.atan2(i.y, i.x)
		local co:vec = vec((i.z)*.2,i_atan*32/3.1416)
		tv = texture(iChannel0, co*.007)
		local c2:vec = vec((i.z)*.2,abs(i_atan*32/3.1416))
		local te:vec = texture(iChannel0, c2*.007)
		tv = vector.lerp(tv, te, smoothstep(0, .7, i_atan) + smoothstep(3.1416-.7,3.1416,-i_atan))
		ac += vec(tv.x^2.2,tv.y^2.2,tv.z^2.2)/sampleCount
	end
	ac /= ( smoothstep(0, 1, 1/( (length(o-i)*.02)^2 )) )^.5
	ac /= (aid^.5)*.1
	--// vignette
	local rf:f64 = sqrt(dot(uv, uv)) * .3
	local rf2_1:f64 = rf * rf + 1
	ac *= 1 / (rf2_1 * rf2_1)
	--// tonemap
	ac = filmic_reinhard(ac)
	ac = vec(smoothstep(-.12,1,ac.x),smoothstep(-.12,1,ac.y),smoothstep(-.12,1,ac.z))
	return ac
end

local function preprocess( iTime:f64 ): f64
	o = vec( sin(iTime*0.478)*8.0, cos(iTime*0.513)*8.0, iTime*100.0 )
	oSquareTotal = o.x*o.x + o.y*o.y
	t = vec( sin(iTime*0.509)*200.0, cos(iTime*0.437)*200.0, -1000.0 )
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
