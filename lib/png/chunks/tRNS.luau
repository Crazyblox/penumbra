--!strict
--!native

local ChunkTypes = require("../ChunkTypes")
local Types = require("../Types")

local function readU16(buf: buffer, offset: number, depth: number)
	return bit32.extract(
		bit32.bor(bit32.lshift(buffer.readu8(buf, offset), 8), buffer.readu8(buf, offset + 1)),
		0,
		depth
	)
end

local function read(
	buf: buffer,
	chunk: Types.Chunk,
	header: ChunkTypes.IHDR,
	palette: ChunkTypes.PLTE?
): ChunkTypes.tRNS
	local gray = -1
	local red = -1
	local green = -1
	local blue = -1

	if header.colorType == 0 then
		assert(chunk.length == 2, "invalid tRNS length for color type")
		gray = readU16(buf, chunk.offset, header.bitDepth)
	elseif header.colorType == 2 then
		assert(chunk.length == 6, "invalid tRNS length for color type")
		red = readU16(buf, chunk.offset, header.bitDepth)
		green = readU16(buf, chunk.offset + 2, header.bitDepth)
		blue = readU16(buf, chunk.offset + 4, header.bitDepth)
	else
		local count = chunk.length -- 1 byte per transparency entry
		assert(palette, "tRNS requires PLTE for color type")
		assert(count <= #palette.colors, "tRNS specified too many PLTE alphas")
		for i = 1, count do
			palette.colors[i].a = buffer.readu8(buf, chunk.offset + i - 1)
		end
	end

	return {
		gray = gray,
		red = red,
		green = green,
		blue = blue,
	}
end

return read
