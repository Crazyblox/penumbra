-- Types : Textures --

-- Represents what constitutes as a texture.
export type Texture = {
	Width: number,
	Height: number,
	Width0: number,
	Height0: number,
	FD: vector,
	Mult: vector
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