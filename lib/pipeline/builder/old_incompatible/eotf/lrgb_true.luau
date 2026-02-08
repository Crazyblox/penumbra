--!strict
--!native
-- lRGB - Piecewise function
-- Separate shader function for legacy purposes.
-- Pixel shader: sRGB -> lRGB color space transform
-- Input is assumed to already be bound 0-1 sRGB

local sRGB_Sub: vector =			vector.one * 0.055
local vector_zero =					vector.zero
local vector_one =					vector.one

return function( iTime: number, In: {vector}, Out: {vector} )
	for i, RGB in In do
		-- Gamma Sign - Branchless, vector.sign acts as per-axis boolean for writing flat/gamma to x/y/z
		local Gamma_Sign: vector = vector.sign( RGB // 0.04045 )
		-- Output
		local Gamma_RGB: vector = (RGB+sRGB_Sub)/1.055 
		Out[i] =
			-- Flat portion
			( vector_one - Gamma_Sign ) * (RGB/12.92) +
			-- Gamma portion
			Gamma_Sign * vector.create(
					Gamma_RGB.x ^ 2.4,
					Gamma_RGB.y ^ 2.4,
					Gamma_RGB.z ^ 2.4
				)
	end
end
