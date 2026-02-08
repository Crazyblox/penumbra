--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Neuron
local vec_up = vec(0, 1, 0)
local ro, lookAt, fwd, right, up = vec(0,0,0), vec(0,0,0), vec(0,0,1), vec(1,0,0), vec(0,1,0)
local a = 2.51
local b_coeff = vec(0.0762, 0.0762, 0.0762)
local c_val = 2.43
local d_coeff = vec(0.59, 0.59, 0.59)
local e_coeff = vec(0.14, 0.14, 0.14)

local function mix(a: vec, b: vec, t: f64): vec
	if type(a) == "vector" then
		return vector.lerp(a, b, t)
	end
	return a + (b - a) * t
end

local function fract(x: f64): f64
	return x - floor(x)
end

local function hash12(x: f64, y: f64): f64
	local vx = fract(x * 0.1031)
	local vy = fract(y * 0.1031)
	local dot_val = vx * (vy + 33.33) + vy * (vx + 33.33)
	return fract((vx + vy) * dot_val)
end

local function noise2D(x: f64, y: f64): f64
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

local function noise3D_sim(p: vec, t: f64): f64
	local np = normalize(p)
	local npx, npy, npz = np.x, np.y, np.z
	local t_scaled = t / 20.0

	local scale = 20

	local s1 = scale
	local o1 = 0.0
	local a1 = noise2D((t_scaled + npx + o1) * s1, (t_scaled + npy + o1) * s1)
	local b1 = noise2D((t_scaled + 0.77 + npy + o1) * s1, (t_scaled + npz + o1) * s1)
	a1 = math.lerp(a1, 0.5, math.abs(npx))
	b1 = math.lerp(b1, 0.5, math.abs(npz))
	local n1 = math.lerp(a1 + b1 - 0.4, 0.5, math.abs(npy) * 0.5)

	local s2 = scale * 2.5
	local o2 = 5.2
	local a2 = noise2D((t_scaled + npx + o2) * s2, (t_scaled + npy + o2) * s2)
	local b2 = noise2D((t_scaled + 0.77 + npy + o2) * s2, (t_scaled + npz + o2) * s2)
	a2 = math.lerp(a2, 0.5, math.abs(npx))
	b2 = math.lerp(b2, 0.5, math.abs(npz))
	local n2 = math.lerp(a2 + b2 - 0.4, 0.5, math.abs(npy) * 0.5)

	return n1 * 0.7 + n2 * 0.3
end

local function rotateY(v: vec, angle: f64): vec
	local c, s = cos(angle), sin(angle)
	return vec(v.x*c + v.z*s, v.y, -v.x*s + v.z*c)
end

local function smin(a: f64, b: f64, k: f64): f64
	local h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return math.lerp(b, a, h) - k * h * (1.0 - h)
end

local function map(p: vec, iTime: f64): f64
	local n_val = noise3D_sim(p, iTime)
	local len_p = length(p)

	local d = (-1.0 * len_p + 3.0) + 1.5 * n_val
	d = min(d, (len_p - 1.5) + 1.5 * n_val)

	local m = 1.5
	local s = 0.03

	local ax = abs(p.x)
	local ay = abs(p.y)
	local az = abs(p.z)

	d = smin(d, max(ax - s, abs(p.y + p.z * 0.2) - 0.07), m)
	d = smin(d, max(az - s, abs(p.x + p.y * 0.5) - 0.07), m)
	d = smin(d, max(abs(p.z - p.y * 0.4) - s, abs(p.x - p.y * 0.2) - 0.07), m)
	d = smin(d, max(abs(p.z * 0.2 - p.y) - s, abs(p.x + p.z) - 0.07), m)
	d = smin(d, max(abs(p.z * -0.2 + p.y) - s, abs(-p.x + p.z) - 0.07), m)

	return d
end

