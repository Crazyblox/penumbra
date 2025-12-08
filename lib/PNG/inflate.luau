--!strict
--!native

local HuffmanTable = require("./HuffmanTable")

-- stylua: ignore
local LIT_LEN = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 
	35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
}

-- stylua: ignore
local LIT_EXTRA = {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 
	2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
}

-- stylua: ignore
local DIST_OFF = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513,
	769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
}

-- stylua: ignore
local DIST_EXTRA = {
	0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
	7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
}

-- stylua: ignore
local LEN_ORDER = {
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
}

local FIXED_LIT = {}
for n = 0, 287 do
	FIXED_LIT[n + 1] = if n < 144 or n > 279 then 8 elseif n < 256 then 9 else 7
end

local FIXED_DIST = {}
for n = 0, 31 do
	FIXED_DIST[n + 1] = 5
end

local readFixedLit = HuffmanTable.new(FIXED_LIT).read
local readFixedDist = HuffmanTable.new(FIXED_DIST).read

local function inflate(input: buffer, output: buffer)
	local byteIdx = 0
	local bitIdx = 0

	local function readBit()
		local byte = buffer.readu8(input, byteIdx)
		local bit = bit32.extract(byte, bitIdx)
		bitIdx += 1
		if bitIdx == 8 then
			bitIdx = 0
			byteIdx += 1
		end
		return bit
	end

	local function readBits(count: number)
		local n = 0
		local byte = buffer.readu8(input, byteIdx)
		for p = 0, count - 1 do
			local bit = bit32.extract(byte, bitIdx)
			n += bit32.lshift(bit, p)
			bitIdx += 1
			if bitIdx == 8 then
				bitIdx = 0
				byteIdx += 1
				byte = buffer.readu8(input, byteIdx)
			end
		end
		return n
	end

	local method = readBits(4)
	assert(method == 8, "invalid zlib compression method")

	local info = readBits(4)
	assert(info <= 7, "invalid zlib window size")

	local fcheck = readBits(5)
	local fdict = readBit()
	assert(fdict == 0, "preset dictionary is not allowed")

	local flevel = readBits(2)
	local sum = bit32.bor(
		bit32.lshift(info, 12),
		bit32.lshift(method, 8),
		bit32.lshift(flevel, 6),
		bit32.lshift(fdict, 5),
		fcheck
	)
	assert(sum % 31 == 0, "invalid zlib header sum")

	local window = buffer.create(0x8000)
	local windowIdx = 0
	local outputIdx = 0

	repeat
		local bfinal = readBit()
		local btype = readBits(2)
		assert(btype ~= 3, "reserved btype")
		assert(btype == 0 or btype == 1 or btype == 2, "unknown btype")

		if btype == 0 then
			if bitIdx > 0 then
				byteIdx += 1
				bitIdx = 0
			end

			local len = bit32.bor(buffer.readu8(input, byteIdx), bit32.lshift(buffer.readu8(input, byteIdx + 1), 8))
			local nlen =
				bit32.bor(buffer.readu8(input, byteIdx + 2), bit32.lshift(buffer.readu8(input, byteIdx + 3), 8))
			assert(len + nlen == 0xFFFF, "invalid len/nlen")
			byteIdx += 4

			for _ = 1, len do
				local b = buffer.readu8(input, byteIdx)
				buffer.writeu8(window, windowIdx, b)
				buffer.writeu8(output, outputIdx, b)
				byteIdx += 1
				windowIdx = bit32.band(windowIdx + 1, 0x7FFF)
				outputIdx += 1
			end
		elseif btype == 1 or btype == 2 then
			local readLit = readFixedLit
			local readDist = readFixedDist

			if btype == 2 then
				local litsCount = readBits(5) + 257
				local distsCount = readBits(5) + 1
				local codesCount = readBits(4) + 4

				local codeLengths = table.create(19, 0)
				local readLength
				for i = 1, codesCount do
					codeLengths[LEN_ORDER[i] + 1] = readBits(3)
				end

				local function getReader(numCodes)
					local lengths = {}
					local index = 1
					local length
					while index <= numCodes do
						local code = readLength(readBit)
						local repeatCount = 1
						if code <= 15 then
							length = code
						elseif code == 16 then
							repeatCount = readBits(2) + 3
						elseif code == 17 then
							length = 0
							repeatCount = readBits(3) + 3
						elseif code == 18 then
							length = 0
							repeatCount = readBits(7) + 11
						end
						for _ = 1, repeatCount do
							lengths[index] = length
							index += 1
						end
					end
					return HuffmanTable.new(lengths).read
				end

				readLength = HuffmanTable.new(codeLengths).read
				readLit = getReader(litsCount)
				readDist = getReader(distsCount)
			end

			while true do
				local v = readLit(readBit)
				if v == 0x100 then
					break
				elseif v < 0x100 then
					buffer.writeu8(window, windowIdx, v)
					buffer.writeu8(output, outputIdx, v)
					windowIdx = bit32.band(windowIdx + 1, 0x7FFF)
					outputIdx += 1
				else
					local len = LIT_LEN[v - 0x100]
					local lenExtra = LIT_EXTRA[v - 0x100]
					if lenExtra > 0 then
						len += readBits(lenExtra)
					end
					local d = readDist(readBit)
					local dist = DIST_OFF[d + 1]
					local distExtra = DIST_EXTRA[d + 1]
					if distExtra > 0 then
						dist += readBits(distExtra)
					end
					for _ = 1, len do
						local b = buffer.readu8(window, bit32.band(windowIdx - dist, 0x7FFF))
						buffer.writeu8(window, windowIdx, b)
						buffer.writeu8(output, outputIdx, b)
						windowIdx = bit32.band(windowIdx + 1, 0x7FFF)
						outputIdx += 1
					end
				end
			end
		end
	until bfinal == 1

	return outputIdx
end

return inflate