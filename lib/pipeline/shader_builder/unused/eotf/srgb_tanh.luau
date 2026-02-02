--!strict
--!native
-- sRGB Tanh approximation
local vector_zero: vector = vector.zero
return function( iTime: number, In: {vector}, Out: {vector} )
	for c: number, RGB: vector in In do
		Out[c] = vector.create(math.tanh(RGB.x),math.tanh(RGB.y),math.tanh(RGB.z))
	end
end
