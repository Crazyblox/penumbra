--!strict
--!native
-- Tonemapper: Reinhard RGB
local Burn: vector = vector.one
return function( iTime: number, In: {vector}, Out: {vector} )
	for c: number = 1, #In do
		Out[c] = In[c] / ( Burn + In[c] )
	end
end