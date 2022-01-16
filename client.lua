local inStation = false
local isFueling = false
local inStationInterval

for i = 1, #ox.stations do
    ox.stations[i]:onPlayerInOut(function(isInside)
        inStation = isInside

        if not ox.qtarget and isInside and not isFueling then
            inStationInterval = SetInterval(function()
                DisplayHelpTextThisFrame('fuelHelpText', false)
            end)
        elseif inStationInterval then
            ClearInterval(inStationInterval)
        end
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
    local closestStation
    local currentStation

    SetInterval(function()
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closestDistance

        for i = 1, #ox.stations do
            local station = ox.stations[i]
            local distance = #(playerCoords - station:getBoundingBoxCenter())
            
            if not closestDistance or distance < closestDistance then
                closestDistance = distance
                closestStation = station
            end
        end

        if not currentStation or closestStation ~= currentStation then
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
        end

        currentStation = closestStation
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

local function StartFueling(vehicle)
    -- todo: refactor, make non ox-inventory
    isFueling = true
    local tickCounter = 0
    local Vehicle = Entity(vehicle).state
    local tickNumber = 10
    local fuelAmount = Vehicle.fuel
    local missingFuel = 100 - fuelAmount
    local fuelingDuration = (math.ceil(missingFuel) / 2) * 1000
    local tick = fuelingDuration / tickNumber
    local fuelToAdd = missingFuel / fuelingDuration * tick -- Need better calculation, not 100% accurate
    exports.ox_inventory:Progress({
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
    end)
    while tickCounter < tickNumber and isFueling do
        Wait(tick)
        Vehicle:set('fuel', Vehicle.fuel + fuelToAdd)
    end
end

RegisterCommand('startfueling', function()
    local ped = PlayerPedId()

    if isFueling or not inStation or IsPedInAnyVehicle(ped) then return end

    local playerCoords = GetEntityCoords(ped)

    for i = 1, #ox.pumpModels do
        local pumpObject = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 1.7, ox.pumpModels[i], false, false, false)

        if pumpObject ~= 0 then
            local vehicle = GetPlayersLastVehicle()

            if vehicle ~= 0 and #(GetEntityCoords(vehicle) - playerCoords) < 1.7 then
                TaskTurnPedToFaceEntity(ped, vehicle, -1)
                StartFueling(vehicle)
            end

            return
        end
    end
end)
RegisterKeyMapping('startfueling', 'Fuel vehicle', 'keyboard', 'e')
TriggerEvent('chat:removeSuggestion', '/startfueling')
AddTextEntry('fuelHelpText', 'Press ~INPUT_C2939D45~ to fuel')
