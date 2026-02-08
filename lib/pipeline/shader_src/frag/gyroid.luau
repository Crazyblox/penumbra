--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - tm gyroid 2 [Source: https://www.shadertoy.com/view/tXtyW8]
local reinhardBurn:vec = vector.one * .225
local FAR = 30.
local PI = 3.1415

local function vcos(v: vec) return vector.create(math.cos(v.x), math.cos(v.y), math.cos(v.z)) end
local function vsin(v: vec) return vector.create(math.sin(v.x), math.sin(v.y), math.sin(v.z)) end
local function vpow(a: vec, b: vec) return vector.create(math.pow(a.x, b.x), math.pow(a.y, b.y), math.pow(a.z, b.z)) end

local function realstep(edge: f64, x: f64) return if x < edge then 0 else 1 end

local function xy(v: vec) return vector.create(v.x, v.y, 0) end
local function xyy(v: vec) return vector.create(v.x, v.y, v.y) end
local function yyx(v: vec) return vector.create(v.y, v.y, v.x) end
local function yxy(v: vec) return vector.create(v.y, v.x, v.y) end
local function xxx(v: vec) return vector.create(v.x, v.x, v.x) end
local function zxy(v: vec) return vector.create(v.z, v.x, v.y) end

local function reflect(i: vec, n: vec): vec
	return i - 2.0 * dot(n, i) * n;
end

local function gyroid(p: vec): f64 
	return dot(vcos(p), vsin(zxy(p))) + 1.;
end

local function map(p: vec): f64
	local p2: vec = p - vec(0, 0, PI)

	local r = 1e5

	local d = gyroid(p);
	r = math.min(r, d)

	d = gyroid(p2);
	r = math.min(r, d)

	return r;
end

local function getAO(p: vec, sn: vec): f64
	local occ = 0.;
	for i=0,3 do
		local t = i*.08;
		local d = map(p + sn*t);
		occ += t-d;
	end
	return clamp(1.-occ, 0., 1.);
end

local e = vec(0.5773, -0.5773, 0) * 0.001
local xyye = xyy(e)
local yyxe = yyx(e)
local yxye = yxy(e)
local xxxe = xxx(e)

local function getNormal(p: vec): vec
	return normalize(xyye*map(p+xyye) + yyxe*map(p+yyxe) + yxye*map(p+yxye) + xxxe*map(p+xxxe));
end

local m = 0;

local function raymarch(ro: vec, rd: vec): f64
	local t = 0.;
	m = 0;
	for i=1,150 do --150
		local p: vec = ro + rd * t
		local p2: vec = p - vec(0, 0, PI)

		local d1 = gyroid(p);
		local d = math.min(1e5, d1)

		local d2 = gyroid(p2);
		d = math.min(d, d2)

		if (abs(d) < .001) then
			m = if d2 < d1 then 2 else 1
			break;
		end

		t += d;
		if (t > FAR) then break; end
	end
	return t;
end

local function trace(ro: vec, rd: vec): vec
	local C: vec = vec(0, 0, 0);
	local throughput: vec = vec(1, 1, 1);

	for bounce=0,1 do
		local d = raymarch(ro, rd);

		if (d > FAR) then break; end

		-- fog
		local fog = 1. - exp(-.008*d*d);
		C += throughput * fog * vec(0, 0, 0); throughput *= 1. - fog;

		local p: vec = ro + rd*d;
		local temp: vec = vector.abs(vcos(p*64.))
		local sn: vec = normalize(getNormal(p) + vpow(temp, vec(16, 16, 16))*.1);

		-- lighting
		local lp: vec = vec(10.,-10.,-10.+ro.z) ;
		local ld: vec = normalize(lp - p);
		local diff = max(0., .5+2.*dot(sn, ld));
		local diff2 = pow(length(vsin(sn*2.)*.5+vec(.5, .5, .5)), 2.);
		local diff3 = max(0., .5+.5*sn.z);

		local spec = max(0., dot(reflect(-ld, sn), -rd));
		local fres = 1. - max(0.,dot(-rd, sn));
		local col = vec(0, 0, 0);
		local alb = vec(0, 0, 0);

		col += vec(.4, .6, .9) * diff;
		col += vec(.5, .1, .1) * diff2;
		col += vec(.9, .1, .4) * diff3; 
		col += vec(.3,.25,.25) * pow(spec,4.)*8.;

		local freck = dot(vcos(p*23.),vec(1, 1, 1));
		if (m==1) then alb = vec(.2, .1, .9);  alb *= max(.6, realstep(2.5, freck)); end
		if (m==2) then alb = vec(.6, .3, .1);  alb *= max(.8, realstep(-2.5, freck)); end
		col *= alb;

		col *= getAO(p, sn); -- ~11%
		C += throughput * col;

		-- reflection
		rd = reflect(rd, sn);
		ro = p + sn*.01;
		throughput *=  .9 * pow(fres, 1.);
	end

	return C;
end

local function main( fragColor:vec, fragCoord:vec, iTime:f64 ):vec

	local uv: vec = (xy(fragCoord) - xy(iRes)*.5) / iRes.y;

	local ro: vec = vec(PI/2.,0, -iTime*.5);
	local rd: vec = normalize(vec(uv.x, uv.y, -.5));

	do
		local rotArg = sin(iTime*.2)
		local c = cos(rotArg);
		local s = sin(rotArg);
		local new_x = c * rd.x - s * rd.y;
		local new_y = s * rd.x + c * rd.y;

		rd = vector.create(new_x, new_y, rd.z)
	end

	local ta: vec = vec(cos(iTime*.4), sin(iTime*.4), 4.);

	do
		local dir = normalize(ta)
		local up: vec = vec(0.,1.,0.);
		local rt: vec = normalize(cross(dir,up));
		local c0, c1, c2 = rt, cross(rt,dir), dir;

		rd = rd.x * c0 + rd.y * c1 + rd.z * c2
	end

	local col: vec = trace(ro, rd);
	col *= smoothstep(0.,1., 1.2-length(uv*.9));
	col /= col + reinhardBurn;
	return col
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
