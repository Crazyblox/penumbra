-- Pipeline : Types --
local Textures = require(`../textures`)

export type Shader = {
	-- Shader needs its own write buffer due to temporal accumulation.
	read FB_Slice_Write: buffer,
	read Run: ShaderModule
}

export type ShaderModule = (
	T: number,
	Sync_FB_Slice_Read: buffer,
	FB_Slice_Write: buffer, --Out: buffer,
	IL: boolean,
	FB_Full: Textures.Texture
) -> () 

export type Swapchain = {
	Bool: boolean,
	Swap: ( Swapchain, buffer? ) -> ( buffer, buffer ),
	Buffers: { [boolean]: buffer }
}

export type Program = {
	Name: string,
	Execute: ( Program, buffer? ) -> (),
	Shaders: { Shader }
}

return {}
