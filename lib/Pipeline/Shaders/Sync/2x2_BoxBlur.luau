--!strict
--!native
-- As the project currently stands in WIP, this filter is the only 'Sync' one that behaves.
-- Gets the idea across for how framebuffer slices are shared with one another in order to
-- perform convolutional filters.
-- More sync filters are likely to be packaged in future versions for as long as they and
-- the sync feature itself behaves correctly in the future.
local Pipeline = require( `../../../Pipeline` )
return function( T: number, In: {vector}, Out: {vector} )
	local ExtUp = Pipeline.Shared.External_Above
	local ExtDn = Pipeline.Shared.External_Below
	local OffUp: number = Pipeline.Kernels.PixelCount
	local OffDn: number = -Pipeline.Kernels.PixelCount
	local kI = Pipeline.Kernels.k3x3.Index
	-- Storables: [0,1], [0,2]
	local X0_Y1: vector = In[1+kI[4]] or ExtUp[OffUp+1+kI[4]]
	local X0_Y2: vector = In[1+kI[7]] or ExtDn[OffDn+1+kI[7]]
	local kI_8: number = kI[8]
	for c: number = 1, #In do
		-- Read new values
		local X1_Y1: vector = In[c] 
		local X1_Y2: vector = In[c+kI_8] or ExtDn[OffDn+c+kI_8]
		-- Write value
		Out[c] = ( X0_Y1 + X1_Y1 + X0_Y2 + X1_Y2 ) * 0.25
		-- Store for next iteration
		X0_Y1 = X1_Y1
		X0_Y2 = X1_Y2
	end
end