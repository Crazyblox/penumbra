--!strict
--!native

--Textures: Parses and provides texture data via appropriate types.

-- Requires
local Settings =	require( `./Settings` )
local PNG =			require( `./PNG` )
local Base64 =		require( `./Base64` )

-- [[ TYPES ]] --
local Types = require( `@self/Types` )
export type Texture = Types.Texture
export type Cubemap = Types.Cubemap
export type LoadTexture = Types.LoadTexture

--Locals
local vec_0: vector = vector.zero
local HalfPi: number = math.pi * 0.5
local Tau: number = math.pi * 2
local vec = vector.create

-- Metatables covering floating point precision errors when inferring correct texture/index.
local Metatables = {}
Metatables.vector = { __index = function(): vector return vec_0 end }
table.freeze( Metatables.vector )

-- TEXTURE SAMPLER --
-- These types are used primarily within './lib/Pipeline/Shaders', and act as shorthand when copy-pasting texture sampler functions...
-- ...in order to retain blazing-fast performance by preventing heavy code from jumping between scope to scope...
-- Luau does have an ongoing 'export' RFC that aims to address this, but until then...
type vec=vector; type f64=number  
local function Sampler_Nearest_Repeat(t:Texture,UV:vec):vec UV=vec(UV.x%1,UV.y%1)//t.FD;return t[UV.x+UV.y*t.Width]end;local function Sampler_Nearest_Clamp(t:Texture,UV:vec):vec UV=vector.clamp(UV//t.FD,vec_0,vec(t.Width0,t.Height0)); return t[UV.x+UV.y*t.Width];end;local function Sampler_Linear_Repeat(t:Texture,UV:vec):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y);end;local function Sampler_Linear_Clamp( t:Texture,UV:vec ):vec UV*=vec(t.Width,t.Height);UV-=vec(.5,.5);local UV_0:vec =vector.floor(UV);local UV_1:vec =vector.ceil(UV);UV_0=vector.clamp(UV_0,vec_0,vec(t.Width0,t.Height0));UV_1=vector.clamp(UV_1,vec_0,vec(t.Width0,t.Height0));local A:vec =UV-UV_0;local X0:f64 =UV_0.x%t.Width;local X1:f64 =UV_1.x%t.Width;local Y0:f64 =(UV_0.y%t.Height)*t.Width;local Y1:f64 =(UV_1.y%t.Height)*t.Width;return vector.lerp(vector.lerp(t[X0+Y0],t[X1+Y0],A.x),vector.lerp(t[X0+Y1],t[X1+Y1],A.x),A.y)end
local vW: number, vP: number = Settings.Display_Res.x, Settings.Display_Res.x * Settings.Display_Res.y
if Settings.Actor_RenderNum and Settings.Actor_RenderNum > -1 then
	-- Branched into when VM is running via 'Render' init; allows non-render VMs to make use of './Libraries/Textures'
	vW = Settings.Actor_Res.x
	vP = ( Settings.Actor_Res.x * Settings.Actor_Res.y ) * ( Settings.Actor_RenderNum - 1 )
end

-- FALLBACK: TEXTURE --
local FallbackTexture: Texture = (function(): Texture
	local Width: number = 128
	local Height: number = 128
	local x: number, y: number = 0, 0
	local CreatedTexture: Texture = {
		Width = Width,
		Height = Height,
		Width0 = Width-1,
		Height0 = Height-1,
		FD = vector.create(1/Width,1/Height,1/Height),
		Mult = vector.one
	}
	--Generate colour for every pixel
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
	return table.freeze( CreatedTexture )
end)()

Metatables.Cubemap = { __index = FallbackTexture }
table.freeze( Metatables.Cubemap )

