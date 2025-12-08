--!strict
--!native
local VM,S,vec=require("../plugin/vm"),{},vector.create

--[[ PENUMBRA: SETTINGS ]]--
S.Display_Res 	  =	vec(640,360)	-- Output resolution [RBX Max: 1024x1024]
S.Render_Threads  =	8				-- Assigned CPU thread count for './init/render.luau' [RBX Max: Live - 3, Studio - 8]
S.Display_Resample=	"Bilinear"		-- How './plugin/display' will present the output content ["Bilinear", "Nearest"]
--[[ ^^^ USER SETTINGS ]]--

--[[ vvv SANITISATION OF USER SETTINGS SO STUFF DOESN'T BREAK ]]--
S.Render_Threads =	math.max( S.Render_Threads, 1 ) // 1
S.Display_Res //=	1
S.Display_Res =		vector.clamp( vec(S.Display_Res.x,(S.Display_Res.y//S.Render_Threads)*S.Render_Threads), vec(1,1), vec(1024,1024) )
S.Actor_Res =		vec(S.Display_Res.x,S.Display_Res.y//S.Render_Threads)
S.Actor_RenderNum = VM.Env.RenderNum or -1
return table.freeze(S)

--[[ Resolution : Pixel Count
	16:9
160x90 : 14400, 177x100 : 17700, 192x108 : 20736, 213x120 : 25560, 256x144 : 36720, 288x162 : 46656, 320x180 : 57600,
384x216 : 82944, 426x240 : 102240, 470x264 : 124080, 480x270 : 129600, 512x288 : 147456, 533x300 : 159900,
568x320 : 181760, 597x336 : 200592, 640x360 : 230400, 675x380 : 256500, 683x384 : 262272, 711x400 : 284400,
725x408 : 295800, 747x420 : 313740, 768x432 : 331776, 800x450 : 360000, 854x480 : 409920, 910x512 : 465920
960x540 : 518400, 1024x576 : 589824

	4:3
192x144 : 27648, 240x180 : 43200, 320x240 : 76800, 360x270 : 97200, 384x288 : 110592, 416x312 : 129792,
427x320 : 136640, 448x336 : 150528, 480x360 : 172800, 512x384 : 196608, 560x420 : 235200, 640x480 : 307200,
720x540 : 388800, 768x576 : 442368, 800x600 : 480000, 1024x768 : 786432

	RETRO:
[Gameboy] 160x144 : 23040, [Gameboy Advance] 240x160 : 28400, [SNES] 256x224 : 57344,
[NES] 256x240 : 61440, [Megadrive] 320x240 : 76800
]]