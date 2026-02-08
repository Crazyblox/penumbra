--!nocheck
--!nolint
--/INLINE
--local iChannel0: Textures.Texture = Textures.Load.Base( {}, "rustymetal" )
local texture = Sampler_Nearest -- Sampler_Nearest_IL, Sampler_Linear, Sampler_BoxBlur, Sampler_Unsharp

local vec_3, vec_2 = vec(3, 3, 3), vec(2, 2, 2)
local vec_up = vec(0, 1, 0)
local ro: vec = vec(0.0, 1.0, 6.0)
local lookAt: vec = vec(0.0, -0.5, -20.0)
local fwd: vec = vec(0,0,-1)
local right: vec = vec(1,0,0)
local up: vec = vec(0,1,0)
local SKY_SUN_DIR = vector.normalize(vec(0.0, 0.2, -1.0))
local SUN_DIR = vector.normalize(vec(0.3, 0.5, -0.8))

local function length2(x: number, z: number): number
	return sqrt(x*x + z*z)
end

local function smoothstep(edge0: f64, edge1: f64, x: f64): f64
	local t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
end

local function lerp(a: f64, b: f64, t: f64): f64
	return a + (b - a) * t
end

local function mix(a: vec, b: vec, t: f64): vec
	return vector.lerp(a, b, t)
end

local function floor_v(v: vec): vec
	return vec(floor(v.x), floor(v.y), floor(v.z))
end

local function fract(x: f64): f64
	return x - floor(x)
end

local function reflect_vec(i: vec, n: vec): vec
	return i - n * (2.0 * dot(i, n))
end

local function rot2(x:number, y:number, a:number): (number, number)
	local c,s = cos(a), sin(a)
	return x*c - y*s, x*s + y*c
end

local function sdBox(p:vec, b:vec): number
	local q = vec(abs(p.x), abs(p.y), abs(p.z)) - b
	local mx = max(q.x, 0); local my = max(q.y, 0); local mz = max(q.z, 0)
	return sqrt(mx*mx + my*my + mz*mz) + min(max(q.x, max(q.y,q.z)), 0)
end

local function sdCylY(p:vec, r:number, h:number): number
	local d1 = length2(p.x, p.z) - r
	local d2 = abs(p.y) - h
	local ax = max(d1, 0)
	local ay = max(d2, 0)
	return min(max(d1, d2), 0) + sqrt(ax*ax + ay*ay)
end

local function sdSegment2D(px:number,py:number, x1:number,y1:number, x2:number,y2:number, r:number): number
	local vx, vy = x2-x1, y2-y1
	local wx, wy = px-x1, py-y1
	local vv = vx*vx + vy*vy
	local t = 0.0
	if vv > 1e-6 then
		t = clamp((wx*vx + wy*vy) / vv, 0, 1)
	end
	local cx = x1 + vx*t
	local cy = y1 + vy*t
	local dx = cx - px
	local dy = cy - py
	return sqrt(dx*dx + dy*dy) - r
end

local function sdBird2D(x:number, y:number, flap:number): number
	local wing = 0.18 + 0.08*flap
	local ax, ay = 0.0, 0.0
	local bx, by = -wing, 0.10
	local cx, cy =  wing, 0.10
	local d1 = sdSegment2D(x,y, ax,ay, bx,by, 0.02)
	local d2 = sdSegment2D(x,y, ax,ay, cx,cy, 0.02)
	return min(d1,d2)
end

local function hash(n: f64): f64
	n = fract(n * 0.1031)
	n *= n + 33.33
	n *= n + n
	return fract(n)
end

local function noise(x: vec): f64
	local p = floor_v(x)
	local f = x - p
	f = f * f * (vec_3 - vec_2 * f)
	local n = p.x + p.y * 57.0 + p.z * 113.0

	return lerp(lerp(lerp( hash(n+0.0), hash(n+1.0), f.x),
		lerp( hash(n+57.0), hash(n+58.0), f.x), f.y),
		lerp(lerp( hash(n+113.0), hash(n+114.0), f.x),
			lerp( hash(n+170.0), hash(n+171.0), f.x), f.y), f.z)
