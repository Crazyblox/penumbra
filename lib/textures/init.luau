--!strict
--!native

--[[
	Penumbra: textures.luau
	
	This module handles loading and processing a texture via any
	of the given load parameters by the calling module.
	
	Assets are stored via textures/assets, additional ones can be
	added by providing PNG files as base64-encoded strings so that
	no filesystem dependency is required.
]]

-- Requires
local Settings = 	require( `../` )()
local PNG =			require( `./png` )
local Base64 =		require( `./base64` )

-- [[ TYPES ]] --
local Types = require( `@self/types` )
export type Texture = Types.Texture
export type Cubemap = Types.Cubemap
export type LoadTexture = Types.LoadTexture

-- RGBAu8/vec3 buffer read/write functions
local u32B: number = 4
local buffer_vec3 = function(b: buffer ,i: number ): vector
	local n:number = buffer.readu32(b,i)
	return vector.create(bit32.band(n,0x000000FF),bit32.rshift(bit32.band(n,0x0000FF00),8),bit32.rshift(bit32.band(n,0x00FF0000),16))*.00392156862745098
end
local vec3_buffer = function(b: buffer, i: number, v: vector)
	v*=0xFF
	buffer.writeu32(b,i,v.x+bit32.lshift(v.y,8)+bit32.lshift(v.z,16)+0xFF000000)
end

-- Sampling function pulled from shader_builder for pre-processing textures
local function Sampler_Nearest(t: Types.Texture, UV: vector ): vector
	UV *= vector.create( t.Width, t.Height )		-- Expand resolution
	UV //= 1										-- Set top-left UV integer
	local x:number	= UV.x % t.Width				-- Wrap U to texture width
	local y:number	= ( UV.y % t.Height ) * t.Width	-- Wrap V to texture height
	local i:number	= (x + y) * u32B				-- Set index value
	return buffer_vec3(t.Buffer, i)					-- Return read value
end

-- Locals
local vec_0: vector = vector.zero
local HalfPi: number = math.pi * 0.5
local Tau: number = math.pi * 2
local vec = vector.create

-- FALLBACK: TEXTURE --
local FallbackTexture: Texture = (function(): Texture
	local Width: number = 128
	local Height: number = 128
	local x: number, y: number = 0, 0
	local CreatedTexture = {
		Buffer = buffer.create(1),
		Dimensions = vector.create(Width, Height),
		Width = Width,
		Height = Height,
		Width0 = Width-1,
		Height0 = Height-1,
		FD = vector.create(1/Width,1/Height,1/Height),
		Mult = vector.one
	}
	-- Generate colour for every pixel
	for write: number = 0, Width * Height do 
		local xRate: number = y / Width
		local yRate: number = x / Height
		local zRate: number = 1 - math.min( ( 1 - xRate ) + ( 1 - yRate ), 1 )
		xRate -= zRate
		yRate -= zRate
		CreatedTexture[ write ] = vector.create( xRate, zRate, yRate )
		x += 1
		y = x == Width and y + 1 or y
		x = x == Width and 0 or x
	end
	return table.freeze( CreatedTexture ) :: Texture
end)()

-- LOADED TEXTURES --
-- This module can return already-loaded textures once they are initially created and stored here.
-- Be mindful of this is you choose to load the same texture in the same VM multiple times, as pre-processing is fixed.
local Textures = table.freeze( {
	Base = {} :: { [ string ]: Texture },		--All Textures
	Cubemaps = {} :: { [ string ]: Cubemap },	--Cubemaps [Contains Textures]
	Load = {}									-- Loading functions are stored here.
} )


local vX: vector = vector.create( 1, 0, 0 )
local vY: vector = vector.create( 0, 1, 0 )
local vZ: vector = vector.create( 0, 0, 1 )

