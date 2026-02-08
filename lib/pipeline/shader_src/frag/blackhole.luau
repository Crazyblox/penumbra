--!nocheck
--!nolint
--/INLINE
local iChannel0: Textures.Texture = Textures.Load.Base( {}, "rustymetal" )
local texture = Sampler_Nearest -- Sampler_Nearest_IL, Sampler_Linear, Sampler_BoxBlur, Sampler_Unsharp

local PI: f64 = math.pi
local ro: vec = vec(0.0, 2.0, 14.0)
local lookAt: vec = vec(0.0, 0.0, 0.0)
local fwd: vec = vec(0,0,-1)
local right: vec = vec(1,0,0)
local up: vec = vec(0,1,0)
local vec_up: vec = vec(0,1,0)
local a = 2.51
local b_coeff = vec(0.0762, 0.0762, 0.0762) -- 2.54 * 0.03
local c_val = 2.43
local d_coeff = vec(0.59, 0.59, 0.59)
local e_coeff = vec(0.14, 0.14, 0.14)

local function mix(a: vec, b: vec, t: f64): vec
	return vector.lerp(a, b, t)
end

local function fract(x: f64): f64
	return x - floor(x)
end

local function smoothstep(edge0: f64, edge1: f64, x: f64): f64
	local t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
end

local function hash12(x: f64, y: f64): f64
	local vx = fract(x * 0.1031)
	local vy = fract(y * 0.1031)
	local dot_val = vx * (vy + 33.33) + vy * (vx + 33.33)
	return fract((vx + vy) * dot_val)
end

local function noise(x: f64, y: f64): f64
	local i_x = floor(x)
	local i_y = floor(y)
	local f_x = fract(x)
	local f_y = fract(y)

	local u_x = f_x * f_x * (3.0 - 2.0 * f_x)
	local u_y = f_y * f_y * (3.0 - 2.0 * f_y)

	local a = hash12(i_x, i_y)
	local b = hash12(i_x + 1.0, i_y)
	local c = hash12(i_x, i_y + 1.0)
	local d = hash12(i_x + 1.0, i_y + 1.0)

	return math.lerp(math.lerp(a, b, u_x), math.lerp(c, d, u_x), u_y)
end

local function rotateY(v: vec, a: f64): vec
	local c, s = cos(a), sin(a)
	return vec(v.x*c + v.z*s, v.y, -v.x*s + v.z*c)
end

local function rotateX(v: vec, a: f64): vec
	local c, s = cos(a), sin(a)
	return vec(v.x, v.y*c - v.z*s, v.y*s + v.z*c)
end

local function blackbody(temp: f64): vec
	local t = temp * 3.0
	local r = clamp(t * 1.5, 0.0, 1.0) + 0.3 * exp(-pow(t - 3.5, 2.0))
	local g = clamp(t - 0.8, 0.0, 1.0)
	local b = clamp(t - 1.8, 0.0, 1.0) 

	local col = vec(r, g, b)
	col *= col

	local orange = vec(1.0, 0.6, 0.1)
	local mix_amt = smoothstep(0.0, 0.5, abs(temp - 0.4))
	return mix(col, orange, mix_amt * 0.5)
end

local function skyColor(rd: vec): vec
	local bg = vec(0.005, 0.005, 0.01)

	local scaled = rd * 350.0
	local sid = vec(floor(scaled.x), floor(scaled.y), floor(scaled.z))
	local h = hash12(sid.x + sid.y * 113.0, sid.z * 57.0)

	local star = 0.0
	if h > 0.992 then
		local b = smoothstep(0.992, 1.0, h)
		star = b * 3.0
	end

	return bg + vec(star, star, star)
end

