--!strict
--!native
-- Tonemapper: AcesFilm [Source: https://www.shadertoy.com/view/W3lfRN]
local v_1: vector =			vector.one * 1
local v_0: vector =			vector.zero
local v_0_625: vector =		vector.one * 0.625
local v_0_003: vector =		vector.one * 0.003
local v_0_59: vector =		vector.one * 0.59
local v_0_14: vector =		vector.one * 0.14
local Reciprocal: vector =	vector.one / 4.8
local function Shader( x: vector ): vector
	return vector.clamp( ( x * ( 2.51 * x + v_0_003 ) ) / ( x * ( 2.43 * x + v_0_59 ) + v_0_14 ), v_0, v_1 )
end
return function( iTime: number, In: {vector}, Out: {vector} )
	for c = 1, #In do Out[c] = Shader( In[c] ) end
end
