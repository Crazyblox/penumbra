--!strict
--!native

--[[
	Penumbra: Init / Settings / Launch Parameters
	
	This module handles inputs such as launch parameters provided via the Pajamas runtime,
	a configurator for the Penumbra project, and provides settings & launch parameters to
	every module calling afterwards.
	
		How to launch:
	local pajamas = require(`./path/to/pajamas`)
	pajamas("penumbra", "main", "640", "360", "8")
	
	The above example calls into pajamas via a server or client script,
	which then passes the launch parameters for penumbra.
	"main" is the module name intended to run on project startup.
	"640" is the X resolution I specified for my video output.
	"360" is the Y resolution I specified for my video output.
	"8" is the number of render threads I wanted to run penumbra with.
	
	Note that all inputs are string based and string representations of
	numbers and booleans will be type coerced, just as if they were
	being launched from the terminal.
	
	Ensure that the .pajamasrc runtime table is correctly configured for
	the context you wish to run this in.
]]

export type self = {
	read Display_Res:		vector,
	read Render_Threads:	number,
	read Display_Resample:	vector,
	read Actor_Res:			vector,
	read Actor_RenderNum:	number
}

export type params = {
	[string]: 		any,
	i:				{[number]: any},
	read Path: 		string,
	read X: 		number,
	read Y: 		number,
	read Threads: 	number,
	read Resample: 	string,
	RenderNum:		number?
}

type pIn = {[number]: any}

local S: any = nil
local P: any = nil
local VM = require( `./plugin/process` )
local display = require( `./plugin/display`)

-- A Pajamas project assumes that data passed to it will always be a strings.
-- This function performs type coercion so that data can be matched with the .pajamasrc module.
local function parse( str: string ): any
	if str == "true" or str == "false" then
		return str == "true"
	end
	return tonumber(str) or str
end

-- Cross-checks launch parameters with Penumbra's .pajamasrc module.
-- Configures & returns settings and launch parameters to the module function.
-- This function is only called once in a given VM.
local function Init(Input: pIn): (self, params)
	local Params, Misc = 		VM.Launch_Parse(Input, require(`@self/.pajamasrc`).params :: any)
	local S_New: any = 			{}
	S_New.Display_Res = 		display.SanitiseResolution( vector.create(Params.X, Params.Y) )
	S_New.Render_Threads = 		math.max(Params.Threads, 1) // 1
	S_New.Display_Resample = 	if ( Params.Resample :: any ) == true then "Bilinear" else "Nearest"
	S_New.Display_Res //= 		1
	S_New.Display_Res = 		vector.create((S_New.Display_Res.x//2)*2,S_New.Display_Res.y)
	S_New.Display_Res =			vector.clamp(
		vector.create(S_New.Display_Res.x, (S_New.Display_Res.y // S_New.Render_Threads) * S_New.Render_Threads),
		vector.create(1, 1), vector.create(1024, 1024)
	)
	S_New.Actor_Res = 			vector.create(S_New.Display_Res.x, S_New.Display_Res.y // S_New.Render_Threads)
	VM.Launch_Init(Misc.Host)
	S_New.Actor_RenderNum = 	Params.RenderNum
	S = 						S_New
	P = 						Params
	-- Run module called via T.Path
	local M = 					require( `@self/{Params.Path}` )() :: any
	-- Return settings and launch parameters
	return S :: self, P :: params
end

-- Perform init or configured settings if already generated
return function(...): (self, params)
	local x = ...
	if (not x) or (S and P) then
		return S :: self, P :: params
	end
	return Init({...} :: pIn)
end

--[[ Resolution : Pixel Count
	16:9
160x90 : 14400,		177x100 : 17700, 	192x108 : 20736, 	213x120 : 25560, 	256x144 : 36720, 	288x162 : 46656, 	320x180 : 57600,
384x216 : 82944, 	426x240 : 102240,	470x264 : 124080, 	480x270 : 129600, 	512x288 : 147456, 	533x300 : 159900,
568x320 : 181760,	597x336 : 200592,	640x360 : 230400, 	675x380 : 256500, 	683x384 : 262272, 	711x400 : 284400,
725x408 : 295800, 	747x420 : 313740, 	768x432 : 331776, 	800x450 : 360000, 	854x480 : 409920, 	910x512 : 465920
960x540 : 518400, 	1024x576 : 589824

	4:3
192x144 : 27648, 	240x180 : 43200, 	320x240 : 76800, 	360x270 : 97200, 	384x288 : 110592, 	416x312 : 129792,
427x320 : 136640, 	448x336 : 150528, 	480x360 : 172800, 	512x384 : 196608, 	560x420 : 235200, 	640x480 : 307200,
720x540 : 388800, 	768x576 : 442368, 	800x600 : 480000, 	1024x768 : 786432

	RETRO:
[Gameboy] 	160x144 : 23040
[GBA]		240x160 : 28400
[SNES]		256x224 : 57344
[NES]		256x240 : 61440
[Genesis]	320x240 : 76800
]]