local function traceBlackHole(ro0: vec, rd0: vec, iTime: f64): vec
	local BH_MASS = 1.0
	local RS = 2.0 * BH_MASS
	local PHOTON_SPHERE = 1.5 * RS
	local ACCRETION_IN = 3.0 * RS
	local ACCRETION_OUT = 14.0 * RS

	local diskTilt = 0.3 -- radians
	local cosT, sinT = cos(diskTilt), sin(diskTilt)

	local p = ro0
	local v = rd0
	local col = vec_0
	local trans = 1.0 -- transmittance
	local min_dist = 1e9

	local iter = 0
	local max_iter = 128 -- steps
	local step_size = 0.3

	local escape_limit = 40.0 * RS

	local function toDiskSpace(pt: vec): vec
		return vec(pt.x, pt.y * cosT - pt.z * sinT, pt.y * sinT + pt.z * cosT)
	end

	while iter < max_iter do
		iter += 1

		local r2 = dot(p, p)
		local r = sqrt(r2)
		min_dist = min(min_dist, r)

		if r < RS * 1.01 then
			trans = 0.0
			break
		end

		if r > escape_limit then
			col += skyColor(v) * trans
			break
		end

		--a = -1.5 * Rs * (h^2 / r^5) * r_vec
		--where h = |r x v| (angular momentum per unit mass)
		local crossP = cross(p, v)
		local h2 = dot(crossP, crossP) -- magnitude squared of angular momentum

		--divide by r^5. Since we have r2 (r^2), r^5 = r2 * r2 * r
		local r5 = r2 * r2 * r
		local geodesicTerm = -1.5 * RS * h2 / max(r5, 1e-4)

		local acc = p * geodesicTerm

		local dt = step_size * r * 0.12

		dt = max(dt, 0.005)

		v = normalize(v + acc * dt)
		p += v * dt

		local pd = toDiskSpace(p)
		local diskH = abs(pd.y)
		local diskR = sqrt(pd.x*pd.x + pd.z*pd.z)

		local thickness = 0.25 + (diskR * 0.06)

		if diskH < thickness and diskR > ACCRETION_IN and diskR < ACCRETION_OUT then
			local phi = math.atan2(pd.z, pd.x)

			local angularSpeed = 1.5 / sqrt(diskR)
			local rotPhi = phi + iTime * angularSpeed

			local noiseScale = 4.0
			local n1 = noise(diskR * 0.5 - iTime * 0.5, rotPhi * 3.0 + diskR * 0.2)
			local n2 = noise(diskR * 1.5, rotPhi * 12.0 - diskR * 0.5)
			local plasma = n1 * 0.7 + n2 * 0.3

			local fadeInner = smoothstep(ACCRETION_IN, ACCRETION_IN * 1.1, diskR)
			local fadeOuter = smoothstep(ACCRETION_OUT, ACCRETION_OUT * 0.5, diskR)
			local verticalFade = smoothstep(thickness, 0.0, diskH)

			local density = plasma * fadeInner * fadeOuter * verticalFade * 0.8

			if density > 0.01 then
				local temp = pow(ACCRETION_IN / diskR, 1.3)

				local redshift = sqrt((r - RS) / r)
				redshift = clamp(redshift, 0.05, 1.0)
				temp *= redshift

				local baseColor = blackbody(temp)

				local velDirDisk = vec(-sin(phi), 0, cos(phi))
				local velDirWorld = vec(velDirDisk.x, velDirDisk.y * cosT + velDirDisk.z * sinT, -velDirDisk.y * sinT + velDirDisk.z * cosT)

				local viewDotVel = dot(v, velDirWorld)
				--  dt = 1 / (g * (1 - b * cos(t)))
				local doppler = pow(1.0 / (1.0 - 0.45 * viewDotVel), 3.5)

				local emission = baseColor * density * doppler * 1.5 * redshift

				local stepAbsorb = density * 0.5 * dt
				local w = min(1.0, stepAbsorb)

				col += emission * (trans * w)
				trans *= (1.0 - w)

				if trans < 0.01 then break end
			end
		end
	end

	local photonSphere = PHOTON_SPHERE
	local ringWidth = 0.2
	if trans > 0.0 and min_dist > photonSphere and min_dist < photonSphere + ringWidth then
		local intensity = smoothstep(photonSphere + ringWidth, photonSphere, min_dist)
		col += vec(1.0, 0.95, 0.85) * intensity * 0.4 * trans
	end

	return col
end

local function main(_: vec, fragCoord: vec, iTime: f64): vec
	-- [-1, 1]
	local uv = vec(-1, -1, 0) + (vec(2,2,0) * fragCoord) / vec(iRes.x, iRes.y, 1)
	uv = vec(uv.x * (iRes.x / iRes.y), uv.y, 0)

	local camPos = ro
	local camDist = 16.0
	local camSpeed = 0.08
	camPos = vec(sin(iTime * camSpeed) * camDist, 3.5 + cos(iTime * 0.15) * 1.5, cos(iTime * camSpeed) * camDist)

	local fwd = normalize(vec(0,0,0) - camPos)
	local right = normalize(cross(fwd, vec(0,1,0)))
	local up = normalize(cross(right, fwd))

	local rd = normalize(fwd + right * uv.x + up * uv.y)
	local col = traceBlackHole(camPos, rd, iTime)
	col *= .6 -- exposure
	-- (x * (a * x + b)) / (x * (c * x + d) + e)
	local num = col * (col * a + b_coeff)
	local den = col * (col * c_val + d_coeff) + e_coeff
	return vector.clamp(num / den, vec_0, vec_1)
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
