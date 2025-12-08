--!strict
--!native
local vector_zero: vector = vector.zero
local vector_one: vector = vector.one
return function( iTime: number, In: {vector}, Out: {vector} )
	for c = 1, #In do
		Out[c] = vector.clamp( In[c], vector_zero, vector_one )
	end
end