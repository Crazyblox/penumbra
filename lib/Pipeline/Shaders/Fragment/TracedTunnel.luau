--!strict
--!native
-- Penumbra: Fragment Shader - Traced Tunnel [Source: https://www.shadertoy.com/view/tdjfDR]
type f64=number; type vec=vector
local S, Textures = require( "../../../Settings" ), require( "../../../Textures/init" )
local vec =	vector.create;local vec_1, vec_0_5, vec_0 = vec(1,1,1), vec(.5,.5,.5), vec(0,0);local iResolution:vec =vec(S.Display_Res.x,S.Display_Res.y);local iResolution_div:vec = iResolution+vec(0,0,1);
local radians, degrees, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, pow, exp, log, exp2, log2, sqrt, inversesqrt, abs, sign, floor, ceil, fract, mod, modf, min, max, clamp, mix, step, smoothstep, length, distance, dot, cross, normalize = -- Requiring implementation: asinh, acosh, atanh, exp2, inversesqrt, trunc, step, smoothstep, distance, faceforward, reflect, refract, determinant, outerProduct, matrixCompMult, inverse, transpose
	math.rad, math.deg, math.sin, math.cos, math.tan, math.asin, math.acos, math.atan, math.sinh, math.cosh, math.tanh, math.pow, math.exp, math.log, math.exp, function( n:f64 ):f64 return math.log( n, 2. ) end, math.sqrt, math.sqrt, math.abs, math.sign, math.floor, math.ceil, function( n:f64 ):f64 return n - math.floor(n) end, function( n:f64, m:f64 ):f64 return n % m end, math.modf, math.min, math.max, math.clamp, math.lerp, function( edge:f64, x:f64 ):f64 return x end, function(e0:f64,e1:f64,x:f64):f64 local t:f64=math.clamp((x-e0)/(e1-e0),0.,1.) return t*t*(3-2*t) end, vector.magnitude, vector.magnitude, vector.dot, vector.cross, vector.normalize
local function Sampler_Nearest_Repeat(t:Textures.Texture,UV:vec):vec UV=vec(UV.x%1,UV.y%1)//t.FD;return t[ UV.x + UV.y * t.Width ]end;local function Sampler_Nearest_Clamp(t:Textures.Texture,UV:vec):vec UV=vector.clamp(UV//t.FD,vec_0,vec(t.Width0,t.Height0)); return t[UV.x+UV.y*t.Width];end;local function Sampler_Linear_Repeat(t:Textures.Texture,UV:vec):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y);end;local function Sampler_Linear_Clamp( t:Textures.Texture,UV:vec ):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);UV_0=vector.clamp(UV_0,vec_0,vec(t.Width0,t.Height0));UV_1=vector.clamp(UV_1,vec_0,vec(t.Width0,t.Height0));local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y)end
--[[ SHADER ]]--
local iChannel0: Textures.Texture = Textures.Load.Base( {{Name="Squared"},{Name="VFlip"}}, "Abstract3" )
local iChannel1: Textures.Texture = Textures.Load.Base( {{Name="Squared"},{Name="VFlip"}}, "RustyMetal" )
local sampleNum:f64 =		1
local DOF:f64 =				.05
local DOFDist:f64 =			3
local sc:f64 =				12
local txSc:vec =			vec(2,.5) --// Texture scale (vec2, const)
local txSc2:vec =			vec(1,.25) --// Texture scale. (vec2, const)
local e:f64 =				2.71828182 --2.718281828459045235360287471352
local texture = Sampler_Linear_Repeat
local function r2( v2:vec, a:f64 ):vec --// 2D rotation. --mat2 r2(float a){ return mat2(cos(a), sin(a), -sin(a), cos(a)); }
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
	-- Cam swing; comment out if not swinging.
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
local function Shader( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	--// Aspect correct screen coordinates.
	local uv:vec = ( fragCoord - iResolution * .5 ) / iResolution.y
	uv = vec(uv.x,uv.y)
	--// Depth of field (DOF) amount, and the DOF distance. In this case, a figure of 3 will bring everything into focus three units down the tunnel, but camera blur things around it.
	-- const float DOF = .05, DOFDist = 3.;
	--// Global & tick (regular) time, has lurching tick. Motion sickness liability
	local tm:f64 = iTime
	local tickTm:f64 = tickTime(tm)
	--// Cam pos init, tickTm lurches across z position.
	local ca:vec = vec(0,0,tickTm)
	--// Initialize the scene color to zero.
	local col:vec = vec_0
	--// Number of samples. Ray spread is influenced by j.
	local j:f64 = 0
	--for j = 0, sampleNum - 1 do
	--// Pixel offset (vec2)
	local j_off:f64 = j*74.542+35.877
	local offs:vec = hash22( uv + vec(j_off,j_off) ) - vec(.5,.5)
	--#ifdef MOTION_BLUR
	--// Motion blur: Just a simple temporal blending of samples. In case it isn't
	--// obvious, you're advancing global time a little with each sample, which results 
	--// in frames further in time being blended with the present. You could go 
	--// backwards instead, if the idea of looking into the future bothers you. :D
	--tm = iTime + float(j)*.05/float(sampleNum);
	--tickTm = tickTime(tm);
	--#endif
	local ro:vec = vec_0
	--#ifdef DEPTH_OF_FIELD
	--// Depth of field. Spreading out the sample, according to screen depth.
	-- vec2
	--ro.xy += offs*DOF;
	--ro += GL.xy_( ro ) * offs * DOF
	ro += offs * DOF
	local r:vec = normalize( ( uv - offs * DOF / DOFDist ) + vec(0,0,1) )
	-- vec3
	--vec3 r = normalize(vec3(uv - offs*DOF/DOFDist, 1));
	--local r: vector = GL.normalize( GL.v2_v3( uv - offs * DOF / DOFDist, 1 ) )
	--#else
	--local r: vector = vector.normalize( ( uv - offs / ResY ) + vector.create( 0, 0, 1 ) )
	--#endif
	--// Camera movement. Rotation, swivle, etc.
	-- DEBUG: Possible factors which are affecting this: r2, ro, r, tm, tickTm
	ro = cam(ro,tm,tickTm)
	r = cam(r,tm,tickTm)
	ro += vector.create(0,0,ca.z) --GL.__z(ca) --GL.xy_(ro) + ( GL.__z(ro) + GL.__z(ca) ) -- ro = GL.vec3( ro.x, ro.y, ro.z + ca.z )
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
		--local tuv: vector = vector.create( p.x, p.z, 0 ) + vector.create( 0, n.y, 0 ) -- vec2
		local tuv:vec = vec(p.x,p.z+n.y)
		--// If we've hit the side walls instead, change the normal and UVs accordingly. 
		if min(pl_z,pl_w) < min(pl_x,pl_y) then
			n = vec( if pl_z < pl_w then 1 else -1, 0 )
			--tuv = vector.create( p.y, p.z, 0 ) + GL.vec2( n.x, 0 ) --// Left walls.
			tuv = vec( p.y + n.x, p.z ) --// Left walls.
		end
		--// Texture scaling for texturing. do
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
		--local txSc: vector = vector.create( 2, 1 / 2 ) --// Texture scale (vec2, const)
		local ip3:vec = (vector.floor(p*sc)+vec_0)/sc --// Quantizing... as opposed to continuous values.
		local ang:f64 = math.atan2(ip3.x,ip3.y)/6.2831 --// Angle of grid cell from the tube center.
		local tnuv:vec = vec(uvShape(vec(ip3.x,ip3.y)) * ang * txSc.x, ip3.z * txSc.y ) --// Square polar UVs. (vec2)
		--// Smooth squarish polar mapping.
		--local txSc2: vector = vector.create( 1, 1 / 4 ) --// Texture scale. (vec2, const)
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
		--/*
		--// W23's chromatic effect. It looks good in his artsy black and white
		--// example, but there's too much color here for it to be effective.
		--float patDistL = udBox(tuv - vec2(.05, 0), vec2(.4));
		--float patDistR = udBox(tuv - vec2(0, .05), vec2(.4));
		--sampleCol *= step(0., -vec3(patDistL, patDist, patDistR) - .025);
		--*/
		sampleCol *= 1.35/(1.+fogD*fogD*.05) --// Applying some fog.
		col += sampleCol*alpha*fre --// Add the sample color to overall accumulated scene color.
		alpha *= .9 --// Reduce the alpha factor by a bit and mix in the Fresnel factor as well.
		--// Calculate the reflection vector for the next pass.
		--#ifdef PURE_REFLECTION
		--r -= 2 * vector.dot( r, n ) * n --// Pure reflection overide. It's definitely cleaner, but less interesting.
		--#else
		--// Just some randomized reflection, based on certain heuristics. There are various ways to create a randomized relective vector, but it's mainly common sense.
		-- !!!!! UNSURE HOW THE VECTOR-BASED VALUES CONVERT TO A FLOAT
		local h:f64 = hash21(id)*smoothstep(0.,.005,-patDist+.15)
		--// Purely reflected vector.
		--vec3 ref = reflect(r,n);
		local ref:vec = r-2*dot(r,n)*n -- local ref: vector = GL.reflect3( r, n )
		--// Random vector.
		--r = normalize(hash23(uv + float(j)*74.524 + float(i)*35.712) - .5);
		--r = GL.normalize( hash23( uv + GL.f_v3(j) * 74.524 + GL.f_v3(i) * 35.712 ) - GL.f_v3(.5) );
		r = normalize(hash23(uv+vec_1*(j*74.524+i*35.712))-vec(.5,.5,.5))
		--// Mixing the purely reflected vector with the random vector according to some heuristics. In this case, a random opaque factor for the tile, the tile shade, pattern border, fog... I made it up as I went along. :)
		--r = normalize(mix(ref, r, (hash21(tuv)*.0 + h*.1*sh)*exp(-fogD*.05)));
		--r = GL.normalize( GL.mix3( ref, r, ( hash21( tuv ) * .0 + h * 0.1 * sh ) * GL.expf( -fogD * 0.05 ) ) );
		r = normalize(vector.lerp(ref,r,(hash21(tuv)*.0+h*.1*sh)*exp(-fogD*.05)))
		--// Ensuring random reflection. I normally use other logic, but it works well enough in W23 and Nusan's examples, so it'll do. :)
		--r = dot(r, n)<0.? -r : r;
		r = if dot(r,n) < 0 then -r else r
		--r = if GL.dot( r, n ) < 0. then -r else r
		--#endif
		--// Advance the position to the new hit point. Also be sure to bump the ray off the surface to avoid self collision... If I had a dollar for every time I've forgotten to do this... :)
		ro = p+n*.0011
	end
	--end
	--// Divide by the total number of samples.
	--col /= sampleNum
	--// Use this to tone down highlight extrema... However, if you like to live on the edge and burn your eyes, then leave it as is. :D
	--col = vector_one - vector.create(
	--	e ^ -col.x,
	--	e ^ -col.y,
	--	e ^ -col.z
	--)
	--//col = 1. - exp(-col);
	--// Gamma correction and screen presentation.
	return vec(col.x^.4545,col.y^.4545,col.z^.4545)
	--return GL.pow3( vector.max( col, vector_zero ), vector_one * 0.4545 )
end
--[[ MODULE/WRAPPER: Must be placed at bottom of module ]]--
local iResolution0:vec =iResolution-vec(1,1);local iResolution0_div:vec =iResolution0+vec(0,0,1);local tStart0:vec =vec(0,S.Actor_Res.y*(S.Actor_RenderNum-1));local tRes1:vec =S.Actor_Res;local tRes0:vec =S.Actor_Res-vec(1,1);local tEnd0:vec =tStart0+tRes0;local tScale:f64 =1;local C_Start:f64 =1+(((tStart0.y//tScale*tScale)-tStart0.y)*iResolution.x)
return function(T:f64,I:{vec},O:{vec})local c:f64 =C_Start;local i_Res0_y:f64 =iResolution0.y;for Y:f64 =tStart0.y//tScale*tScale,tEnd0.y,tScale do for X:f64 =tStart0.x,tEnd0.x,tScale do O[c]=Shader(I[c],vec(X,i_Res0_y-Y),T);c+=tScale;end;c+=iResolution.x*(tScale-1);end if tScale<=1 then return end;c=C_Start;for Y:f64 =0,tRes0.y do for X:f64 =tStart0.x,tEnd0.x do local uv:vec =vec(X,Y)//tScale*tScale;O[c]=O[uv.x+uv.y*iResolution.x+1];c+=1;end;end;end