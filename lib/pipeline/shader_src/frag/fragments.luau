--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Fragments [Source: https://www.shadertoy.com/view/3cScWy]
local fEnd:f64 = 6
local iTime_z: vec
local r_xxy:vec = vec(iRes.x, iRes.y, iRes.y);
local mul_vec2:vec = vec(1, 1, 0);
local nums:vec = vec(6,1,2);

local function main( O:vec, I:vec, t:f64 ):vec
	--//Iterator, raymarch depth, turbulence frequency and time
	local z:f64=0;
	--//Raymarch sample point
	local n_r_xxy:vec = normalize( I+I - r_xxy );
	--//Clear fragColor and raymarch 30 steps
	local p:vec; --local O_Alpha:f64=0
	for i:f64 = 1, 25 do
		p=(z*n_r_xxy)-iTime_z
		local f:f64=1;
		for f = 2, fEnd do
			local rnd:vec = vector.floor((p*6.)+vec_0_5)/3.*f;
			p += vec( sin(rnd.y), sin(rnd.x), sin(rnd.z) ) / f;
		end
		local len:f64 = length(p*mul_vec2);
		local cos_p:vec = vec(cos(p.x),cos(p.y),cos(p.z));
		local sin_p_yzx:vec = vec(sin(p.y),sin(p.z),sin(p.x)); 
		f = .003 + abs( len - 5. + dot(cos_p,sin_p_yzx) ) * .125;
		z += f;
		local wv:vec = vec_1 * (i*.3+z+t);
		wv += nums;
		O += vec(1+sin(wv.x),1+sin(wv.y),1+sin(wv.z))/f; --O_Alpha += ( 1 + sin(wv) ) / f;	
	end
	O *= .001;
	return vec(tanh(O.x), tanh(O.y), tanh(O.z)) -- * tanh(O_Alpha);
end

local function preprocess( iTime:f64 ): f64
	iTime *= .5
	iTime_z = vec(0, 0, iTime)
	return iTime
end
