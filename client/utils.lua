local utils = {}

---@param state StateBag
---@param vehicle integer
---@param fuel number
---@param replicate? boolean
function utils.setFuel(state, vehicle, fuel, replicate)
	if DoesEntityExist(vehicle) then
		fuel = math.clamp(fuel, 0, 100)

		SetVehicleFuelLevel(vehicle, fuel)
		state:set('fuel', fuel, replicate)
	end
end

function utils.getVehicleInFront()
	local coords = GetEntityCoords(cache.ped)
	local destination = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.2, -0.25)
	local handle = StartShapeTestCapsule(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 2.2,
		2, cache.ped, 4)

	while true do
		Wait(0)
		local retval, _, _, _, entityHit = GetShapeTestResult(handle)

		if retval ~= 1 then
			return entityHit ~= 0 and entityHit
		end
	end
end

local bones = {
	'petrolcap',
	'petroltank',
	'petroltank_l',
	'hub_lr',
	'engine',
}

function utils.getVehiclePetrolCapBoneIndex(vehicle)
	for i = 1, #bones do
		local boneIndex = GetEntityBoneIndexByName(vehicle, bones[i])

		if boneIndex ~= -1 then
			return boneIndex
		end
	end
end

return utils
