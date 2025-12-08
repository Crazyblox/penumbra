--!strict
--!native
-- Penumbra: Blank Template -  Read './lib/Pipeline/Fragment/Template' for more info --
type f64=number; type vec=vector
local S, Textures = require( "../../../Settings" ), require( "../../../Textures/init" )
local vec =	vector.create;local vec_1, vec_0_5, vec_0 = vec(1,1,1), vec(.5,.5,.5), vec(0,0);local iResolution:vec =vec(S.Display_Res.x,S.Display_Res.y);local iResolution_div:vec = iResolution+vec(0,0,1);
local radians, degrees, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, pow, exp, log, exp2, log2, sqrt, inversesqrt, abs, sign, floor, ceil, fract, mod, modf, min, max, clamp, mix, step, smoothstep, length, distance, dot, cross, normalize = -- Requiring implementation: asinh, acosh, atanh, exp2, inversesqrt, trunc, step, smoothstep, distance, faceforward, reflect, refract, determinant, outerProduct, matrixCompMult, inverse, transpose
	math.rad, math.deg, math.sin, math.cos, math.tan, math.asin, math.acos, math.atan, math.sinh, math.cosh, math.tanh, math.pow, math.exp, math.log, math.exp, function( n:f64 ):f64 return math.log( n, 2. ) end, math.sqrt, math.sqrt, math.abs, math.sign, math.floor, math.ceil, function( n:f64 ):f64 return n - math.floor(n) end, function( n:f64, m:f64 ):f64 return n % m end, math.modf, math.min, math.max, math.clamp, math.lerp, function( edge:f64, x:f64 ):f64 return x end, function(e0:f64,e1:f64,x:f64):f64 local t:f64=math.clamp((x-e0)/(e1-e0),0.,1.) return t*t*(3-2*t) end, vector.magnitude, vector.magnitude, vector.dot, vector.cross, vector.normalize  
local function Sampler_Nearest_Repeat(t:Textures.Texture,UV:vec):vec UV=vec(UV.x%1,UV.y%1)//t.FD;return t[ UV.x + UV.y * t.Width ]end;local function Sampler_Nearest_Clamp(t:Textures.Texture,UV:vec):vec UV=vector.clamp(UV//t.FD,vec_0,vec(t.Width0,t.Height0)); return t[UV.x+UV.y*t.Width];end;local function Sampler_Linear_Repeat(t:Textures.Texture,UV:vec):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y);end;local function Sampler_Linear_Clamp( t:Textures.Texture,UV:vec ):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);UV_0=vector.clamp(UV_0,vec_0,vec(t.Width0,t.Height0));UV_1=vector.clamp(UV_1,vec_0,vec(t.Width0,t.Height0));local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y)end
--[[ SHADER ]]--
--local iChannel0: Textures.Texture =	Textures.Load.Base( {}, "" )
local texture = Sampler_Linear_Repeat
local blob1:vec = vec(127.1,311.7,0)
local blob2:vec = vec(269.5,183.3,0)
local blob3:vec = vec(419.2,317.9,0)
local function Shader( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	local vec_noPreCalc:vec = vec(.5,.5)*(iTime*2.)+vec(.0,2.)
	local p_noPreCalc:vec = vec(.5,.5)-(vec(.5,.5)*vec(cos(vec_noPreCalc.x),cos(vec_noPreCalc.y)))
	for i = 1, 3 do
		p_noPreCalc = p_noPreCalc*p_noPreCalc*(vec(3,3)-vec(2,2)*p_noPreCalc)
	end
	local k_noPreCalc:f64 = 1 + 63 * pow(1.-p_noPreCalc.y,6.)

	-- NOT to be confused with `uv: vector` found below... Poorly named shader values.
	local u:f64 = p_noPreCalc.x
	local v:f64 = p_noPreCalc.y

	local uv:vec = fragCoord/iResolution.x 
	local p2:vec = uv * 24
	local i:vec = vector.floor(p2)
	local f:vec = vec(fract(p2.x),fract(p2.y))

	local a:f64 = 0
	local b:f64 = 0
	for y2 = -2, 2 do
		for x2 = -2, 2 do
			local g:vec = vec(x2,y2)
			local thing:vec = i + g
			local q:vec = vec(dot(thing,blob1),dot(thing,blob2),dot(thing,blob3))
			local o:vec = (vec(cos(q.x),cos(q.y),cos(q.z)))*43758.5453
			o = vec(fract(o.x),fract(o.y),fract(o.z))
			local o:vec = o*vec(u,u,1)
			local d:vec = g - f + vec(o.x,o.y)
			local w_noPreCalc:f64 = pow(1.-smoothstep(0.,1.414,length(d)),k_noPreCalc)
			a += o.z * w_noPreCalc
			b += w_noPreCalc
		end
	end

	local f:f64 = a/b
	local ratio:vec = f*((fragCoord-(iResolution/2.))/iResolution)
	ratio = vector.abs(ratio)

	return vec(sin(ratio.x),sin(ratio.y),sin(ratio.x+ratio.y))
end
--[[ MODULE/WRAPPER: Must be placed at bottom of module ]]--
local iResolution0:vec =iResolution-vec(1,1);local iResolution0_div:vec =iResolution0+vec(0,0,1);local tStart0:vec =vec(0,S.Actor_Res.y*(S.Actor_RenderNum-1));local tRes1:vec =S.Actor_Res;local tRes0:vec =S.Actor_Res-vec(1,1);local tEnd0:vec =tStart0+tRes0;local tScale:f64 =1;local C_Start:f64 =1+(((tStart0.y//tScale*tScale)-tStart0.y)*iResolution.x)
return function(T:f64,I:{vec},O:{vec})local c:f64 =C_Start;local i_Res0_y:f64 =iResolution0.y;for Y:f64 =tStart0.y//tScale*tScale,tEnd0.y,tScale do for X:f64 =tStart0.x,tEnd0.x,tScale do O[c]=Shader(I[c],vec(X,i_Res0_y-Y),T);c+=tScale;end;c+=iResolution.x*(tScale-1);end if tScale<=1 then return end;c=C_Start;for Y:f64 =0,tRes0.y do for X:f64 =tStart0.x,tEnd0.x do local uv:vec =vec(X,Y)//tScale*tScale;O[c]=O[uv.x+uv.y*iResolution.x+1];c+=1;end;end;end