-- LOADED TEXTURES --
-- This module can return already-loaded textures once they are initially created and stored here.
-- This means that Load.Base() and Load.Cubemap() should be versatile and not require second-thought. 
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
		To_sRGB = function( In: vector ): vector 
			-- Gamma Reciprocal: 1 / 2.4 = 0.4166666666666667
			local R, G, B = In.x, In.y, In.z
			return vector.create(
				R > 0.0031308 and 1.055 * ( R ^ 0.4166666666666667 ) - 0.055 or R * 12.92,
				G > 0.0031308 and 1.055 * ( G ^ 0.4166666666666667 ) - 0.055 or G * 12.92,
				B > 0.0031308 and 1.055 * ( G ^ 0.4166666666666667 ) - 0.055 or B * 12.92
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
		VFlip = function( In: Texture, Config: any ): {vector}
			local HalfY: number = In.Height0 // 2
			for Y = 0, HalfY do
				local i_Y0: number = Y * In.Width
				local i_Y1: number = ( In.Height0 - Y ) * In.Width
				for X = 0, In.Width0 do
					local S0 = In[ i_Y0 + X ]
					local S1 = In[ i_Y1 + X ]
					-- Swap pixels with above & below row.
					In[ i_Y0 + X ], In[ i_Y1 + X ] = S1, S0
				end
			end
			return In
		end,
	}
}
-- Main loader function
function Textures.Load.Base( cfg: LoadTexture?, ...: string ): ...Texture
	local cfg = cfg or {} :: LoadTexture
	local LoadedTextures: { Texture } = {}
	for _, TexturePath: string in { ... } do
		--Add texture to list if it's already loaded
		if Textures.Base[ TexturePath ] then
			table.insert( LoadedTextures, Textures.Base[ TexturePath ] )
			continue
		end
		-- [Errors if texture isn't present]
		local TextureData = require( `@self/Assets/{ TexturePath }` ) :: any
		-- [Redundant?] Replace texture with fallback if data doesn't exist
		if not TextureData then
			print(`Texture '{ TexturePath }' doesn't exist: Providing fallback`)
			table.insert( LoadedTextures, FallbackTexture )
			continue
		end
		-- Are we a buffer or a table?
		local ImageFile
		if type(TextureData) == "buffer" then
			ImageFile = PNG.decode( Base64.Decode( TextureData :: buffer ) :: buffer )
		elseif type(TextureData) == "table" then
			ImageFile = TextureData :: PNG.PNG
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
			CreatedTexture[RGB_i] = vec(
				buffer.readu8( TextureBuffer, Buffer_i ),
				buffer.readu8( TextureBuffer, Buffer_i+1 ),
				buffer.readu8( TextureBuffer, Buffer_i+2 )
			) / 0xFF
			Buffer_i += 4
		end
		-- Iterate through given list of process functions and relevant configs
		for i: number, Mode: {[string]: any} in cfg do
			-- Fragment modes
			if ProcessFunctions.Fragment[ Mode.Name ] then
				for RGB_i = 0, ( Width_O * Height_O ) - 1 do
					CreatedTexture[RGB_i] = ProcessFunctions.Fragment[ Mode.Name ](
						CreatedTexture[RGB_i],
						Mode.Config
					)
				end
			-- Full modes
			elseif ProcessFunctions.Full[ Mode.Name ]then
				ProcessFunctions.Full[ Mode.Name ](
					CreatedTexture,
					Mode.Config
				)	
			end
		end
		
		-- MIPMAP GENERATION
		--[[
		-- Yet to be implemented; Experimental feature where mipmaps of a texture were generated.
		-- Work on this was shelved after understanding that mipmap level inference was handled in hardware on the GPU;
		-- The work required to carry this out would take a long time as the knowledge is currenlty beyond me...
		local SelectedTexture = CreatedTexture
		local Mipmaps = { [0] = CreatedTexture }
		local MipLevel: number = 0
		local MaxMip: number = 4
		while MipLevel < Settings.Textures_Downscale-1 and MipLevel < MaxMip do
			-- Break if mipmapping isn't possible.
			if not ( ( SelectedTexture.Width / 2 == SelectedTexture.Width // 2 ) or ( SelectedTexture.Height / 2 == SelectedTexture.Height // 2 ) ) then
				break
			end
			MipLevel += 1
			local MipWidth: number = SelectedTexture.Width / 2
			local MipHeight: number = SelectedTexture.Height / 2
			local MipSize: number = 1
			local Mults={ _ft = vec3(1,Width_O,0), _rt = vec3(0,MipWidth,1), _up = vec3(1,0,MipWidth), _bk = vec3(1,MipWidth,0), _lf = vec3(0,MipWidth,1), _dn = vec3(1,0,MipWidth) }
			local Mult_Mip = Mults[ string.sub( TexturePath, #TexturePath - 2, #TexturePath ) ] or Mults._ft
			local MipTexture: Texture = {
				Width =			MipWidth,
				Height =		MipHeight,
				Width0 =		MipWidth-1,
				Height0 =		MipHeight-1,
				FD =			vector.create( 1 / MipWidth, 1 / MipHeight, 1 / MipSize ),
				Mult =			Mult_Mip
			}
			-- Generate downsampled texture from SelectedTexture
			local RGB_i: number = 0
			for Y = 0, MipHeight-1 do
				for X = 0, MipWidth-1 do
					MipTexture[RGB_i] = Sampler_Linear_Clamp( SelectedTexture, vector.create( (X+.5)/MipWidth, (Y+.5)/MipHeight ) )
					RGB_i += 1
				end
			end
			print(`Created Mipmap: Level {MipLevel}, X {MipWidth}, Y {MipHeight}, RGB_i {RGB_i}, RGB_i[0] {MipTexture[0]}, RGB_i[#] {MipTexture[#MipTexture :: any]}, # {#MipTexture :: any}`)
			Mipmaps[MipLevel] = MipTexture
			SelectedTexture = MipTexture
			print(`Created MipMap Level { MipLevel }`)
		end
		CreatedTexture = SelectedTexture
		]]
		-- Texture loaded & processed - Frozen for fast reads - Mutability not expected.
		table.freeze( CreatedTexture )
		-- Stores texture in global dictionary and own array for returning
		Textures.Base[ TexturePath ] = CreatedTexture
		table.insert( LoadedTextures, CreatedTexture )
	end
	-- Returns each texture as requested.
	return table.unpack( LoadedTextures )
end

-- Generates Cubemap
function Textures.Load.Cubemap( cfg: LoadTexture, Name: string ): Cubemap
	-- Early exit if cubemap with a given name is already loaded/available for returning.
	if Textures.Cubemaps[ Name ] then
		return Textures.Cubemaps[ Name ]
	end
	local Front = Textures.Load.Base(cfg,`Cubemaps/{Name}/{Name}_ft`)
	--Create Immutable & Error-Free
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