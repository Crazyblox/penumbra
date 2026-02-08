--!nocheck
--!nolint
--/INLINE
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
