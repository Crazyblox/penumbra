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

local function BuildModule(input: ModuleScript): ModuleScript
	-- Get template modules
	local scripts: {ModuleScript} = {
		script.template.prepend,
		input or script.shader,
		script.template.append
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
	outputModule.Name = input.Name
	print("Built inlined module:", outputModule)
	return outputModule
end

local Build = {}

-- Maybe in the future!!!
-- function Build.Directory(dir)
-- end

function Build.Once(input: ModuleScript, output: Instance?): ModuleScript
	BuildModule(input).Parent = output or script.build
end

return Build
