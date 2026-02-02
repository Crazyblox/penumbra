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
-- Penumbra: Fragment Shader - Traced Tunnel [Source: https://www.shadertoy.com/view/tdjfDR]
local iChannel0: Textures.Texture = Textures.Load.Base( {{Name="Squared"},{Name="VFlip"},{Name="GaussianBlur"}}, "abstract3" )
local iChannel1: Textures.Texture = Textures.Load.Base( {{Name="Squared"},{Name="VFlip"},{Name="GaussianBlur"}}, "rustymetal" )
local reinhardBurn:vec = vector.one*.225
local sampleNum:f64 =		1
local reflectionNum:f64 =	2
local DOF:f64 =				.05
local DOFDist:f64 =			3
local sc:f64 =				12
local txSc:vec =			vec(2,.5) --// Texture scale (vec2, const)
local txSc2:vec =			vec(1,.25) --// Texture scale. (vec2, const)
local e:f64 =				2.71828182 --2.718281828459045235360287471352
local texture = Sampler_Nearest_IL
local function r2( v2:vec, a:f64 ):vec --// 2D rotation. 
	local cosA:f64, sinA:f64 = cos(a), sin(a)
	return vec(v2.x*cosA+v2.y*sinA,v2.x*-sinA+v2.y*cosA)
end
local function hash21( p:vec ):f64 --// Random functions: All based on IQ's originals.
	local v:f64 = sin(dot(p,vec(425.215,714.388)))*45758.5453 
	return v-(v//1)
end
local function hash22( p:vec ):vec
	local v:vec = vec(
		sin(dot(p,vec(72.927,98.283))),
		sin(dot(p,vec(41.295,57.263)))
	)*vec(43758.5453,23421.6361)
	return v-(v//1)
end
local function hash23( p:vec ):vec
	local v:vec = vec(
		sin(dot(p,vec(12.989,78.233))),
		sin(dot(p,vec(51.898,56.273))),
		sin(dot(p,vec(41.898,57.263)))
	)*vec(43758.5453,23421.6361,65426.6357)
	return v-(v//1)
end
local function Tick( t:f64, d:f64 ):f64
	local m:f64 = (t/d)%1
	m = smoothstep(0,1,m)
	m = smoothstep(0,1,m)
	return (floor(t/d)+m)*d
end
local function tickTime( t:f64 ): f64
	return t*2+Tick(t,4)*.75
end
local function cam( p:vec, tm:f64, tTime:f64 ):vec
	local p_r2: vector = r2(vec(p.x,p.z),sin(tTime*.3)*.4)
	p = vec(p_r2.x,p.y,p_r2.y)
	p_r2 = r2(vec(p.x,p.y),sin(tTime*.1)*2.)
	p = vec(p_r2.x,p_r2.y,p.z)
	return p
end
local function rayPlane( ro:vec, rd:vec, n:vec, d:f64 ):f64
	local t:f64 = 1e8
	local ndotdir:f64 = dot(rd,n)
	if ndotdir < 0 then
		local dist:f64 = (-d-dot(ro,n)+9e-7)/ndotdir
		t = if dist > 0 and dist < t then dist else t
	end
	return t
end
local function udBox( p:vec, b:vec ):f64
	return length(vector.max(vector.abs(p)-b+vec(.1,.1),vec_0))-.1
end
local function uvShape( p:vec ):f64
	p = vector.abs(p) -- Polar mapping a square wall.
	return max(p.x,p.y)
end
local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	--// Aspect correct screen coordinates.
	local uv:vec = ( fragCoord - iRes * .5 ) / iRes.y
	uv = vec(uv.x,uv.y)

	--// Global & tick (regular) time, has lurching tick. Motion sickness liability
	local tm:f64 = iTime
	local tickTm:f64 = tickTime(tm)

	--// Cam pos init, tickTm lurches across z position.
	local ca:vec = vec(0,0,tickTm)

	--// Initialize the scene color to zero.
	local col:vec = vec_0

	--// Number of samples. Ray spread is influenced by j.
	local j:f64 = 0

	--// Pixel offset (vec2)
	local j_off:f64 = j*74.542+35.877
	local offs:vec = hash22( uv + vec(j_off,j_off) ) - vec(.5,.5)

	local ro:vec = vec_0

	local r: vector = normalize( ( uv - offs / iRes.y ) + vector.create( 0, 0, 1 ) )

	--// Camera movement. Rotation, swivle, etc.
	ro = cam(ro,tm,tickTm)
	r = cam(r,tm,tickTm)
	ro += vector.create(0,0,ca.z)

	--// Alpha, for blending layers.
	local alpha:f64 = 1.

	--// Fog distance.
	local fogD:f64 = 1e5

	--// Reflective bounces. Three is usual, but reduce for better performance.
	--local i: number = 0
	for i:f64 = 0, 1 do
		--// Tracing the four planes, then determining the closest.
		--// You could group this into a faster, more tailored function,
		--// but this is easier to read.
		local pl_x = rayPlane(ro, r, vec( 0, 1 ), 1)	--// x, Bottom
		local pl_y = rayPlane(ro, r, vec( 0, -1 ), 1)	--// y, Top
		local pl_z = rayPlane(ro, r, vec( 1, 0 ), 1)	--// z, Left
		local pl_w = rayPlane(ro, r, vec( -1, 0 ), 1)	--// w, Right

		--// Minimum plane distance.
		local d:f64 = min(min(pl_x,pl_y),min(pl_z,pl_w))

		--// Set the fog distance on the first pass.
		fogD = if i == 0 then d else fogD

		--// Hit position.
		local p:vec = ro+r*d

		--// Determine the UV coordinates for texturing, and the normal, for lighting and other things.
		--// Set the normal and UVs to the bottom or top planes.
		local n:vec = vec( 0, if pl_x < pl_y then 1 else -1 )
		local tuv:vec = vec(p.x,p.z+n.y)

		--// If we've hit the side walls instead, change the normal and UVs accordingly. 
		if min(pl_z,pl_w) < min(pl_x,pl_y) then
			n = vec( if pl_z < pl_w then 1 else -1, 0 )
			tuv = vec( p.y + n.x, p.z ) --// Left walls.
		end

		--// Texture scaling for texturing.
		tuv *= sc

		--// Sample color.
		local sampleCol:vec = vec_1

		--// Grid square ID and local coordinates.
		local id:vec = vector.floor(tuv)
		tuv -= id + vec(.5,.5)

		--// Use the UV coordinates to create a whitish colored rounded box grid.
		local patDist:f64 = udBox(tuv,vec(.4,.4))

		--// Use the square grid shape for shading.
		local sh:f64 = clamp(.5-patDist/.2,0.,1.)

		--// Subtle coloring.
		local sqCol_cos:vec = vec_1 * ( hash21( id + vec(.2,.2) ) * 2 ) * 6.2831 + vec(0,1,2)
		local sqCol:vec = (vec_1*.85) + .3 * vec(cos(sqCol_cos.x),cos(sqCol_cos.y),cos(sqCol_cos.z))
		sampleCol = vector.lerp(vec_0,sqCol*sh,1.-smoothstep(.0,.005,patDist))

		--// Perform a squarish polar mapping (of sorts), read in to some textures, then color them up, etc.
		--// Quantized squarish polar mapping.
		local ip3:vec = (vector.floor(p*sc)+vec_0)/sc --// Quantizing... as opposed to continuous values.
		local ang:f64 = math.atan2(ip3.x,ip3.y)/6.2831 --// Angle of grid cell from the tube center.
		local tnuv:vec = vec(uvShape(vec(ip3.x,ip3.y)) * ang * txSc.x, ip3.z * txSc.y ) --// Square polar UVs. (vec2)

		--// Smooth squarish polar mapping.
		local p3:vec = vector.lerp(p,(vector.floor(p*sc)+vec_0)/sc,.8) --// Slightly smooth quantized values. (vec3)
		local ang2:f64 = math.atan2(p3.x,p3.y)/6.2831 --// Angle of grid cell from the tube center.
		local tnuv2:vec = vec(uvShape(vec(p3.x,p3.y))*ang2*txSc2.x+p3.z*.075,p3.z*txSc2.y) --// Square polar UVs.

		--// Reading the texel values, and manipulating a bit. Note the squaring of the value, (tx *= tx) which is a rough sRGB to linear conversion.
		local tx_fract:vec = tnuv-vec(.5,.5)-vec(iTime/(sc)/2,.0) 
		local tx:vec = texture(iChannel0,tx_fract) --tx *= tx
		tx = vector.lerp(tx,vec_1*dot(tx,vec(.299,.587,.114)),.75)
		tx = vec(smoothstep(.1,.55,tx.x),smoothstep(.1,.55,tx.y),smoothstep(.1,.55,tx.z))
		local tx2_fract:vec = tnuv2-vec(.5,.5)-vec(iTime/(sc)/2,0.) 
		local tx2:vec = texture(iChannel1,tx2_fract) -- tx2 *= tx2
		tx2 = vec(smoothstep(.18,.5,tx2.x),smoothstep(.18,.5,tx2.y),smoothstep(.18,.5,tx2.z))
		sampleCol *= tx*tx2*4 --// Apply the textures to the sample color.  

		--// Some fakish point lighting. Light direction vector. The light is 3 units up from the camera, which coincides with the depth of field distance. 
		local ld:vec = normalize(ca+vec(0,0,3)-p)
		local dif:f64 = max(dot(ld,n),0.) --// Diffuse.
		local spe:f64 = pow(max(dot(ld-2*dot(ld,-n)*-n,-r),0.),8) --// Specular.
		local fre:f64 = pow(max(1.-abs(dot(r,n))*.5,0.),1) --// Fresnel.
		sampleCol *= (vec_1*dif+vec(1,.9,.7)*spe*4.+vec(.5,.7,1.)*fre)

		sampleCol *= 1.35/(1.+fogD*fogD*.05) --// Applying some fog.
		col += sampleCol*alpha*fre --// Add the sample color to overall accumulated scene color.
		alpha *= .9 --// Reduce the alpha factor by a bit and mix in the Fresnel factor as well.

		--// Calculate the reflection vector for the next pass.
		r -= 2 * vector.dot( r, n ) * n --// Pure reflection.

		--// Advance the position to the new hit point. Also be sure to bump the ray off the surface to avoid self collision... If I had a dollar for every time I've forgotten to do this... :)
		ro = p+n*.0011
	end

	--// Divide by the total number of samples.
	--col /= sampleNum

	col /= col + reinhardBurn
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
