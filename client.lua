local fuelingCan = nil

AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon)
	if currentWeapon and currentWeapon.name == 'WEAPON_PETROLCAN' then
		fuelingCan = currentWeapon
	else
		fuelingCan = nil
	end
end)

local function isVehicleCloseEnough(playerCoords, vehicle)
	return #(GetEntityCoords(vehicle) - playerCoords) <= 3
end

local playerPed
local nearestPump

CreateThread(function()
	while true do
		playerPed = cache.ped
		local vehicle = cache.vehicle

		if vehicle and GetIsVehicleEngineRunning(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
			local usage = Config.rpmUsage[math.floor(GetVehicleCurrentRpm(vehicle) * 10) / 10]
			local multiplier = Config.classUsage[GetVehicleClass(vehicle)] or 1.0

			local Vehicle = Entity(vehicle).state
			local fuel = Vehicle.fuel or GetVehicleFuelLevel(vehicle)
			local newFuel = fuel - usage * multiplier

			if newFuel < 0 or newFuel > 100 then
				newFuel = GetVehicleFuelLevel(vehicle)
			end

			SetVehicleFuelLevel(vehicle, newFuel)
			Vehicle:set('fuel', newFuel, true)
		end

		Wait(1000)
	end
end)

local inStation = false
local isFueling = false

CreateThread(function()
	local blip

	if Config.qtarget and Config.showBlips ~= 1 then
		return
	end

	while true do
		local playerCoords = GetEntityCoords(playerPed)

		for station, pumps in pairs(stations) do
			local stationDistance = #(playerCoords - station)
			if stationDistance < 60 then
				if Config.showBlips == 1 and not blip then
					blip = AddBlipForCoord(station.x, station.y, station.z)
					SetBlipSprite(blip, 415)
					SetBlipDisplay(blip, 4)
					SetBlipScale(blip, 0.6)
					SetBlipColour(blip, 23)
					SetBlipAsShortRange(blip, true)
					BeginTextCommandSetBlipName('STRING')
					AddTextComponentSubstringPlayerName('Fuel Station')
					EndTextCommandSetBlipName(blip)
				end

				if not Config.qtarget then
					repeat
						if stationDistance < 15 then
							inStation = true
							local pumpDistance

							repeat
								playerCoords = GetEntityCoords(playerPed)
								for i = 1, #pumps do
									local pump = pumps[i]
									pumpDistance = #(playerCoords - pump)

									if pumpDistance < 3 then
										nearestPump = pump

										while pumpDistance < 3 do
											if IsPedInAnyVehicle(playerPed) then
												DisplayHelpTextThisFrame('fuelLeaveVehicleText', false)
											elseif not isFueling then
												local vehicle = GetPlayersLastVehicle()
												if not isVehicleCloseEnough(playerCoords, vehicle) and Config.petrolCan.enabled then
													DisplayHelpTextThisFrame('petrolcanHelpText', false)
												else
													DisplayHelpTextThisFrame('fuelHelpText', false)
												end
											end

											pumpDistance = #(GetEntityCoords(playerPed) - pump)
											Wait(0)
										end

										nearestPump = nil
									end
								end
								Wait(100)
							until pumpDistance > 15
							break
						end

						Wait(100)
						inStation = false
						stationDistance = #(GetEntityCoords(playerPed) - station)
					until stationDistance > 60
				end
			end
		end


		Wait(500)
		if blip then
			RemoveBlip(blip)
			blip = nil
		end
	end
end)

if Config.showBlips == 2 then
	for station in pairs(stations) do
		local blip = AddBlipForCoord(station.x, station.y, station.z)
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

local ox_inventory = exports.ox_inventory

-- fuelingMode = 1 - Pump
-- fuelingMode = 2 - Can
local function StartFueling(vehicle, fuelingMode)
	isFueling = true
	local Vehicle = Entity(vehicle).state
	local fuel = Vehicle.fuel
	local duration = math.ceil((100 - fuel) / Config.refillValue) * Config.refillTick
	local price, moneyAmount
	local durability = 0

	if 100 - fuel < Config.refillValue then
		isFueling = false
		return ox_inventory:notify({type = 'error', text = 'The tank of this vehicle is full'})
	end

	if fuelingMode == 1 then
		price = 0
		moneyAmount = ox_inventory:Search(2, 'money')
	end

	TaskTurnPedToFaceEntity(playerPed, vehicle, duration)

	Wait(500)

	ox_inventory:Progress({
		duration = duration,
		label = 'Fueling vehicle',
		useWhileDead = false,
		canCancel = true,
		disable = {
			move = true,
			car = true,
			combat = true,
		},
		anim = {
			dict = 'timetable@gardener@filling_can',
			clip = 'gar_ig_5_filling_can',
			flags = 49,
		},
	}, function(cancel)
		if cancel then
			isFueling = false
		end
	end)

	while isFueling do

		if fuelingMode == 1 then
			price += Config.priceTick
			if price >= moneyAmount then
				ox_inventory:CancelProgress()
			end
		end

		if fuelingMode == 2 then
			durability += Config.durabilityTick
			if durability >= fuelingCan.metadata.ammo then
				ox_inventory:CancelProgress()
				TriggerEvent('ox_inventory:disarm')
				TriggerServerEvent('ox_fuel:UpdateCanDurability', fuelingCan, 0)
			end
		end

		fuel += Config.refillValue

		if fuel >= 100 then
			isFueling = false
			fuel = 100.0
		end

		Wait(Config.refillTick)
	end

	Vehicle:set('fuel', fuel, true)
	SetVehicleFuelLevel(vehicle, fuel)
	if fuelingMode == 1 then TriggerServerEvent('ox_fuel:pay', price, fuel) end
	if fuelingMode == 2 then TriggerServerEvent('ox_fuel:UpdateCanDurability', fuelingCan, fuelingCan.metadata.ammo - durability) end
end

local function GetPetrolCan(pumpCoord)
	local petrolCan = ox_inventory:Search('count', 'WEAPON_PETROLCAN')
	LocalPlayer.state.invBusy = true

	TaskTurnPedToFaceCoord(playerPed, pumpCoord, Config.petrolCan.duration)
	-- Linden broke this changing from entity too coord, needs a better solution

	Wait(500)

	ox_inventory:Progress({
		duration = Config.petrolCan.duration,
		label = 'Fueling can',
		useWhileDead = false,
		canCancel = true,
		disable = {
			move = true,
			car = true,
			combat = true,
		},
		anim = {
			dict = 'timetable@gardener@filling_can',
			clip = 'gar_ig_5_filling_can',
			flags = 49,
		},
	}, function(cancel)
		LocalPlayer.state.invBusy = false
		if not cancel then
			if petrolCan > 0 then
				return TriggerServerEvent('ox_fuel:fuelCan', true, Config.petrolCan.refillPrice)
			else
				return TriggerServerEvent('ox_fuel:fuelCan', false, Config.petrolCan.price)
			end
		else
			return false
		end
	end)
end

if not Config.qtarget then
	RegisterCommand('startfueling', function()
		local vehicle = GetPlayersLastVehicle()
		local petrolCan = GetSelectedPedWeapon(playerPed) == `WEAPON_PETROLCAN`
		local playerCoords = GetEntityCoords(playerPed)
		local moneyAmount = ox_inventory:Search(2, 'money')

		if not petrolCan then
			if not inStation or isFueling or IsPedInAnyVehicle(playerPed) then return end
			if not nearestPump then return ox_inventory:notify({type = 'error', text = 'There are no fuel pumps nearby'}) end

			if not isVehicleCloseEnough(playerCoords, vehicle) and Config.petrolCan.enabled then
				if moneyAmount >= Config.petrolCan.price then
					GetPetrolCan(nearestPump)
				else
					ox_inventory:notify({type = 'error', text = 'You cannot afford a petrol can'})
				end
			elseif isVehicleCloseEnough(playerCoords, vehicle) then
				if moneyAmount >= Config.priceTick then
					StartFueling(vehicle, 1)
				else
					ox_inventory:notify({type = 'error', text = 'You cannot afford to refuel your vehicle'})
				end
			else
				return ox_inventory:notify({type = 'error', text = 'Your vehicle is too far away'})
			end
		else
			if not Config.petrolCan.enabled or isFueling or IsPedInAnyVehicle(playerPed) then return end
			if nearestPump then return ox_inventory:notify({type = 'error', text = 'Put your can away before fueling with the pump'}) end

			if isVehicleCloseEnough(playerCoords, vehicle) then
				if fuelingCan.metadata.ammo <= Config.durabilityTick then return end
				StartFueling(vehicle, 2)
			else
				return ox_inventory:notify({type = 'error', text = 'Your vehicle is too far away'})
			end
		end
	end)

	RegisterKeyMapping('startfueling', 'Fuel vehicle', 'keyboard', 'e')
	TriggerEvent('chat:removeSuggestion', '/startfueling')
end


if Config.qtarget then
	exports.qtarget:AddTargetModel(Config.pumpModels, {
		options = {
			{
				action = function (entity)
					if ox_inventory:Search(2, 'money') >= Config.priceTick then
						StartFueling(GetPlayersLastVehicle(), 1)
					else
						ox_inventory:notify({type = 'error', text = 'You cannot afford to refuel your vehicle'})
					end
				end,
				icon = "fas fa-gas-pump",
				label = "Start fueling",
				canInteract = function (entity)
					if isFueling or IsPedInAnyVehicle(playerPed) then
						return false
					end
					return isVehicleCloseEnough(GetEntityCoords(playerPed), GetPlayersLastVehicle())
				end
			},
			{
				action = function (entity)
					if ox_inventory:Search(2, 'money') >= Config.petrolCan.price then
						GetPetrolCan(GetEntityCoords(entity))
					else
						ox_inventory:notify({type = 'error', text = 'You cannot afford a petrol can'})
					end
				end,
				icon = "fas fa-faucet",
				label = "Buy or refill a fuel can",
			},
		},
		distance = 2
	})

	exports.qtarget:Vehicle({
		options = {
			{
				action = function (entity)
					if fuelingCan.metadata.ammo <= Config.durabilityTick then return end
					StartFueling(entity, 2)
				end,
				icon = "fas fa-gas-pump",
				label = "Start fueling",
				canInteract = function (entity)
					if isFueling or IsPedInAnyVehicle(playerPed) then
						return false
					end
					return GetSelectedPedWeapon(playerPed) == `WEAPON_PETROLCAN` and Config.petrolCan.enabled
				end
			}
		},
		distance = 2
	})
end

AddTextEntry('fuelHelpText', 'Press ~INPUT_C2939D45~ to fuel')
AddTextEntry('petrolcanHelpText', 'Press ~INPUT_C2939D45~ to buy or refill a fuel can')
AddTextEntry('fuelLeaveVehicleText', 'Leave the vehicle to be able to start fueling')