--!nocheck
--!nolint
--/INLINE
-- Fragment Shader - Cloudy Tunnel [Source: https://www.shadertoy.com/view/llSfRK]

--// origo and lookat points
local o:vec
local t:vec
local oSquareTotal:f64
local sampleCount:f64 = 2
local W:f64 = 4.0
local T:f64 = 0.05
local texture = Sampler_Nearest_IL

-- Values
local iChannel0: Textures.Texture = Textures.Load.Base(
	{ { Name = "From_BT709" }, { Name = "To_sRGB" }, { Name = "VFlip" }, { Name = "GaussianBlur" } },
	"clouds_1024"
)

-- Functions
local function smoothstep(e0:f64,e1:f64,x:f64):f64
	--// Scale, and clamp x to 0..1 range
	x = clamp((x-e0)/(e1-e0),0,1)
	return x*x*(3-2*x)
end

local function filmic_reinhard_curve(x:f64):f64
	local q:f64 = (T+1.0)*x*x
	return q / (q + x + T);
end

local function filmic_reinhard(x:vec):vec
	local w:f64 = filmic_reinhard_curve(W)
	local q:vec = (T+1.0)*x*x
	return (q / (q + x + (vec_1*T)))/w
end

local function mul_vecmat3(v:vec,r0:vec,r1:vec,r2:vec):vec
	return
		vec(r0.x,r1.x,r2.x)*v.x +
		vec(r0.y,r1.y,r2.y)*v.y +
		vec(r0.z,r1.z,r2.z)*v.z
end

local function orient(v:vec, d:vec): (vec, vec, vec)
	v = normalize(v)
	local i:vec = normalize(cross(v, normalize(d)))
	return i, cross(i,v), v
end

local function main( fragColor: vec, fragCoord: vec, iTime: f64 ): vec
	local uv:vec = -vec_1+((vec_1*2)*fragCoord) / iRes
	uv = vec(uv.x * (iRes.x/iRes.y), uv.y)
	
	--// oriented direction vectors (up-vector)
	local d:vec = normalize( mul_vecmat3( vec( uv.x, uv.y, 2.0 ), orient( t, normalize( vec( 0, 1, 2 ) ) ) ) ) 
	--
	local tv:vec = vec_1
	local ac:vec = vec_0
	local i:vec = vec_0
	local aid:f64 = 0
	--
	local a:f64 = d.x*d.x + d.y*d.y
	local b:f64 = 2 * ( o.x*d.x + o.y*d.y )
	--// Sample iteration
	for l = 1, sampleCount do
		local off:f64 = 3 * ( 1 * ( length(tv) ^ 2 ) ) 
		aid += off
		local r:f64 = 32 - off
		local c:f64 = oSquareTotal - r*r
		local delta:f64 = sqrt( b*b - 4*a*c )
		local t:f64 = min( (-b-delta)/(2*a), (-b+delta)/(2*a) )
		t = if math.isnan(t) then 0 else t
		i = o + t*d;
		local i_atan:f64 = math.atan2(i.y, i.x)
		local co:vec = vec((i.z)*.2,i_atan*32/3.1416)
		tv = texture(iChannel0, co*.007)
		local c2:vec = vec((i.z)*.2,abs(i_atan*32/3.1416))
		local te:vec = texture(iChannel0, c2*.007)
		tv = vector.lerp(tv, te, smoothstep(0, .7, i_atan) + smoothstep(3.1416-.7,3.1416,-i_atan))
		ac += vec(tv.x^2.2,tv.y^2.2,tv.z^2.2)/sampleCount
	end
	ac /= ( smoothstep(0, 1, 1/( (length(o-i)*.02)^2 )) )^.5
	ac /= (aid^.5)*.1
	--// vignette
	local rf:f64 = sqrt(dot(uv, uv)) * .3
	local rf2_1:f64 = rf * rf + 1
	ac *= 1 / (rf2_1 * rf2_1)
	--// tonemap
	ac = filmic_reinhard(ac)
	ac = vec(smoothstep(-.12,1,ac.x),smoothstep(-.12,1,ac.y),smoothstep(-.12,1,ac.z))
	return ac
end

local function preprocess( iTime:f64 ): f64
	o = vec( sin(iTime*0.478)*8.0, cos(iTime*0.513)*8.0, iTime*100.0 )
	oSquareTotal = o.x*o.x + o.y*o.y
	t = vec( sin(iTime*0.509)*200.0, cos(iTime*0.437)*200.0, -1000.0 )
	return iTime
end
