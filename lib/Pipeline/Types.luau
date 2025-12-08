-- Pipeline : Types --

export type Shader = (
	T: number,
	In: {vector},
	Out: {vector}
) -> {vector}

export type Swapchain = {
	Bool: boolean,
	Swap: ( Swapchain, {vector}? ) -> ( {vector}, {vector} ),
	Buffers: { [boolean]: {vector} }
}
export type Program = {
	Name: string,
	Execute: ( Program, {vector}? ) -> {vector},
	Swapchain: Swapchain,
	Shaders: {Shader}
}

return {}