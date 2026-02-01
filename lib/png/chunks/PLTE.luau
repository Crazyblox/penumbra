--!strict
--!native

local ChunkTypes = require("../ChunkTypes")
local Types = require("../Types")

local function read(buf: buffer, chunk: Types.Chunk, header: ChunkTypes.IHDR): ChunkTypes.PLTE
	assert(chunk.length % 3 == 0, "malformed PLTE chunk")

	local count = chunk.length / 3
	assert(count > 0, "no entries in PLTE")
	assert(count <= 256, "too many entries in PLTE")
	assert(count <= 2 ^ header.bitDepth, "too many entries in PLTE for bit depth")

	local colors = table.create(count)
	local offset = chunk.offset

	for i = 1, count do
		colors[i] = {
			r = buffer.readu8(buf, offset),
			g = buffer.readu8(buf, offset + 1),
			b = buffer.readu8(buf, offset + 2),
			a = 255,
		}
		offset += 3
	end

	return {
		colors = colors,
	}
end

return read
