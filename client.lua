local isFueling = false
local function StartFueling(vehicle)
    -- todo: refactor, make non ox-inventory
    isFueling = true
    local Vehicle = Entity(vehicle).state
    local fuelAmount = Vehicle.fuel
    local fuelingDuration = ((100 - math.ceil(fuelAmount)) / 2) * 1000
    local tick = fuelingDuration / 10
    local fuelToAdd = (100 - fuelAmount) / fuelingDuration * tick -- Need better calculation, not 100% accurate
    --[[exports.ox_inventory:Progress({
        duration = fuelingDuration,
        label = 'Fueling vehicle',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
            flags = 49,
        },
    }, function(cancel)
        isFueling = false
    end)]]--
    while Vehicle.fuel < 100 do
        Wait(tick)
        Vehicle:set('fuel', Vehicle.fuel + fuelToAdd)
    end
end

local gasPumps = {
    `prop_gas_pump_old2`,
    `prop_gas_pump_1a`,
    `prop_vintage_pump`,
    `prop_gas_pump_old3`,
    `prop_gas_pump_1c`,
    `prop_gas_pump_1b`,
    `prop_gas_pump_1d`,
}

local inStation = false

for i = 1, #ox.stations do
    ox.stations[i]:onPlayerInOut(function(isInside)
        inStation = isInside
    end)

    if ox.showBlips == 2 then
        local coords = ox.stations[i]:getBoundingBoxCenter()
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 415)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 23)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Fuel Station')
        EndTextCommandSetBlipName(blip)
    end
end

if ox.showBlips == 1 then
    local currentBlip
    local closestDistance
    local closestStation

    SetInterval(function()
        local playerCoords = GetEntityCoords(PlayerPedId())

        for i = 1, #ox.stations do
            local station = ox.stations[i]
            local distance = #(playerCoords - station:getBoundingBoxCenter())

            if not closestDistance or distance < closestDistance then
                closestDistance = distance
                closestStation = station
            end
        end

        if DoesBlipExist(currentBlip) then
            RemoveBlip(currentBlip)
        end

        local coords = closestStation:getBoundingBoxCenter()
        currentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(currentBlip, 415)
        SetBlipDisplay(currentBlip, 4)
        SetBlipScale(currentBlip, 0.6)
        SetBlipColour(currentBlip, 23)
        SetBlipAsShortRange(currentBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Closest Fuel Station')
        EndTextCommandSetBlipName(currentBlip)
    end, 5000)
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

RegisterCommand('startfueling', function()
    local playerPed = PlayerPedId()
    if not inStation or GetVehiclePedIsIn(playerPed, false) ~= 0 or isFueling then return end
    local playerCoords = GetEntityCoords(playerPed)
    for i = 1, #gasPumps do
        local pump = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 3.0, gasPumps[i], false, false, false)
        if pump ~= 0 then
            local vehicle = GetPlayersLastVehicle()
            if vehicle ~= 0 and #(GetEntityCoords(vehicle) - playerCoords) < 3.0 then
                TaskTurnPedToFaceEntity(playerPed, vehicle, -1)
                StartFueling(vehicle)
            return end
        break end
    end
end)
RegisterKeyMapping('startfueling', 'Fuel vehicle', 'keyboard', 'e')