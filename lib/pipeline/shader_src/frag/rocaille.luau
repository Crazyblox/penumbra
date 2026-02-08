--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Rocaille [Source: https://www.shadertoy.com/view/WXyczK]
local resLen:f64

local function main( O:vec, I:vec, iTime:f64 ):vec
	--// Vector for scaling and turbulence
	local v:vec = iRes;
	--// Centered and scaled coordinates
	local p:vec = (I+I-v)/v.y/.3;
	--// Layer & turbulence freq iter. +Color, attenuate w/ turbulent coords
	-- local O_Alpha:f64 = 0;
	for i_Layer:f64 = 1, 8 do
		local resLen:f64 = length(v);
		O += vec(
			cos( i_Layer + 0 ) + 1,
			cos( i_Layer + 1 ) + 1,
			cos( i_Layer + 2 ) + 1
		) / 6 / resLen; -- O_Alpha += ( cos( i_Layer + 3 ) + 1 ) / 6. / resLen;
		--// Turbulence loop [https://mini.gmshaders.com/p/turbulence]
		v = p;
		for f_Freq:f64 = 1, 8 do
			v += vec(
				sin(v.y * f_Freq + i_Layer + iTime ) / f_Freq,
				sin(v.x * f_Freq + i_Layer + iTime ) / f_Freq
			);
		end;
	end;
	--// Tanh tonemapping [https://www.shadertoy.com/view/ms3BD7]
	O*=O; -- O_Alpha*=O_Alpha;
	return vec(tanh(O.x),tanh(O.y),tanh(O.z));
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
