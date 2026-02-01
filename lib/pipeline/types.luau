-- Pipeline : Types --

export type Shader = (
	T: number,
	In: buffer,
	Out: buffer,
	IL: boolean?
) -> () 

export type Swapchain = {
	Bool: boolean,
	Swap: ( Swapchain, buffer? ) -> ( buffer, buffer ),
	Buffers: { [boolean]: buffer }
}

export type Program = {
	Name: string,
	Execute: ( Program, buffer? ) -> buffer,
	Swapchain: Swapchain,
	Shaders: {Shader}
}

return {}
