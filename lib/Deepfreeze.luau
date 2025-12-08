--!strict
--!native
--Deepfreeze: Freezes table and all child tables, prevents writes & improves read speeds when in tight loops
local function Deepfreeze<T>( tab: T, FreezeCount: number? ): T
	if type( tab ) ~= "table" then return tab end
	local FreezeCount: number = FreezeCount or 0
	for i, v in tab do
		-- Prevents cyclic tables from looping infinitely
		if type( v ) == "table" and not table.isfrozen( v ) then
			FreezeCount = Deepfreeze( v )
		end
	end
	table.freeze( tab )
	return tab
end 

return Deepfreeze