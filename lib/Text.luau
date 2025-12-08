--!strict
--!native
local Settings = require( `./Settings` )
local Textures = require( `./Textures` )
local VM = require( `../plugin/vm` )
assert( VM.Process == VM.MainProcess, `'./lib/Text.luau' can only be required by the main process.`)

--[[
	Penumbra: Text
	Responsible for drawing text to the screen
	Only works as expected when required by './init/main.luau'
	
		NOTE:
	This text renderer is ASCII only.
	Attempting to print characters outside of ASCII spec will cause undefined behaviour.
	If you want to provide your own font texture, ensure that all characters are aligned
	in a 256x1 monospace row; the renderer will use the image's X and Y dimensions to take care of the rest.
]]

local Font_Texture: Textures.Texture = Textures.Load.Base( {}, "Font_Codepage437" )
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
	-- Iterate through character Y rows
	for i_Y: number = 0, Font_CharSize_Y - 1 do
		-- 'Buffer_Y_Offset' helps provide appropriate offset for drawing character.
		local Buffer_Y_Offset: number = ( Output_Y + i_Y ) * Settings.Display_Res.x
		-- 'RGB_Y' is used as the Y offset for reading from the RGB texture.
		local RGB_Y_i_Offset: number = i_Y * Font_Texture.Width
		-- Iterate through X; Each pixel within the given Y row
		for i_X: number = 0, Font_CharSize_X - 1 do
			-- Sample of font
			local RGB: vector = Font_Texture[ RGB_i_Start + i_X + RGB_Y_i_Offset ] * 0xFF
			-- Where in the buffer the pixel will be written to
			local bIdx: number = 4 * ( Output_X + i_X + Buffer_Y_Offset )
			buffer.writeu8( Out,  bIdx,		RGB.x )
			buffer.writeu8( Out,  bIdx+1,	RGB.y )
			buffer.writeu8( Out,  bIdx+2,	RGB.z )
		end
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