local function main(fragColor: vec, fragCoord: vec, iTime: f64): vec

	local uv = vec(-1, -1, 0) + (vec(2, 2, 0) * fragCoord) / vec(iRes.x, iRes.y, 1)
	uv = vec(uv.x * (iRes.x / iRes.y), uv.y, 0)

	local ray = normalize(vec(uv.x, uv.y, 1.0))

	local color = vec_0
	local rayCount = 128
	local iEnd:f64 = rayCount
	local t = 0.0
	local r:f64 = 1
	local d:f64 = 1
	local p:vec
	local endLoop:boolean = false
	while not endLoop do
		p = vec(0, 0, -3.0) + ray * t

		p = rotateY(p, iTime * 0.1)
		p = rotateY(p, iTime / 3.0)

		-- float mask = max(0.,(1.-length(p/3.)))
		local mask = max(0.0, 1.0 - length(p / 3.0))

		-- p = rotateY(p,mask*sin(iTime/2.)*1.2)
		p = rotateY(p, mask * sin(iTime / 2.0) * 1.2)

		-- p.y += sin(iTime+p.x)*mask*.5
		p = vec(p.x, p.y + sin(iTime + p.x) * mask * 0.5, p.z)

		-- p *= 1.1+(sin(iTime/2.)*mask*.3)
		p *= 1.1 + (sin(iTime / 2.0) * mask * 0.3)

		d = map(p, iTime)

		t += d * .6

		r += 1;

		endLoop = if d < .02 or r == rayCount then true else false

		--r += 1;
	end

	local iter = r / rayCount
	local ao = (1.0 - iter)
	ao *= ao
	ao = 1.0 - ao

	local mask_col = max(0.0, 1.0 - length(p / 2.0))
	mask_col *= abs(sin(iTime * -1.5 + length(p) + p.x) - 0.2)

	local n_val = noise3D_sim(p, iTime)
	local noise_term = max(0.0, (n_val * 4.0 - 2.6))

	color += vec(0.2, 2.0, 1.6) * noise_term * mask_col
	color += vec(0.12, 0.45, 0.7) * ao * 6.0
	color += vec(0.27, 0.2, 0.4) * (t / 8.0)
	color *= 2.0
	color -= vec(0.15, 0.15, 0.15)

	--[[
	for r = 1, rayCount do
		local p = vec(0, 0, -3.0) + ray * t

		p = rotateY(p, iTime * 0.1)
		p = rotateY(p, iTime / 3.0)

		-- float mask = max(0.,(1.-length(p/3.)))
		local mask = max(0.0, 1.0 - length(p / 3.0))

		-- p = rotateY(p,mask*sin(iTime/2.)*1.2)
		p = rotateY(p, mask * sin(iTime / 2.0) * 1.2)

		-- p.y += sin(iTime+p.x)*mask*.5
		p = vec(p.x, p.y + sin(iTime + p.x) * mask * 0.5, p.z)

		-- p *= 1.1+(sin(iTime/2.)*mask*.3)
		p *= 1.1 + (sin(iTime / 2.0) * mask * 0.3)

		local d = map(p, iTime)

		if d < 0.01 or r == rayCount then
			local iter = r / rayCount
			local ao = (1.0 - iter)
			ao = ao * ao
			ao = 1.0 - ao

			local mask_col = max(0.0, 1.0 - length(p / 2.0))
			mask_col *= abs(sin(iTime * -1.5 + length(p) + p.x) - 0.2)

			local n_val = noise3D_sim(p, iTime)
			local noise_term = max(0.0, (n_val * 4.0 - 2.6))

			color += vec(0.2, 2.0, 1.6) * noise_term * mask_col

			color += vec(0.12, 0.45, 0.7) * ao * 6.0

			color += vec(0.27, 0.2, 0.4) * (t / 8.0)

			color *= 2.0
			color -= vec(0.15, 0.15, 0.15)
			break
		end

		t += d * 0.6
	end
	]]

	local uv_vig = vec(fragCoord.x / iRes.x, fragCoord.y / iRes.y, 0)
	uv_vig = uv_vig * (vec(1.0, 1.0, 0) - vec(uv_vig.y, uv_vig.x, 0))

	local vig = uv_vig.x * uv_vig.y * 20.0
	vig = pow(vig, 0.25)

	color *= vig
	color = vec(color.x * 1.5, color.y * 0.8, color.z)

	color *= .6
	local num = color * (color * a + b_coeff)
	local den = color * (color * c_val + d_coeff) + e_coeff
	local color_mapped = num / den
	return vector.clamp(color_mapped, vec_0, vec_1)
end


local function preprocess(iTime:f64): f64
	iTime *= .66;
	ro = vec(0.0, 1.0, 6.0)
	lookAt = vec(sin(iTime*0.62222), cos(iTime*0.7428765235), -20.0)
	fwd = normalize(lookAt - ro)
	right = normalize(cross(fwd, vec_up))
	up = normalize(cross(right, fwd))
	return iTime
end
