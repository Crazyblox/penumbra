--!strict
--!native

-- Multi-shader wrapper module
-- Calls multiple different modules based on os.clock()

-- Shaders
local ShaderList = {
	require( "./Template_Min" ),
	require( "./Creation" ),
	require( "./Introduction" ),
	require( "./Mandelbrot" ),
	require( "./Mini_Hillside" ),
	require( "./Mini_Mosaic" ),
	require( "./Mini_Nova" ),
	require( "./Mini_Squircle" ),
	require( "./Mini_Squircle_2" ),
	require( "./Distortion" ),
	require( "./TracedTunnel" )
}

-- WRAPPER --
local ShaderDuration: number = 5
return function( iTime: number, ...)
	ShaderList[ ( ( iTime // ShaderDuration ) % #ShaderList ) + 1 ]( iTime, ... )
end