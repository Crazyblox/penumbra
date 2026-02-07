--!nocheck
--!nolint

-- Multi-shader wrapper module
-- Calls multiple different modules based on os.clock()

-- Shaders
local ShaderList = {
	require( "./frag/cardgame" ),
	require( "./frag/cave" ),
	require( "./frag/cloudytunnel" ),
	require( "./frag/rocaille" ),
	require( "./frag/fractalpyramid" ),
	require( "./frag/fragments" ),
	require( "./frag/gyroid" ),
	require( "./frag/mandelbrot_standard" ),
	require( "./frag/neuron" ),
	require( "./frag/squircle2" ),
	require( "./frag/tracedtunnel" )
}

-- WRAPPER --
local ShaderDuration: number = 10
return function( iTime: number, ...)
	ShaderList[ ( ( iTime // ShaderDuration ) % #ShaderList ) + 1 ]( iTime, ... )
end