end

local function fbm(p: vec): number
	local f = 0.0
	f += 0.5 * noise(p); p *= 2.0
	f += 0.25 * noise(p); p *= 2.0
	f += 0.125 * noise(p)
	return f
end

local function birdsMask(rd:vec, iTime:number): number
	if rd.y < 0.02 then return 0 end

	local denom = max(0.25, -rd.z)
	local u = rd.x / denom
	local v = rd.y / denom

	local mask = 0.0
	for i=0,7 do
		local fi = i + 13.37

		local px = lerp(-0.85, 0.85, hash(fi*10.1))
		local py = lerp( 0.18, 0.80, hash(fi*20.2))
		local sp = lerp( 0.10, 0.22, hash(fi*30.3))

		local t = iTime*0.08 + hash(fi*40.4)*10.0
		local dx = (fract(t) - 0.5) * 1.2
		local dy = 0.05*sin(t*2.0 + fi)

		local x = (u - (px+dx)) / sp
		local y = (v - (py+dy)) / sp

		local ang = (hash(fi*50.5)-0.5)*0.6
		x,y = rot2(x,y, ang)

		local flap = sin(iTime*6.0 + fi)*0.5 + 0.5
		local d = sdBird2D(x,y, flap)
		local a = smoothstep(0.04, 0.0, d)
		mask = max(mask, a)
	end
	return clamp(mask, 0, 1)
end

local function map(p: vec, iTime: f64): vector
	-- sand
	local floor_base = 1.0 - p.z * 0.08
	local d_floor = p.y + floor_base
	if p.z > -50 then
		if abs(d_floor) < 1.5 then
			d_floor += noise(p * 0.1) * 0.5 + noise(p * 0.5) * 0.1
		end
	end

	-- water
	local wave = 0.15 * sin(p.z * 0.8 + iTime) * sin(p.x * 0.1 + iTime * 0.5)
	wave += 0.05 * sin(p.z * 2.0 + iTime * 2.0)
	local d_water = p.y + 1.8 + wave

	-- sea stacks
	local d_stacks = 100.0
	if p.z < -10.0 and abs(p.x) < 10.0 then
		local p_s1 = p - vec(-3.0, -1.0, -18.0)
		local d_stack1 = length2(p_s1.x, p_s1.z) - 2.5 + p_s1.y * 0.3

		local p_s2 = p - vec(2.5, -1.5, -24.0)
		local d_stack2 = length2(p_s2.x, p_s2.z) - 3.0 + p_s2.y * 0.4

		local dsMin = min(d_stack1, d_stack2)
		if abs(dsMin) < 1.5 then
			d_stack1 += fbm(p_s1 * 0.8) * 1.5
			d_stack2 += fbm(p_s2 * 0.7) * 1.8
			d_stacks = min(d_stack1, d_stack2)
		else
			d_stacks = dsMin
		end
	end

	local d_cave = 100.0
	if p.z > -10.0 then
		local tunnel_radius = 5.5 - fbm(p * 0.6) * 3.5
		local d_cave_tunnel = -(length(vec(p.x, p.y, 0)) - tunnel_radius)
		d_cave = max(d_cave_tunnel, -(p.z + 5.0))
	end

	local d_ship = 100.0
	if p.z < -18.0 and p.z > -70.0 and abs(p.x) < 18.0 and p.y > -6.0 and p.y < 6.0 then
		local shipPos = vec( sin(iTime*0.10)*6.0, -1.25, -32.0 + sin(iTime*0.05)*2.0 )
		local ps = p - shipPos

		local ang = 0.2*sin(iTime*0.07)
		local rx, rz = rot2(ps.x, ps.z, ang)
		ps = vec(rx, ps.y, rz)

		local hull = sdBox(ps - vec(0, 0.1, 0), vec(2.0, 0.35, 0.7))
		hull = max(hull, -(ps.y + 0.15))

		local mast = sdCylY(ps - vec(0.1, 0.9, 0), 0.06, 1.2)

		d_ship = min(hull, mast)
	end

	local d_res = d_floor
	local mat_id = 1.0

	if d_water < d_res then
		d_res = d_water
		mat_id = 4.0
	end
	if d_stacks < d_res then
		d_res = d_stacks
		mat_id = 2.0
	end
	if d_cave < d_res then
		d_res = d_cave
		mat_id = 3.0
	end
	if d_ship < d_res then
		d_res = d_ship
		mat_id = 5.0
	end

	return vec(d_res, mat_id, 0)
