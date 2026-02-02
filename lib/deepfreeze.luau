--!strict
--!native
--Deepfreeze: Freezes table and all child tables, prevents writes & improves read speeds when in tight loops
local function Deepfreeze<T>( t: T ): T
	if type( t ) ~= "table" then
		return t
	end
	local tab: {[any]: any} = t :: any
	for _, v in tab do
		-- Prevents cyclic tables from looping infinitely
		if type( v ) == "table" and not table.isfrozen( v ) then
			Deepfreeze( v )
		end
	end
	table.freeze( tab )
	return tab
end 

return Deepfreeze
