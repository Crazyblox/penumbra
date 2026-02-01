-- Types : Textures --

-- Represents what constitutes as a texture.
export type Texture = {
	[number]: 			vector,
	read Buffer:		buffer,
	read Dimensions:	vector,
	read Width:			number,
	read Height:		number,
	read Width0:		number,
	read Height0:		number,
	read FD:			vector,
	read Mult:			vector | number
}

-- A superset of textures used in a 3d context.
export type Cubemap = typeof( 
	setmetatable(
		{} :: { [ vector ]: Texture },
		{} :: { __index: Texture }
	)
)

-- Required input when asking to load a texture.
export type LoadTexture = { 
	[number]: {
		Name: string,
		Config: {any}?
	}
}

return {}
