--[[
	Penumbra: Shader module builder [Roblox]
	
	This module allows you to build shader modules in Roblox Studio.
	
	This works by inlining 'template/prepend.luau' and 'template/append.luau',
	with your own provided shader modulein the middle.
	If a shader module isn't provided, then 'template/shader.luau' module will be used.
	'--!strict' and '--!native' will be inlined by default.
	
	If you want to take advantage of this module builder, call the function
	with your shader module as the given input.
	
	The system will look for all occurences of '--/INLINE', and copy the
	relevant source into the module you are building.
	
	This should allow for quicker iteration on the creation of a shader module
	which is compatible with Penumbra.
	
	If you're developing outside of Roblox, it might be better for you
	to write your own shell script to do this.
]]

local function BuildShader(in_prepend: ModuleScript, in_shader: ModuleScript, in_append: ModuleScript): ModuleScript
	-- Get template modules
	local scripts: {ModuleScript} = {
		in_prepend or script.template.frag.prepend,
		in_shader or script.template.frag.shader,
		in_append or script.template.frag.append
	}
	local outputSource: string = `--!strict\n--!native\n`
	for _, module: ModuleScript in scripts do
		local source: string = module.Source
		local splitChar: {string} = string.split( source, `--/INLINE\n` )
		table.remove( splitChar, 1 )
		for i = 1, #splitChar do
			outputSource ..= splitChar[i]..`\n`
		end
		print(`Inlined '{module.Name}'`)
	end
	local outputModule = Instance.new("ModuleScript")
	outputModule.Source = outputSource
	outputModule.Name = in_shader.Name
	print("Built inlined module:", outputModule)
	return outputModule
end

local Build = {}

function Build.Directory(dir, output)
	dir = dir or script.Parent.src
	local dirs = dir:GetChildren()
	for _, d in dirs do
		local shader_type = d.Name
		local modules = d:GetChildren()
		for _, m in modules do
			if m:IsA("ModuleScript") then
				BuildShader(
					script.template[shader_type].prepend,
					m,
					script.template[shader_type].append
				).Parent = ( output and output[shader_type] or script.parent.shaders[shader_type] )
			end
		end
	end
end

function Build.OnceFromSource(input: ModuleScript, output: Instance?): ModuleScript
	BuildShader(input).Parent = output or script.parent.shaders
end

return Build
