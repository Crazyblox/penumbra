--!strict
--!native
-- sRGB - Fastest Approximation - Highly inaccurate, performance tradeoff not really worth it
local v_1: vector =		vector.one
local v_0_225: vector =	vector.one * 0.225
return function( iTime: number, In: {vector}, Out: {vector} )
	for c = 1, #In do
		Out[c] = ( In[c] * ( In[c] * .225 + v_1 ) ) / ( In[c] + v_0_225 )
	end
end