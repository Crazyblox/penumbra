local Types = require("./Types")

export type IHDR = {
	width: number,
	height: number,
	bitDepth: number,
	colorType: number,
	interlaced: boolean,
}

export type PLTE = {
	colors: { Types.Color },
}

export type tRNS = {
	gray: number,
	red: number,
	green: number,
	blue: number,
}

return {}
