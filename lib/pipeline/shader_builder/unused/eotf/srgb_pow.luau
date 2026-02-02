--!strict
--!native
-- sRGB Pow approximation
local vector_zero: vector = vector.zero
local vector_one: vector = vector.one
return function( iTime: number, In: {vector}, Out: {vector} )
	for c: number, RGB: vector in In do
		Out[c] = vector.create(RGB.x^.4545,RGB.y^.4545,RGB.z^.4545)
	end
end
