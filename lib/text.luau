--!strict
--!native

--[[
	Penumbra: text.luau
	Responsible for drawing text to the screen
	Only works as expected when required by 'main.luau'
	
		NOTE:
	This text renderer is ASCII only.
	Attempting to print characters outside of ASCII spec will cause undefined behaviour.
	If you want to provide your own font texture, ensure that all characters are aligned
	in a 256x1 monospace row; the renderer will use the image's X and Y dimensions to take care of the rest.
]]

local Settings = require(`../`)()
local Textures = require( `./textures` )
local VM = require( `../../plugin/process` )
assert( VM.ThisProcess == VM.MainProcess, `'text.luau' can only be required by the main process.`)

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

local Font_Texture: Textures.Texture = Textures.Load.Base( {{Name="RemoveAlpha"}}, "font_codepage437" )
local Font_CharSize: vector = vector.create( Font_Texture.Width / 0x100, Font_Texture.Height )
local Font_CharSize_X: number = Font_Texture.Width / 0x100
local Font_CharSize_Y: number = Font_Texture.Height
local Display_Res: vector = Settings.Display_Res
local Display_Res0: vector = Settings.Display_Res - vector.create( 1, 1 )

local function DrawChar( self: buffer, Code: number, Output_X: number, Output_Y: number )
	-- Infer font X/Y coords from 'Code'
	-- Get bitmap X/Y coords and establish bitmap start index.
	local RGB_Y_i_Start: number = ( Code // 0x100 ) * ( Font_Texture.Width * Font_CharSize_Y )
	local RGB_X_i_Start: number = Code * Font_CharSize_X
	-- The index offset for reading from the font framebuffer
	local RGB_i_Start: number = RGB_X_i_Start + RGB_Y_i_Start
	local Out: buffer = self
	-- Local for speed
	local Font_Buffer: buffer = Font_Texture.Buffer
	-- Iterate through character Y rows
	for i_Y: number = 0, Font_CharSize_Y - 1 do
		-- 'Buffer_Y_Offset' helps provide appropriate offset for drawing character.
		local Buffer_Y_Offset: number = ( Output_Y + i_Y ) * Settings.Display_Res.x
		-- 'RGB_Y' is used as the Y offset for reading from the RGB texture.
		local RGB_Y_i_Offset: number = i_Y * Font_Texture.Width
		-- Copy row of the bitmap font character
		buffer.copy(
			Out,
			( Output_X + Buffer_Y_Offset ) * 4,
			Font_Buffer,
			( RGB_i_Start + RGB_Y_i_Offset ) * 4,
			Font_CharSize_X * 4
		)
	end
end

local function DrawString(
	self: buffer,
	Str: string,			-- Text to be drawn
	GridCoords: boolean?,	-- Snaps all input coordinates to font's character size
	Cursor_XY: vector?,		-- Cursor for where to start drawing text
	XY0: vector?,			-- Bounding box; Top-Left Point
	XY1: vector?			-- Bounding box; Bottom-Right Point
)
	local Cursor: vector = Cursor_XY or vector.zero
	local XY0: vector = XY0 or vector.zero
	local XY1: vector = XY1 or Display_Res0
	-- Ensures XY0 is top-left and XY1 is bottom-right
	XY0, XY1 = vector.min( XY0, XY1 ), vector.max( XY0, XY1 )
	-- Clamp
	XY0 = vector.clamp( XY0, vector.zero, Display_Res0 )
	XY1 = vector.clamp( XY1, vector.zero, Display_Res0 )
	Cursor = vector.clamp( Cursor, XY0, XY1 )
	if GridCoords then
		Cursor = ( Cursor // Font_CharSize ) + ( Cursor * Font_CharSize )
		XY0 = ( XY0 // Font_CharSize ) + ( XY0 * Font_CharSize )
		XY1 = ( XY1 // Font_CharSize ) + ( XY1 * Font_CharSize )
		Cursor = vector.create( Cursor.x, Cursor.y )
		XY0 = vector.create( XY0.x, XY0.y )
		XY1 = vector.create( XY1.x, XY1.y )
	end
	
	local Start_X: number = XY0.x
	local Start_Y: number = XY0.y
	local Bounds_X: number = XY1.x 
	local Bounds_Y: number = XY1.y
	local Cursor_X: number = Cursor.x
	local Cursor_Y: number = Cursor.y
	
	-- Bounds check
	if Cursor_X + Font_CharSize_X > Bounds_X then
		Cursor_X = Start_X
		Cursor_Y += Font_CharSize_Y
	end
	if Cursor_Y + Font_CharSize_Y > Bounds_Y then return end
	
	-- Establish 'i' and string length
	local C: number = 1
	local Len: number = string.len( Str )
	
	-- Rendering loop; continues until string is complete or cursor escapes bounds
	while C <= Len do
		-- Find WordEnd_i
		local WordEnd_i: number? = string.find( Str, " ", C )
		-- Do Cursor_X/Y boundary update if C is less than WordEnd_i
		if WordEnd_i and C < WordEnd_i then
			if Cursor_X + ((1+WordEnd_i-C)*Font_CharSize_X) > Bounds_X then
				Cursor_X = Start_X
				Cursor_Y += Font_CharSize_Y
				if Cursor_Y + Font_CharSize_Y > Bounds_Y then
					return
				end
			end
		end
		-- Draw until end of word or end of string
		for _ = C, WordEnd_i or Len do
			-- Bounds check
			if Cursor_X + Font_CharSize_X > Bounds_X then
				Cursor_X = Start_X
				Cursor_Y += Font_CharSize_Y
				if Cursor_Y + Font_CharSize_Y > Bounds_Y then
					return
				end
			end
			DrawChar( self, string.byte( string.sub( Str, C, C ) ), Cursor_X, Cursor_Y )
			C += 1
			Cursor_X += Font_CharSize_X 
		end
	end
end

return DrawString
