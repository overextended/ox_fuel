if ox.showBlips == 1 then
    -- DISTANCE BLIPS
elseif ox.showBlips == 2 then
    -- CREATE BLIPS
end

-- Synchronize fuel
SetInterval(function()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)

	if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped or not GetIsVehicleEngineRunning(vehicle) then
        return
    end

    local usage = ox.rpmUsage[math.floor(GetVehicleCurrentRpm(vehicle) * 10) / 10]
    local multiplier = ox.classUsage[GetVehicleClass(vehicle)] or 1.0

    local Vehicle = Entity(vehicle).state
    local fuel = Vehicle.fuel

    local newFuel = fuel and fuel - usage * multiplier or GetVehicleFuelLevel(vehicle)

    if newFuel < 0 or newFuel > 100 then return end

    SetVehicleFuelLevel(vehicle, newFuel)
    Vehicle:set('fuel', newFuel, true)
end, 1000)