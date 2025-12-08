return {
	schema = "0.0.1",
	project = {
		name = "Penumbra",
		author = "Crazyblox",
		version = "25.49.0",
		launch_note = "PENUMBRA IS IN-DEV & SUBJECT TO CHANGE; USE AT YOUR OWN RISK. https://github.com/Crazyblox/Penumbra"
	},
	runtime = {
		default =	{ run = true },
		roblox =	{ run_server = false, run_client = true }
	},
	plugin = {
		["display"] =	{ include = true },
		["event"] =		{ include = true },
		["input"] =		{ include = true },
		["task"] =		{ include = true },
		["vm"] =		{ include = true }
	}
}