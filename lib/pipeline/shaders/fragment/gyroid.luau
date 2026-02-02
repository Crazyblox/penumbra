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
-- Penumbra: Fragment Shader - tm gyroid 2 [Source: https://www.shadertoy.com/view/tXtyW8]
local reinhardBurn:vec = vector.one * .225
local FAR = 30.
local PI = 3.1415

local function vcos(v: vec) return vector.create(math.cos(v.x), math.cos(v.y), math.cos(v.z)) end
local function vsin(v: vec) return vector.create(math.sin(v.x), math.sin(v.y), math.sin(v.z)) end
local function vpow(a: vec, b: vec) return vector.create(math.pow(a.x, b.x), math.pow(a.y, b.y), math.pow(a.z, b.z)) end

local function realstep(edge: f64, x: f64) return if x < edge then 0 else 1 end

local function xy(v: vec) return vector.create(v.x, v.y, 0) end
local function xyy(v: vec) return vector.create(v.x, v.y, v.y) end
local function yyx(v: vec) return vector.create(v.y, v.y, v.x) end
local function yxy(v: vec) return vector.create(v.y, v.x, v.y) end
local function xxx(v: vec) return vector.create(v.x, v.x, v.x) end
local function zxy(v: vec) return vector.create(v.z, v.x, v.y) end

local function reflect(i: vec, n: vec): vec
	return i - 2.0 * dot(n, i) * n;
end

local function gyroid(p: vec): f64 
	return dot(vcos(p), vsin(zxy(p))) + 1.;
end

local function map(p: vec): f64
	local p2: vec = p - vec(0, 0, PI)

	local r = 1e5

	local d = gyroid(p);
	r = math.min(r, d)

	d = gyroid(p2);
	r = math.min(r, d)

	return r;
end

local function getAO(p: vec, sn: vec): f64
	local occ = 0.;
	for i=0,3 do
		local t = i*.08;
		local d = map(p + sn*t);
		occ += t-d;
	end
	return clamp(1.-occ, 0., 1.);
end

local e = vec(0.5773, -0.5773, 0) * 0.001
local xyye = xyy(e)
local yyxe = yyx(e)
local yxye = yxy(e)
local xxxe = xxx(e)

local function getNormal(p: vec): vec
	return normalize(xyye*map(p+xyye) + yyxe*map(p+yyxe) + yxye*map(p+yxye) + xxxe*map(p+xxxe));
end

local m = 0;

local function raymarch(ro: vec, rd: vec): f64
	local t = 0.;
	m = 0;
	for i=1,150 do --150
		local p: vec = ro + rd * t
		local p2: vec = p - vec(0, 0, PI)

		local d1 = gyroid(p);
		local d = math.min(1e5, d1)

		local d2 = gyroid(p2);
		d = math.min(d, d2)

		if (abs(d) < .001) then
			m = if d2 < d1 then 2 else 1
			break;
		end

		t += d;
		if (t > FAR) then break; end
	end
	return t;
end

local function trace(ro: vec, rd: vec): vec
	local C: vec = vec(0, 0, 0);
	local throughput: vec = vec(1, 1, 1);

	for bounce=0,1 do
		local d = raymarch(ro, rd);

		if (d > FAR) then break; end

		-- fog
		local fog = 1. - exp(-.008*d*d);
		C += throughput * fog * vec(0, 0, 0); throughput *= 1. - fog;

		local p: vec = ro + rd*d;
		local temp: vec = vector.abs(vcos(p*64.))
		local sn: vec = normalize(getNormal(p) + vpow(temp, vec(16, 16, 16))*.1);

		-- lighting
		local lp: vec = vec(10.,-10.,-10.+ro.z) ;
		local ld: vec = normalize(lp - p);
		local diff = max(0., .5+2.*dot(sn, ld));
		local diff2 = pow(length(vsin(sn*2.)*.5+vec(.5, .5, .5)), 2.);
		local diff3 = max(0., .5+.5*sn.z);

		local spec = max(0., dot(reflect(-ld, sn), -rd));
		local fres = 1. - max(0.,dot(-rd, sn));
		local col = vec(0, 0, 0);
		local alb = vec(0, 0, 0);

		col += vec(.4, .6, .9) * diff;
		col += vec(.5, .1, .1) * diff2;
		col += vec(.9, .1, .4) * diff3; 
		col += vec(.3,.25,.25) * pow(spec,4.)*8.;

		local freck = dot(vcos(p*23.),vec(1, 1, 1));
		if (m==1) then alb = vec(.2, .1, .9);  alb *= max(.6, realstep(2.5, freck)); end
		if (m==2) then alb = vec(.6, .3, .1);  alb *= max(.8, realstep(-2.5, freck)); end
		col *= alb;

		col *= getAO(p, sn); -- ~11%
		C += throughput * col;

		-- reflection
		rd = reflect(rd, sn);
		ro = p + sn*.01;
		throughput *=  .9 * pow(fres, 1.);
	end

	return C;
end

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec

	local uv: vec = (xy(fragCoord) - xy(iRes)*.5) / iRes.y;

	local ro: vec = vec(PI/2.,0, -iTime*.5);
	local rd: vec = normalize(vec(uv.x, uv.y, -.5));

	do
		local rotArg = sin(iTime*.2)
		local c = cos(rotArg);
		local s = sin(rotArg);
		local new_x = c * rd.x - s * rd.y;
		local new_y = s * rd.x + c * rd.y;

		rd = vector.create(new_x, new_y, rd.z)
	end

	local ta: vec = vec(cos(iTime*.4), sin(iTime*.4), 4.);

	do
		local dir = normalize(ta)
		local up: vec = vec(0.,1.,0.);
		local rt: vec = normalize(cross(dir,up));
		local c0, c1, c2 = rt, cross(rt,dir), dir;

		rd = rd.x * c0 + rd.y * c1 + rd.z * c2
	end

	local col: vec = trace(ro, rd);

	col *= smoothstep(0.,1., 1.2-length(uv*.9));
	col /= col + reinhardBurn;
	return col
end

local function preprocess( iTime:f64 ): f64
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
