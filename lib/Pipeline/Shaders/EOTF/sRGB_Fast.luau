--!strict
--!native
-- sRGB - Fast Approximation
local v_1: vector =			vector.one * 1
local v_0_625: vector =		vector.one * 0.625
local Reciprocal: vector =	vector.one / 4.8
return function( iTime: number, In: {vector}, Out: {vector} )
	for c = 1, #In do
		Out[c] = 
			( v_1 - In[c] ) * ( In[c] / ( In[c] + Reciprocal ) )
			+ In[c] * ( v_0_625 + In[c] * 0.375 )
	end
end