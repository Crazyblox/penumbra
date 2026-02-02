return {
	schema = "0.0.2",
	project = {
		name = "Penumbra",
		author = "Crazyblox",
		version = "26.04.0",
		launch_note = "Thanks for using Penumbra! Contributions & reports are welcome at https://github.com/Crazyblox/Penumbra"
	},
	runtime = {
		default =	{ run = true },
		roblox =	{ run_server = false, run_client = true }
	},
	plugin = {
		-- Possibly redundant for runtime purposes.
		["display"] =	{ include = true },
		["event"] =		{ include = true },
		["input"] =		{ include = true },
		["task"] =		{ include = true },
		["vm"] =		{ include = true }
	},
	params = {
		-- 'input' is used to sanitise & assert type input.
		-- 'input' value is derived from 'default' if not declared.
		-- 'default' value is used as a fallback if no launch parameter is supplied.
		[1] = { name = "Path",		input = "string" },
		[2] = { name = "X", 		default = 320 },
		[3] = { name = "Y", 		default = 240 },
		[4] = { name = "Threads", 	default = 1 },
		[5] = { name = "Resample", 	default = true },
		[6] = { name = "RenderNum", default = -1 }
	}
}