end

local function raymarch(ro: vec, rd: vec, iTime: f64): vector
	local t = 0.0
	local m = -1.0
	local d = 0.0

	for _ = 1, 64 do
		local p = ro + rd * t
		local res = map(p, iTime)
		d = res.x
		m = res.y

		if d < 0.005 * t then
			return vec(t, m, d)
		end
		if t > 80.0 then break end
		t += d
	end
	return vec(-1.0, -1.0, 0.0)
end

local function calcNormal(p: vec, d: number, iTime: f64): vec
	local e = vec(0.01, 0, 0)
	local n = vec(
		map(p + vec(e.x, 0, 0), iTime).x - d,
		map(p + vec(0, e.x, 0), iTime).x - d,
		map(p + vec(0, 0, e.x), iTime).x - d
	)
	return normalize(n)
end

local function getSkyColor(rd: vec): vec
	local skyGradient = mix(vec(0.5, 0.7, 0.9), vec(0.1, 0.3, 0.6), max(0, rd.y))
	local sun = pow(max(0, dot(rd, SKY_SUN_DIR)), 100.0) * vec(1.0, 0.9, 0.7)

	local denom = max(0.35, -rd.z)
	local su = rd.x / denom
	local sv = rd.y / denom
	local c = fbm(vec(su*1.2, sv*1.2, 0) + vec(0.05, 0.02, 0) * (0)) -- LOL
	local clouds = smoothstep(0.55, 0.85, c) * smoothstep(0.02, 0.35, rd.y)
	local cloudCol = vec(1.0, 1.0, 1.0) * 0.35

	return skyGradient + sun + cloudCol * clouds
end

