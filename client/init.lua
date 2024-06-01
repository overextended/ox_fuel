local config = require 'config'

if not config then return end

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

local utils = require 'client.utils'

local function startDrivingVehicle()
	local vehicle = cache.vehicle

	if not DoesVehicleUseFuel(vehicle) then return end

	local state = Entity(vehicle).state

	if not state.fuel then
		state:set('fuel', GetVehicleFuelLevel(vehicle), true)
		while not state.fuel do Wait(0) end
	end

	SetVehicleFuelLevel(vehicle, state.fuel)

	local fuelTick = 0

	while cache.seat == -1 do
		if not DoesEntityExist(vehicle) then return end

		local fuel = tonumber(state.fuel)
		local newFuel = GetVehicleFuelLevel(vehicle)

		if fuel > 0 then
			if GetVehiclePetrolTankHealth(vehicle) < 700 then
				newFuel -= math.random(10, 20) * 0.01
			end

			if fuel ~= newFuel then
				if fuelTick == 15 then
					fuelTick = 0
				end

				print('update fuel', fuel, fuel - newFuel)

				utils.setFuel(state, vehicle, newFuel, fuelTick == 0)
				fuelTick += 1
			end
		end

		Wait(1000)
	end

	utils.setFuel(state, vehicle, state.fuel, true)
end

if cache.seat == -1 then CreateThread(startDrivingVehicle) end

local lastVehicle = cache.vehicle or GetPlayersLastVehicle()

lib.onCache('seat', function(seat)
	if cache.vehicle then
		lastVehicle = cache.vehicle
	end

	if seat == -1 then
		SetTimeout(0, startDrivingVehicle)
	end
end)

local createBlip = require 'client.createBlip'
local stations = require 'data.stations'
local isFueling = false
local nearestPump

CreateThread(function()
	if config.showBlips == 2 then
		for station in pairs(stations) do createBlip(station) end
	end

	local blip

	if config.ox_target and config.showBlips ~= 1 then return end

	while true do
		local playerCoords = GetEntityCoords(cache.ped)

		for station, pumps in pairs(stations) do
			local stationDistance = #(playerCoords - station)
			if stationDistance < 60 then
				if config.showBlips == 1 and not blip then
					blip = createBlip(station)
				end

				if not config.ox_target then
					repeat
						if stationDistance < 15 then
							local pumpDistance

							repeat
								playerCoords = GetEntityCoords(cache.ped)
								for i = 1, #pumps do
									local pump = pumps[i]
									pumpDistance = #(playerCoords - pump)

									if pumpDistance < 3 then
										nearestPump = pump

										while pumpDistance < 3 do
											if cache.vehicle then
												DisplayHelpTextThisFrame('fuelLeaveVehicleText', false)
											elseif not isFueling then
												local vehicleInRange = lastVehicle ~= 0 and
													#(GetEntityCoords(lastVehicle) - playerCoords) <= 3

												if vehicleInRange then
													DisplayHelpTextThisFrame('fuelHelpText', false)
												elseif config.petrolCan.enabled then
													DisplayHelpTextThisFrame('petrolcanHelpText', false)
												end
											end

											pumpDistance = #(GetEntityCoords(cache.ped) - pump)
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
						stationDistance = #(GetEntityCoords(cache.ped) - station)
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

local ox_inventory = exports.ox_inventory

---@return number
local function defaultMoneyCheck()
	return ox_inventory:GetItemCount('money')
end

local getMoneyAmount = defaultMoneyCheck

exports('setMoneyCheck', function(fn)
	getMoneyAmount = fn or defaultMoneyCheck
end)

local fuelingCan = ox_inventory:getCurrentWeapon()

AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon)
	fuelingCan = currentWeapon?.name == 'WEAPON_PETROLCAN' and currentWeapon
end)

-- fuelingMode = 1 - Pump
-- fuelingMode = 2 - Can
local function startFueling(vehicle, isPump)
	local Vehicle = Entity(vehicle).state
	local fuel = Vehicle.fuel or GetVehicleFuelLevel(vehicle)
	local duration = math.ceil((100 - fuel) / config.refillValue) * config.refillTick
	local price, moneyAmount
	local durability = 0

	if 100 - fuel < config.refillValue then
		return lib.notify({ type = 'error', description = locale('tank_full') })
	end

	if isPump then
		price = 0
		moneyAmount = getMoneyAmount()

		if config.priceTick > moneyAmount then
			return lib.notify({
				type = 'error',
				description = locale('not_enough_money', config.priceTick)
			})
		end
	elseif not fuelingCan then
		return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
	elseif fuelingCan.metadata.ammo <= config.durabilityTick then
		return lib.notify({
			type = 'error',
			description = locale('petrolcan_not_enough_fuel')
		})
	end

	isFueling = true

	TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)
	Wait(500)

	CreateThread(function()
		lib.progressCircle({
			duration = duration,
			useWhileDead = false,
			canCancel = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = isPump and 'timetable@gardener@filling_can' or 'weapon@w_sp_jerrycan',
				clip = isPump and 'gar_ig_5_filling_can' or 'fire',
			},
		})

		isFueling = false
	end)

	while isFueling do
		if isPump then
			price += config.priceTick

			if price + config.priceTick >= moneyAmount then
				lib.cancelProgress()
			end
		elseif fuelingCan then
			durability += config.durabilityTick

			if durability >= fuelingCan.metadata.ammo then
				lib.cancelProgress()
				durability = fuelingCan.metadata.ammo
				break
			end
		else
			break
		end

		fuel += config.refillValue

		if fuel >= 100 then
			isFueling = false
			fuel = 100.0
		end

		Wait(config.refillTick)
	end

	ClearPedTasks(cache.ped)

	if isPump then
		TriggerServerEvent('ox_fuel:pay', price, fuel, NetworkGetNetworkIdFromEntity(vehicle))
	else
		TriggerServerEvent('ox_fuel:updateFuelCan', durability, NetworkGetNetworkIdFromEntity(vehicle), fuel)
	end
