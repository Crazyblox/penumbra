--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Mandelbrot Pattern Decoration [Source: https://www.shadertoy.com/view/ttscWn]
-- VARIABLES
local AA:f64 = 2
local AA0:f64 = AA - 1
local AA2_Reciprocal:f64 = 1 / (AA*AA)
local iter:f64 = 128
local fog:vec = vec_0
-- preprocessables
local ttm:f64, c:f64, s:f64, zm:f64

-- FUNCTIONS
local function xzy(v: vec): vec return vec(v.x, v.z, v.y) end
local function yxz(v: vec): vec return vec(v.y, v.x, v.z) end

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec
	fragColor = vec_0 -- Set to black.

	for j = 0, AA0 do
		for i = 0, AA0 do
			local p = (fragCoord + vec(i, j)/AA - iRes*.5)/iRes.y
			p = vec(c * p.x - s * p.y, s * p.x + c * p.y)
			p -= vec(cos(iTime/2.)/2., sin(iTime/3.)/5.)

			local cc = vec(-.57735 + .004, .57735) + p/zm
			local z, dz = vec_0, vec_0

			local ik:f64 = 128
			local zDot:f64
			for k = 0, iter - 1 do
				dz = vec((z.x * dz.x - z.y * dz.y) * 2. + 1., (z.y * dz.x + z.x * dz.y) * 2.)
				z = vec(z.x * z.x - z.y * z.y, 2. * z.x * z.y) + cc
				zDot = dot(z, z)
				if zDot > 1/.005 then
					ik = k
					break
				end
			end

			local ln = step(0, length(z)/15.5 - 1)
			local d = sqrt(1/max(length(dz), .0001))*log(zDot)
			d = clamp(d*50, 0, 1)

			local dir = if mod(ik, 2) < .5 then -1 else 1
			local sh = (iter-ik)/iter
			local tuv = z/320

			local tm = (-ttm*sh*sh*16)
			local c = cos(tm)
			local s = sin(tm)

			tuv = vec(c * tuv.x - s * tuv.y, s * tuv.x + c * tuv.y)
			tuv = vec(
				abs(mod(tuv.x, 1/8) - 1/16),
				abs(mod(tuv.y, 1/8) - 1/16)
			)

			local pat = smoothstep(0, 1/length(dz), length(tuv) - 1/32)
			pat = min(pat, smoothstep(0, 1/length(dz), abs(max(tuv.x, tuv.y) - 1/16) - .04/16))

			local minVal = min(d * .85, .96)
			local lCol:vec = vector.min( vec( 1.5, 1, 1 ) * minVal, vec( 1, 3, 16 ) )
			lCol = vec( pow(lCol.x, 1), pow(lCol.y, 3), pow(lCol.z, 16) )
			lCol *= 1.15

			lCol =
				if dir < 0 then
				lCol * min(pat, ln)
				else
				vec(sqrt(lCol.x) * 0.5 + 0.7, sqrt(lCol.y) * 0.5 + 0.7, sqrt(lCol.z) * 0.5 + 0.7) * max(1 - pat, 1 - ln)

			local rd = normalize(vec(p.x, p.y, 1))
			rd = rd - 2 * dot(vec(0, 0, -1), rd) * vec(0, 0, -1)

			local diff = clamp(dot(z*.5 + vec_0_5, vec(rd.x, rd.y, 0)), 0, 1)*d

			tuv = z/200
			tm = -tm/1.5 + .5
			local c = cos(tm)
			local s = sin(tm)
			tuv = vec(c * tuv.x - s * tuv.y, s * tuv.x + c * tuv.y)
			tuv = vec(
				abs(mod(tuv.x, 1/8) - 1/16),
				abs(mod(tuv.y, 1/8) - 1/16)
			)
			pat = smoothstep(0., 1./length(dz), length(tuv) - 1./32.);
			pat = min(pat, smoothstep(0., 1./length(dz), abs(max(tuv.x, tuv.y) - 1./16.) - .04/16.));

			local gloss:vec = vector.lerp(lCol, vec_1 * ln, .5)
			gloss = gloss * diff * diff * .5 * (pat * .6 + .6)
			lCol += gloss

			lCol = if mod(ik, 6) < .5 then yxz(lCol) else lCol

			local d_factor:f64 = d / 1.2
			lCol *= d_factor
			lCol += xzy(lCol) * (1 - d_factor)

			local fringe_factor = (1 - step(0, -(length(z) * .05 * ik / iter - 1))) * .95
			lCol *= 1 - fringe_factor

			local mixFactor = sh * d
			lCol *= mixFactor
			lCol += fog * ( 1 - mixFactor )

			fragColor += vector.min(lCol, vec_1)
		end
	end

	fragColor *= AA2_Reciprocal

	fragColor = ( vec_1 - vec( exp( -fragColor.x ), exp( -fragColor.y ), exp( -fragColor.z ) ) ) * 1.25

	local uv:vec = fragCoord/iRes
	fragColor *= pow( 16 * ( 1 - uv.x ) * ( 1 - uv.y ) * uv.x * uv.y, 1/8 ) * 1.15
	fragColor = vec( sqrt( fragColor.x ), sqrt( fragColor.y ), sqrt( fragColor.z ) )

	-- NaN is propagating from somewhere but it never used to!! ...Luau regression?
	fragColor = vec(
		math.isnan( fragColor.x ) and 0 or fragColor.x,
		math.isnan( fragColor.y ) and 0 or fragColor.y,
		math.isnan( fragColor.z ) and 0 or fragColor.z
	)
	return vector.clamp( fragColor, vec_0, vec_1 )
end

local function preprocess( iTime:f64 ): f64
	ttm = cos(sin(iTime/8.))*6.2831
	c = cos(ttm)
	s = sin(ttm)
	zm = (200 + sin(iTime/7)*50)
	return iTime
end