-- Specific functions which can be run on the texture.
local ProcessFunctions = {
	-- Per-pixel processing modes
	Fragment = {
		From_BT709 = function( In: vector ): vector
			local R, G, B = In.x, In.y, In.z
			return vector.create(
				if R >= 0.081 then ( ( R + .099 ) / 1.099 ) ^ 2.22222222 else R / 4.5,
				if G >= 0.081 then ( ( G + .099 ) / 1.099 ) ^ 2.22222222 else G / 4.5,
				if B >= 0.081 then ( ( B + .099 ) / 1.099 ) ^ 2.22222222 else B / 4.5
			)
		end,
		To_sRGB = function( In: vector ): vector 
			-- Gamma Reciprocal: 1 / 2.4 = 0.4166666666666667
			local R, G, B = In.x, In.y, In.z
			return vector.create(
				R > 0.0031308 and 1.055 * ( R ^ 0.4166666666666667 ) - 0.055 or R * 12.92,
				G > 0.0031308 and 1.055 * ( G ^ 0.4166666666666667 ) - 0.055 or G * 12.92,
				B > 0.0031308 and 1.055 * ( B ^ 0.4166666666666667 ) - 0.055 or B * 12.92
			)
		end,
		To_lRGB = function( In: vector ): vector
			local R, G, B = In.x, In.y, In.z
			return vector.create(
				if R<0.04045 then R/12.92 else ((R+0.055)/1.055)^2.4,
				if G<0.04045 then G/12.92 else ((G+0.055)/1.055)^2.4,
				if B<0.04045 then B/12.92 else ((B+0.055)/1.055)^2.4
			)
		end,
		Squared = function( In: vector ): vector
			return In*In
		end,
		Mult = function( In: vector, Config: {vector} ): vector
			return In * Config[1]
		end,
	},
	
	-- Processing modes which require access to the full texture
	Full = {
		-- Vertically flip the texture in pre-processing to save compute
		-- Use this when loading a texture to match OpenGL's behaviour.
		VFlip = function( In: Texture, Config: any ): Texture
			local HalfY: number = In.Height0 // 2
			for Y = 0, HalfY do
				local i_Y0: number = Y * In.Width
				local i_Y1: number = ( In.Height0 - Y ) * In.Width
				for X = 0, In.Width0 do
					local S0: vector = buffer_vec3( In.Buffer, (i_Y0 + X)*4 )
					local S1: vector = buffer_vec3( In.Buffer, (i_Y1 + X)*4 )
					-- Swap pixels with above & below row.
					vec3_buffer( In.Buffer, (i_Y0 + X)*4, S0 )
					vec3_buffer( In.Buffer, (i_Y1 + X)*4, S1 )
				end
			end
			return In
		end,
		
		BoxBlur = function( In: Texture, Config: any ): Texture
			local WriteBuffer = buffer.create(buffer.len(In.Buffer))
			local c:number = 0
			for y = 0, In.Height0 do
				for x = 0, In.Width0 do
					local accumulation: vector = vector.zero
					for yB = -1, 1 do
						for xB = -1, 1 do
							accumulation += Sampler_Nearest( In, vector.create( (x + xB) / In.Width, (y + yB) / In.Height ) )
						end
					end
					vec3_buffer( WriteBuffer, c, vector.clamp( accumulation * 0.1111111111111111, vector.zero, vector.one ) )
					c += 4
				end
			end
			buffer.copy( In.Buffer, 0, WriteBuffer )
			WriteBuffer = nil
			return In
		end,
		
		GaussianBlur = function( In: Texture, Config: any ): Texture
			local WriteBuffer = buffer.create(buffer.len(In.Buffer))
			local c:number = 0
			for y = 0, In.Height0 do
				for x = 0, In.Width0 do
					local accumulation: vector = vector.zero
					
					-- Corners: X0Y0, X2Y0, X0Y2, X2Y2
					accumulation += Sampler_Nearest( In, vector.create(x-1,y-1) / In.Dimensions ) * .0625
					accumulation += Sampler_Nearest( In, vector.create(x+1,y-1) / In.Dimensions ) * .0625
					accumulation += Sampler_Nearest( In, vector.create(x-1,y+1) / In.Dimensions ) * .0625
					accumulation += Sampler_Nearest( In, vector.create(x+1,y+1) / In.Dimensions ) * .0625
					
					-- Adjacents: X1Y0, X0Y1, X2Y1, X1Y2
					accumulation += Sampler_Nearest( In, vector.create(x,y-1) / In.Dimensions ) * .1250
					accumulation += Sampler_Nearest( In, vector.create(x-1,y) / In.Dimensions ) * .1250
					accumulation += Sampler_Nearest( In, vector.create(x+1,y) / In.Dimensions ) * .1250
					accumulation += Sampler_Nearest( In, vector.create(x,y+1) / In.Dimensions ) * .1250
					
					-- Center: X1Y1
					accumulation += Sampler_Nearest( In, vector.create(x,y) / In.Dimensions ) * .25
					vec3_buffer( WriteBuffer, c, vector.clamp( accumulation, vector.zero, vector.one ) )
					c += 4
				end
			end
			buffer.copy( In.Buffer, 0, WriteBuffer )
			WriteBuffer = nil
			return In
		end,
		
		-- Removes alpha channel from texture
		RemoveAlpha = function( In: Texture, Config: any ): Texture
			for y = 0, In.Height0 do
				for x = 0, In.Width0 do
					local idx: number = ( ( x % In.Width ) + y * In.Width ) * 4
					local pixel: vector = buffer_vec3( In.Buffer, idx )
					vec3_buffer( In.Buffer, idx, pixel )
				end
			end
			return In
		end,
	},
}

