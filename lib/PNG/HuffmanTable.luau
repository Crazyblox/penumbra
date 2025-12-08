--!strict
--!native

local function new(lengths: { number })
	local blCount = {}
	local maxBits = 0
	for _, len in lengths do
		if len > 0 then
			blCount[len] = (blCount[len] or 0) + 1
			if len > maxBits then
				maxBits = len
			end
		end
	end

	local thisCode = 1
	local nextCode = {}
	for bits = 1, maxBits do
		thisCode = 2 * (thisCode + (blCount[bits - 1] or 0))
		nextCode[bits] = thisCode
	end

	local look = {}
	for n, len in lengths do
		if len > 0 then
			look[nextCode[len]] = n - 1
			nextCode[len] += 1
		end
	end

	local function read(readBit: () -> number)
		local code = 1
		repeat
			code = 2 * code + readBit()
		until look[code]
		return look[code]
	end

	return {
		read = read,
	}
end

return {
	new = new,
}