local function main(_: vec, fragCoord: vec, iTime: f64): vec
	local uv = -vec_1 + ((vec_1 * 2) * fragCoord) / iRes
	uv = vec(uv.x * (iRes.x/iRes.y), uv.y, 0) * .666

	local rd = normalize(fwd + right * uv.x + up * uv.y)

	local col = getSkyColor(rd)

	do
		local b = birdsMask(rd, iTime)
		col = mix(col, vec(0.02, 0.02, 0.02), b)
	end

	local res = raymarch(ro, rd, iTime)
	local t = res.x
	local mat_id = res.y
	local d_curr = res.z

	if t > 0 then
		local p = ro + rd * t
		local n = calcNormal(p, d_curr, iTime)

		local diff = max(0, dot(n, SUN_DIR))
		local amb = 0.5 + 0.5 * n.y
		local shadow = 1.0

		if mat_id == 1 or mat_id == 2 or mat_id == 5 then
			local st = 0.2
			local h = 1.0
			for _=1, 16 do
				h = map(p + SUN_DIR * st, iTime).x
				shadow = min(shadow, 16.0 * h / st)
				if shadow < 0.01 then break end
				st += clamp(h, 0.1, 1.0)
			end
		end
		shadow = clamp(shadow, 0.0, 1.0)

		local albedo = vec_0

		if mat_id == 1 then
			albedo = vec(0.7, 0.6, 0.4)

			local sandScale = 10.0
			local sandN = fbm(p * sandScale)
			local grain = noise(p * 80.0)

			albedo = albedo * (0.8 + 0.3 * sandN)
			albedo = albedo * (0.95 + 0.1 * grain)

			local bump = (sandN - 0.5) * 0.3
			n = normalize(n + vec(bump, 0, bump))

			local waterLevel = -1.8 + 0.2 * sin(iTime + p.z * 0.8)
			local wetness = smoothstep(0.5, -0.2, p.y - waterLevel)

			albedo = mix(albedo, albedo * 0.5, wetness)

			local ref = reflect_vec(rd, n)
			local skyRef = getSkyColor(ref)
			local fre = clamp(1.0 - dot(-rd, n), 0.0, 1.0)
			fre *= fre
			fre *= fre

			col = mix(albedo * (diff * shadow + amb * 0.2), skyRef, fre * 0.8 * wetness)

			local foam = smoothstep(0.1, 0.0, abs(p.y - waterLevel))
			if foam > 0.01 then
				col += vec(0.2, 0.2, 0.2) * foam * noise(p * 10.0)
			end

		elseif mat_id == 2 then
			albedo = vec(0.4, 0.35, 0.3)
			if p.y > 0.0 and n.y > 0.3 then
				albedo = mix(albedo, vec(0.1, 0.4, 0.1), n.y * 0.8)
			end
			col = albedo * (diff * shadow + amb * 0.3)

		elseif mat_id == 3 then
			albedo = vec(0.05, 0.05, 0.05)
			local detail = fbm(p * 2.0)
			albedo = albedo + vec(0.02, 0.02, 0.02) * detail
			col = albedo * (amb * 0.5)

			local rim = clamp(1.0 + dot(rd, n), 0.0, 1.0)
			rim = rim * rim * rim
			col += vec(0.5, 0.4, 0.3) * rim * 0.5 * shadow

		elseif mat_id == 4 then
			albedo = vec(0.05, 0.15, 0.2)

			local waveSpeed = iTime * 0.5
			local wave = fbm(vec(p.x, 0, p.z) * 2.0 + vec(waveSpeed, 0, waveSpeed))
			local waveN = normalize(n + vec(wave * 0.1, 0, wave * 0.1))

			local ref = reflect_vec(rd, waveN)
			local skyRef = getSkyColor(ref)

			local fre = clamp(1.0 - dot(-rd, waveN), 0.0, 1.0)
			fre = pow(fre, 5.0)

			local spec = pow(max(0, dot(ref, SUN_DIR)), 50.0)

			col = mix(albedo, skyRef, 0.2 + 0.8 * fre) + vec_1 * spec

			if t < 40.0 then
				local seaFoam = smoothstep(0.6, 0.8, fbm(p*3.0 + vec(iTime*0.2, 0, iTime*0.2)))
				col += vec(0.3, 0.3, 0.3) * seaFoam
			end

		elseif mat_id == 5 then
			albedo = vec(0.06, 0.055, 0.05)
			local ref = reflect_vec(-SUN_DIR, n)
			local spec = pow(max(0, dot(ref, -rd)), 64.0)
			col = albedo * (diff * shadow + amb * 0.15) + vec_1 * spec * 0.15
		end

		-- fog
		local fogAmount = 1 - exp(-t * 0.02)
		local fogColor = vec(0.5, 0.7, 0.9)
		col = mix(col, fogColor, fogAmount)
	end
	
	col *= 2
	col = vec(tanh(col.x), tanh(col.y), tanh(col.z))
	return vector.clamp(col, vec_0, vec_1)
end

local function preprocess(iTime:f64): f64
	ro = vec(0.0, 1.0, 6.0)
	lookAt = vec(sin(iTime*0.62222), cos(iTime*0.7428765235), -20.0)
	fwd = normalize(lookAt - ro)
	right = normalize(cross(fwd, vec_up))
	up = normalize(cross(right, fwd))
	return iTime
end