-- Main loader function
function Textures.Load.Base( cfg: LoadTexture?, ...: string ): ...Texture
	local cfg = cfg or {} :: LoadTexture
	local LoadedTextures: { Texture } = {}
	for _, TexturePath: string in { ... } do
		
		-- Add texture to list if it's already loaded
		if Textures.Base[ TexturePath ] then
			table.insert( LoadedTextures, Textures.Base[ TexturePath ] )
			continue
		end
		
		-- [Errors if texture isn't present]
		local TextureData = require( `@self/assets/{ TexturePath }` ) :: any
		
		-- [Redundant?] Replace texture with fallback if data doesn't exist
		if not TextureData then
			print(`Texture '{ TexturePath }' doesn't exist: Providing fallback`)
			table.insert( LoadedTextures, FallbackTexture )
			continue
		end
		
		-- Are we a buffer or a table?
		local ImageFile: PNG.PNG
		if type(TextureData) == "buffer" then
			ImageFile = PNG.decode( Base64.Decode( TextureData :: buffer ) :: buffer ) 
		elseif type(TextureData) == "table" then
			ImageFile = TextureData
		else
			error("Lol")
		end
		
		local Width_O: number = ImageFile.Width
		local Width_Mip: number = Width_O
		local Height_O: number = ImageFile.Height
		local Height_Mip: number = Height_O

		-- Unloaded data exists, parse and add to list.
		local TxSize_I: number = math.sqrt( Width_O * Width_O )
		local TxSize_O: number = TxSize_I
		local Mults={ _ft = vec(1,Width_O,0), _rt = vec(0,Width_O,1), _up = vec(1,0,Width_O), _bk = vec(1,Width_O,0), _lf = vec(0,Width_O,1), _dn = vec(1,0,Width_O) }
		local Mult_O = Mults[ string.sub( TexturePath, #TexturePath - 2, #TexturePath ) ] or Mults._ft
		
		-- Create original texture
		local CreatedTexture: Texture = {
			Buffer = buffer.create(Width_O * Height_O * 4),
			Dimensions = vector.create(Width_O, Height_O),
			Width = Width_O,
			Height = Height_O,
			Width0 = Width_O-1,
			Height0 = Height_O-1,
			FD = vec(
				1 / Width_O,
				1 / Height_O,
				1 / TxSize_O
			),
			Mult = Mult_O or 1
		}
		
		-- Initial processing of texture
		local TextureBuffer = ImageFile.Pixels
		local Buffer_i: number = 0
		local RGB_i: number = 0
		for RGB_i = 0, ( Width_O * Height_O ) - 1 do
			buffer.writeu8( CreatedTexture.Buffer, Buffer_i, buffer.readu8( TextureBuffer, Buffer_i ) )
			Buffer_i += 1
			buffer.writeu8( CreatedTexture.Buffer, Buffer_i, buffer.readu8( TextureBuffer, Buffer_i ) )
			Buffer_i += 1
			buffer.writeu8( CreatedTexture.Buffer, Buffer_i, buffer.readu8( TextureBuffer, Buffer_i ) )
			Buffer_i += 2
		end
		
		-- Iterate through given list of process functions and relevant configs
		for i: number, Mode: {[string]: any} in cfg do
			if ProcessFunctions.Fragment[ Mode.Name ] then
				-- Fragment modes
				for RGB_i = 0, ( Width_O * Height_O ) - 1 do
					vec3_buffer(
						CreatedTexture.Buffer,
						RGB_i*4,
						ProcessFunctions.Fragment[ Mode.Name ](
							buffer_vec3( CreatedTexture.Buffer, RGB_i*4 ),
							Mode.Config
						)
					)
				end
			elseif ProcessFunctions.Full[ Mode.Name ] then
				-- Full modes
				ProcessFunctions.Full[ Mode.Name ](
					CreatedTexture,
					Mode.Config
				)
			end
		end
		
		-- Texture loaded & processed - Frozen for fast reads - Mutability not expected.
		table.freeze( CreatedTexture ) 
		
		-- Stores texture in global dictionary and own array for returning
		Textures.Base[ TexturePath ] = CreatedTexture :: Texture
		table.insert( LoadedTextures, CreatedTexture )
	end
	
	-- Returns each texture as requested.
	return table.unpack( LoadedTextures )
end

-- Make a texture with a given input buffer and NOT store it in the textures module
function Textures.Load.FromBuffer( name: string, input: buffer, dimensions: vector ): Texture
	local TxSize_I: number = math.sqrt( dimensions.x * dimensions.y )
	local TxSize_O: number = TxSize_I
	-- Create original texture
	local CreatedTexture: Texture = {
		Buffer = input,
		Dimensions = vector.create(dimensions.x,dimensions.y,0),
		Width = dimensions.x,
		Height = dimensions.y,
		Width0 = dimensions.x-1,
		Height0 = dimensions.y-1,
		FD = vec(
			1 / dimensions.x,
			1 / dimensions.y,
			1 / TxSize_O
		),
		Mult = 1 -- Not relevant for a 2D image
	}
	table.freeze( CreatedTexture ) 
	return CreatedTexture
end

-- Generates Cubemap
function Textures.Load.Cubemap( cfg: LoadTexture, Name: string ): Cubemap
	-- Early exit if cubemap with a given name is already loaded/available for returning.
	if Textures.Cubemaps[ Name ] then
		return Textures.Cubemaps[ Name ]
	end
	local Front = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_ft`)
	
	-- Create Immutable & Error-Free
	local CreatedCubemap: Cubemap = setmetatable(
		{
			[ vec( 0, 0,-1 ) ] = Front,													--Front
			[ vec( 1, 0, 0 ) ] = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_rt`),	--Right
			[ vec( 0, 1, 0 ) ] = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_up`),	--Up
			[ vec( 0, 0, 1 ) ] = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_bk`),	--Back
			[ vec(-1, 0, 0 ) ] = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_lf`),	--Left
			[ vec( 0,-1, 0 ) ] = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_dn`)	--Down
		},
		{ __index = Front }
	)
	table.freeze( CreatedCubemap )
	Textures.Cubemaps[ Name ] = CreatedCubemap
	return CreatedCubemap
end

return Textures
