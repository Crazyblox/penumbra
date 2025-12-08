--!strict
--!native
-- sRGB - Piecewise function
-- Separate shader function for legacy purposes.
-- Pixel shader: Linear -> sRGB color space transform
-- Input is assumed to already be bound 0-1 linear RGB

-- Bypass (number) -> (vector) broadcast performance hit
local sRGB_Sub: vector =			vector.one * 0.055
local vector_zero =					vector.zero
local vector_one =					vector.one

return function( iTime: number, In: {vector}, Out: {vector} ) -- Optimized version
	-- SIMD Linear RGB -> sRGB conversion
	for i, RGB in In do
		-- Gamma Sign - Branchless, vector.sign acts as per-axis boolean for writing flat/gamma to x/y/z
		local Gamma_Sign: vector = vector.sign( RGB // 0.0031308 )
		-- Output
		Out[i] =
			-- sRGB: Flat portion
			( vector_one - Gamma_Sign ) * RGB * 12.92 +
			-- sRGB: Gamma portion
			Gamma_Sign * (
				1.055 * vector.create(
					RGB.x ^ 0.4166666666666667,
					RGB.y ^ 0.4166666666666667,
					RGB.z ^ 0.4166666666666667
				) - sRGB_Sub
			)
	end
end