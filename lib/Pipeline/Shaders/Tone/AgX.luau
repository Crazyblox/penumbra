--!strict
--!native
-- Tonemapper: AgX [Source: https://www.shadertoy.com/view/dtyfRw] 
local Settings =	require( "../../../Settings" )
local MinEV: number = -10 -- Tonemapper min. exposure
local MaxEV: number = 7.5 -- Tonemapper max. exposure

local To_AgX = {
	vector.create(.842479062253094,.0423282422610123,.0423756549057051),
	vector.create(.0784335999999992,.878468636469772,.0784336),
	vector.create(.0792237451477643,.0791661274605434,.879142973793104)
}

local From_AgX = {
	vector.create(1.19687900512017,-0.0528968517574562,-0.0529716355144438),
	vector.create(-0.0980208811401368,1.15190312990417,-0.0980434501171241),
	vector.create(-0.0990297440797205,-0.0989611768448433,1.15107367264116)
}

table.freeze( To_AgX )
table.freeze( From_AgX )

local function v3_1( n: number ): vector return vector.create( n, n, n ) end

return function( iTime: number, In: {vector}, Out: {vector} )
	local x2: vector, x4: vector
	local vC_1 = v3_1(15.5)
	local vC_2 = v3_1(40.14)
	local vC_3 = v3_1(31.96)
	local vC_4 = v3_1(6.868)
	local vC_5 = v3_1(0.4298)
	local vC_6 = v3_1(0.1191)
	local vC_7 = v3_1(0.00232)
	local vector_zero, vector_one = vector.zero, vector.one
	local minEv: vector = vector.one * MinEV
	local maxEv: vector = vector.one * MaxEV
	local divEv_Reciprocal: vector = 1 / ( maxEv - minEv )
	local To_AgX_1 = To_AgX[1]
	local To_AgX_2 = To_AgX[2]
	local To_AgX_3 = To_AgX[3]
	local From_AgX_1 = From_AgX[1]
	local From_AgX_2 = From_AgX[2]
	local From_AgX_3 = From_AgX[3]
	for c: number = 1, #In do
		local x: vector = In[c]
		x = vector.clamp(
			vector.create(
				math.log( vector.dot( To_AgX_1, x ), 2 ),
				math.log( vector.dot( To_AgX_2, x ), 2 ),
				math.log( vector.dot( To_AgX_3, x ), 2 )
			),
			minEv, maxEv
		)
		x = ( x - minEv ) * divEv_Reciprocal
		local x2: vector = x * x
		local x4: vector = x2 * x2
		x = x4 * x2 *	15.5 -
			x4 * x *	40.14 +
			x4 *		31.96 -
			x2 * x *	6.868 +
			x2 *		0.4298 +
			x *			0.1191 -
			vC_7
		-- AgX -> lRGB Matrix3 Transform [EOTF] -> Clamp 0-1 -> Write changes
		Out[c] = vector.clamp(
			vector.create(
				vector.dot( From_AgX_1, x ),
				vector.dot( From_AgX_2, x ),
				vector.dot( From_AgX_3, x )
			),
			vector_zero,
			vector_one
		)
	end
end