--!strict
--!native
-- Penumbra: Fragment Shader - Creation [Source: https://www.shadertoy.com/view/XsXXDn]
type f64=number; type vec=vector
local S, Textures = require( "../../../Settings" ), require( "../../../Textures/init" )
local vec =	vector.create;local vec_1, vec_0_5, vec_0 = vec(1,1,1), vec(.5,.5,.5), vec(0,0);local iResolution:vec =vec(S.Display_Res.x,S.Display_Res.y);local iResolution_div:vec = iResolution+vec(0,0,1);
local radians, degrees, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, pow, exp, log, exp2, log2, sqrt, inversesqrt, abs, sign, floor, ceil, fract, mod, modf, min, max, clamp, mix, step, smoothstep, length, distance, dot, cross, normalize = -- Requiring implementation: asinh, acosh, atanh, exp2, inversesqrt, trunc, step, smoothstep, distance, faceforward, reflect, refract, determinant, outerProduct, matrixCompMult, inverse, transpose
	math.rad, math.deg, math.sin, math.cos, math.tan, math.asin, math.acos, math.atan, math.sinh, math.cosh, math.tanh, math.pow, math.exp, math.log, math.exp, function( n:f64 ):f64 return math.log( n, 2. ) end, math.sqrt, math.sqrt, math.abs, math.sign, math.floor, math.ceil, function( n:f64 ):f64 return n - math.floor(n) end, function( n:f64, m:f64 ):f64 return n % m end, math.modf, math.min, math.max, math.clamp, math.lerp, function( edge:f64, x:f64 ):f64 return x end, function( a:f64, b:f64, x:f64 ):f64 return x end, vector.magnitude, vector.magnitude, vector.dot, vector.cross, vector.normalize  
local function Sampler_Nearest_Repeat(t:Textures.Texture,UV:vec):vec UV=vec(UV.x%1,UV.y%1)//t.FD;return t[ UV.x + UV.y * t.Width ]end;local function Sampler_Nearest_Clamp(t:Textures.Texture,UV:vec):vec UV=vector.clamp(UV//t.FD,vec_0,vec(t.Width0,t.Height0)); return t[UV.x+UV.y*t.Width];end;local function Sampler_Linear_Repeat(t:Textures.Texture,UV:vec):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y);end;local function Sampler_Linear_Clamp( t:Textures.Texture,UV:vec ):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);UV_0=vector.clamp(UV_0,vec_0,vec(t.Width0,t.Height0));UV_1=vector.clamp(UV_1,vec_0,vec(t.Width0,t.Height0));local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y)end
--[[ SHADER ]]--
local iChannel0: Textures.Texture =	Textures.Load.Base( {}, "Abstract3" )
local texture = Sampler_Linear_Repeat
local c = {0,0,0}
local function Shader( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local uv:vec = fragCoord/iResolution
	local c = c
	c[1], c[2], c[3] = 0, 0, 0
	local l:f64, z:f64 = iTime, iTime
	for i = 1, 3 do
		local p:vec = fragCoord/iResolution
		p=vec(p.x,p.y)
		local cuv:vec = p
		p -= vec(.5,.5)
		p *= vec(iResolution.x/iResolution.y,1,1)
		z += .07
		l = length(p)
		cuv += p / l * ( sin( z ) + 1 ) * abs( sin( l * 9 - z - z ) )
		c[i] = .01 / length( cuv - ( cuv // 1 ) - vec(.5,.5) )
	end
	return ( vec(c[1],c[2],c[3]) / l ) --* texture( iChannel0, uv*(16*0.6666) )
end
--[[ MODULE/WRAPPER: Must be placed at bottom of module ]]--
local iResolution0:vec =iResolution-vec(1,1);local iResolution0_div:vec =iResolution0+vec(0,0,1);local tStart0:vec =vec(0,S.Actor_Res.y*(S.Actor_RenderNum-1));local tRes1:vec =S.Actor_Res;local tRes0:vec =S.Actor_Res-vec(1,1);local tEnd0:vec =tStart0+tRes0;local tScale:f64 =1;local C_Start:f64 =1+(((tStart0.y//tScale*tScale)-tStart0.y)*iResolution.x)
return function(T:f64,I:{vec},O:{vec})local c:f64 =C_Start;local i_Res0_y:f64 =iResolution0.y;for Y:f64 =tStart0.y//tScale*tScale,tEnd0.y,tScale do for X:f64 =tStart0.x,tEnd0.x,tScale do O[c]=Shader(I[c],vec(X,i_Res0_y-Y),T);c+=tScale;end;c+=iResolution.x*(tScale-1);end if tScale<=1 then return end;c=C_Start;for Y:f64 =0,tRes0.y do for X:f64 =tStart0.x,tEnd0.x do local uv:vec =vec(X,Y)//tScale*tScale;O[c]=O[uv.x+uv.y*iResolution.x+1];c+=1;end;end;end