end

local function getPetrolCan(pumpCoord, refuel)
	TaskTurnPedToFaceCoord(cache.ped, pumpCoord.x, pumpCoord.y, pumpCoord.z, config.petrolCan.duration)
	Wait(500)

	if lib.progressCircle({
			duration = config.petrolCan.duration,
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
			}
		}) then
		if refuel and ox_inventory:Search('count', 'WEAPON_PETROLCAN') then
			return TriggerServerEvent('ox_fuel:fuelCan', true, config.petrolCan.refillPrice)
		end

		TriggerServerEvent('ox_fuel:fuelCan', false, config.petrolCan.price)
	end

	ClearPedTasks(cache.ped)
end

local utils = require 'client.utils'

if not config.ox_target then
	RegisterCommand('startfueling', function()
		if isFueling or cache.vehicle or lib.progressActive() then return end

		local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
		local playerCoords = GetEntityCoords(cache.ped)

		if nearestPump then
			local moneyAmount = getMoneyAmount()

			if petrolCan and moneyAmount >= config.petrolCan.refillPrice then
				return getPetrolCan(nearestPump, true)
			end

			local vehicleInRange = lastVehicle and #(GetEntityCoords(lastVehicle) - playerCoords) <= 3

			if not vehicleInRange then
				if not config.petrolCan.enabled then return end

				if moneyAmount >= config.petrolCan.price then
					return getPetrolCan(nearestPump)
				end

				return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
			elseif moneyAmount >= config.priceTick then
				return startFueling(lastVehicle, true)
			else
				return lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
			end

			return lib.notify({ type = 'error', description = locale('vehicle_far') })
		elseif petrolCan then
			local vehicle = utils.getVehicleInFront()

			if vehicle then
				local hasFuel = config.classUsage[GetVehicleClass(vehicle)] or true

				if hasFuel == 0.0 then return end

				local boneIndex = utils.getVehiclePetrolCapBoneIndex(vehicle)
				local fuelcapPosition = boneIndex and GetWorldPositionOfEntityBone(vehicle, boneIndex)

				if fuelcapPosition and #(playerCoords - fuelcapPosition) < 1.8 then
					return startFueling(vehicle, false)
				end

				return lib.notify({ type = 'error', description = locale('vehicle_far') })
			end
		end
	end)

	RegisterKeyMapping('startfueling', 'Fuel vehicle', 'keyboard', 'e')
	TriggerEvent('chat:removeSuggestion', '/startfueling')
end


if config.ox_target then
	if config.petrolCan.enabled then
		exports.ox_target:addModel(config.pumpModels, {
			{
				distance = 2,
				onSelect = function()
					if getMoneyAmount() >= config.priceTick then
						startFueling(lastVehicle, 1)
					else
						lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
					end
				end,
				icon = "fas fa-gas-pump",
				label = locale('start_fueling'),
				canInteract = function(entity)
					if isFueling or cache.vehicle or lib.progressActive() then
						return false
					end

					return lastVehicle and #(GetEntityCoords(lastVehicle) - GetEntityCoords(cache.ped)) <= 3
				end
			},
			{
				distance = 2,
				onSelect = function(data)
					local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
					local moneyAmount = getMoneyAmount()

					if moneyAmount < config.petrolCan.price then
						return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
					end

					return getPetrolCan(data.coords, petrolCan)
				end,
				icon = "fas fa-faucet",
				label = locale('petrolcan_buy_or_refill'),
			},
		})
	else
		exports.ox_target:addModel(config.pumpModels, {
			{
				distance = 2,
				onSelect = function()
					if getMoneyAmount() >= config.priceTick then
						if GetVehicleFuelLevel(lastVehicle) >= 100 then
							return lib.notify({ type = 'error', description = locale('vehicle_full') })
						end
						startFueling(lastVehicle, 1)
					else
						lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
					end
				end,
				icon = "fas fa-gas-pump",
				label = locale('start_fueling'),
				canInteract = function(entity)
					if isFueling or cache.vehicle then
						return false
					end

					return lastVehicle and #(GetEntityCoords(lastVehicle) - GetEntityCoords(cache.ped)) <= 3
				end
			},
		})
	end
	if config.petrolCan.enabled then
		exports.ox_target:addGlobalVehicle({
			{
				distance = 2,
				onSelect = function(data)
					if not fuelingCan then
						return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
					end

					if fuelingCan.metadata.ammo <= config.durabilityTick then
						return lib.notify({
							type = 'error',
							description = locale('petrolcan_not_enough_fuel')
						})
					end

					startFueling(data.entity)
				end,
				icon = "fas fa-gas-pump",
				label = locale('start_fueling'),
				canInteract = function(entity)
					if isFueling or cache.vehicle or lib.progressActive() then
						return false
					end
					return fuelingCan and config.petrolCan.enabled
				end
			}
		})
	end
end

AddTextEntry('fuelHelpText', locale('fuel_help'))
AddTextEntry('petrolcanHelpText', locale('petrolcan_help'))
AddTextEntry('fuelLeaveVehicleText', locale('leave_vehicle'))
