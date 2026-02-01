--!nocheck
--!nolint

-- Multi-shader wrapper module
-- Calls multiple different modules based on os.clock()

-- Shaders
local ShaderList = {
	require( "./cloudytunnel" ),
	require( "./creation" ),
	require( "./distortion" ),
	require( "./fractalpyramid" ),
	require( "./gyroid" ),
	require( "./hillside" ),
	require( "./introduction" ),
	require( "./mandelbrot_pattern" ),
	require( "./mandelbrot_standard" ),
	require( "./mosaic" ),
	require( "./nova" ),
	require( "./squircle" ),
	require( "./squircle2" ),
	require( "./tracedtunnel" )
}

-- WRAPPER --
local ShaderDuration: number = 6
return function( iTime: number, ...)
	ShaderList[ ( ( iTime // ShaderDuration ) % #ShaderList ) + 1 ]( iTime, ... )
end
