--!strict
--!native

local ChunkTypes = require("../ChunkTypes")
local Types = require("../Types")

local COLOR_TYPE_BIT_DEPTH = {
	[0] = { 1, 2, 4, 8, 16 },
	[2] = { 8, 16 },
	[3] = { 1, 2, 4, 8 },
	[4] = { 8, 16 },
	[6] = { 8, 16 },
}

local function read(buf: buffer, chunk: Types.Chunk): ChunkTypes.IHDR
	assert(chunk.length == 13, "IHDR data must be 13 bytes")

	local offset = chunk.offset

	local width = bit32.byteswap(buffer.readu32(buf, offset))
	local height = bit32.byteswap(buffer.readu32(buf, offset + 4))
	local bitDepth = buffer.readu8(buf, offset + 8)
	local colorType = buffer.readu8(buf, offset + 9)
	local compression = buffer.readu8(buf, offset + 10)
	local filter = buffer.readu8(buf, offset + 11)
	local interlace = buffer.readu8(buf, offset + 12)

	assert(width > 0 and width <= 2 ^ 31 and height > 0 and height <= 2 ^ 31, "invalid dimensions")
	assert(compression == 0, "invalid compression method")
	assert(filter == 0, "invalid filter method")
	assert(interlace == 0 or interlace == 1, "invalid interlace method")

	local allowedBitDepth = COLOR_TYPE_BIT_DEPTH[colorType]
	assert(allowedBitDepth ~= nil, "invalid color type")
	assert(table.find(allowedBitDepth, bitDepth) ~= nil, "invalid bit depth")

	return {
		width = width,
		height = height,
		bitDepth = bitDepth,
		colorType = colorType,
		interlaced = interlace == 1,
	}
end

return read
