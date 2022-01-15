local Blips = {}
local inStation = false

for i = 1, #ox.stations do
    ox.stations[i]:onPlayerInOut(function(isInside)
        inStation = isInside
    end)

    local Pos = ox.stations[i]:getBoundingBoxCenter()
    Blips[i] = AddBlipForCoord(Pos.x, Pos.y, Pos.z)
    SetBlipSprite(Blips[i], 415)
    SetBlipDisplay(Blips[i], 4)
    SetBlipScale(Blips[i], 0.6)
    SetBlipColour(Blips[i], 23)
    if ox.showBlips == 1 then
        SetBlipAsShortRange(Blips[i], true)
    elseif ox.showBlips == 2 then
        SetBlipAsShortRange(Blips[i], false)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Fuel Station')
    EndTextCommandSetBlipName(Blips[i]) 
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
