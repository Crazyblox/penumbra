--!nocheck
--!nolint
--/INLINE
-- Penumbra: Fragment Shader - Card Game [Source: https://www.shadertoy.com/view/XXtBRr]
local texture = Sampler_Nearest -- Sampler_Nearest_IL, Sampler_Linear
local SPIN_ROTATION:f64 = -2.0;
local SPIN_SPEED:f64 = 7.0;
local SPIN_EASE:f64 = 1.0;
local SPIN_AMOUNT:f64 = 0.25;
local OFFSET:vec = vec(0, 0);
local CONTRAST:f64 = 3.5;
local LIGHTING:f64 = 0.4;
local COLOUR_1:vec = vec(0.871, 0.267, 0.231);
local COLOUR_2:vec = vec(0.0, 0.42, 0.706);
local COLOUR_3:vec = vec(0.086, 0.137, 0.145);
local PIXEL_FILTER:f64 = 745.0;
local speed:f64 = SPIN_ROTATION*SPIN_EASE*0.2
local mul_vec2:vec = vec(1,1)

local function main( O:vec, fragCoord:vec, iTime:f64 ):vector
	local uv0:vec = fragCoord/iRes;
	uv0 = vec(uv0.x,uv0.y);
	local screenSize:vec = iRes;
	local screen_coords:vec = uv0 * iRes;

	local pixel_size:f64 = length(screenSize) / PIXEL_FILTER;

	local uv:vec = (vector.floor(screen_coords*(1/pixel_size))*pixel_size - 0.5*screenSize)/length(screenSize) - OFFSET;
	local uv_len:f64 = length(uv);

	local speed:f64 = speed;
	--speed = iTime * speed; -- For rotation
	speed += 302.2;
	local new_pixel_angle:f64 = math.atan2(uv.y, uv.x) + speed - SPIN_EASE*20.*(1.*SPIN_AMOUNT*uv_len + (1. - 1.*SPIN_AMOUNT));

	local mid:vec = (screenSize/length(screenSize))/2.;

	uv = (vec((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

	uv *= 30.;
	speed = iTime*(SPIN_SPEED);
	local uv2:vec = mul_vec2 * (uv.x+uv.y);

	for i:f64 = 0, 4 do
		uv2 += (mul_vec2 * sin(max(uv.x, uv.y))) + uv;
		uv += (mul_vec2*.5)*vec(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
		uv -= mul_vec2 * ( 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y) );
	end

	local contrast_mod:f64 = (0.25*CONTRAST + 0.5*SPIN_AMOUNT + 1.2);
	local paint_res:f64 = min(2., max(0.,length(uv)*(0.035)*contrast_mod));
	local c1p:f64 = max(0.,1. - contrast_mod*abs(1.-paint_res));
	local c2p:f64 = max(0.,1. - contrast_mod*abs(paint_res));
	local c3p:f64 = 1. - min(1., c1p + c2p);
	local light:f64 = (LIGHTING - 0.2)*max(c1p*5. - 4., 0.) + LIGHTING*max(c2p*5. - 4., 0.);
	O = (0.3/CONTRAST)*COLOUR_1 + ( vec_1 * (1. - 0.3/CONTRAST) ) * (COLOUR_1*c1p + COLOUR_2*c2p + ( COLOUR_3*c3p*c3p ) ) + (vec_1 * light);
	return vector.clamp(O, vec_0, vec_1);
end

local function preprocess( iTime:f64 ): f64
	return iTime
end
