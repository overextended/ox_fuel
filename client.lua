lib.locale()

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

local function Raycast(flag)
	local playerCoords = GetEntityCoords(cache.ped)
	local plyOffset = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.2, -0.25)
	local rayHandle = StartShapeTestCapsule(playerCoords.x, playerCoords.y, playerCoords.z + 0.5, plyOffset.x, plyOffset.y, plyOffset.z, 2.2, flag or 30, cache.ped)
	while true do
		Wait(0)
		local result, _, _, _, entityHit = GetShapeTestResult(rayHandle)
		if result ~= 1 then
			local entityType
			if entityHit then entityType = GetEntityType(entityHit) end
			if entityHit and entityType ~= 0 then
				return entityHit, entityType
			end
			return false
		end
	end
end

local function setFuel(state, vehicle, fuel, replicate)
	if DoesEntityExist(vehicle) then
		SetVehicleFuelLevel(vehicle, fuel)

		if not state.fuel then
			TriggerServerEvent('ox_fuel:createStatebag', NetworkGetNetworkIdFromEntity(vehicle), fuel)
		else
			state:set('fuel', fuel, replicate)
		end
	end
end

lib.onCache('seat', function(seat)
	if seat == -1 then
		SetTimeout(0, function()
			local vehicle = cache.vehicle
			local multiplier = Config.classUsage[GetVehicleClass(vehicle)] or 1.0

			-- Vehicle doesn't use fuel
			if multiplier == 0.0 then return end

			local state = Entity(vehicle).state

			if not state.fuel then
				TriggerServerEvent('ox_fuel:createStatebag', NetworkGetNetworkIdFromEntity(vehicle), GetVehicleFuelLevel(vehicle))
				while not state.fuel do Wait(0) end
			end

			local fuelTick = 0

			while cache.seat == -1 do
				if GetIsVehicleEngineRunning(vehicle) then
					local usage = Config.rpmUsage[math.floor(GetVehicleCurrentRpm(vehicle) * 10) / 10]
					local fuel = state.fuel
					local newFuel = fuel - usage * multiplier

					if newFuel < 0 or newFuel > 100 then
						newFuel = fuel
					end

					if fuel ~= newFuel then
						if fuelTick == 15 then
							fuelTick = 0
						end

						setFuel(state, vehicle, newFuel, fuelTick == 0)
						fuelTick += 1
					end
				end

				Wait(1000)
			end

			setFuel(state, vehicle, state.fuel, true)
		end)
	end
end)

local inStation = false
local isFueling = false
local nearestPump

local function createBlip(station)
	local blip = AddBlipForCoord(station.x, station.y, station.z)
	SetBlipSprite(blip, 415)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.6)
	SetBlipColour(blip, 23)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(locale('fuel_station_blip'))
	EndTextCommandSetBlipName(blip)
	return blip
end

CreateThread(function()
	local blip
	if Config.qtarget and Config.showBlips ~= 1 then return end

	while true do
		local playerCoords = GetEntityCoords(cache.ped)

		for station, pumps in pairs(stations) do
			local stationDistance = #(playerCoords - station)
			if stationDistance < 60 then
				if Config.showBlips == 1 and not blip then
					blip = createBlip(station)
				end

				if not Config.qtarget then
					repeat
						if stationDistance < 15 then
							inStation = true
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
												local vehicle = GetPlayersLastVehicle()

												if not isVehicleCloseEnough(playerCoords, vehicle) and Config.petrolCan.enabled then
													DisplayHelpTextThisFrame('petrolcanHelpText', false)
												else
													DisplayHelpTextThisFrame('fuelHelpText', false)
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
						inStation = false
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

if Config.showBlips == 2 then
	for station in pairs(stations) do createBlip(station) end
end

local ox_inventory = exports.ox_inventory

-- fuelingMode = 1 - Pump
-- fuelingMode = 2 - Can
local function startFueling(vehicle, isPump)
	isFueling = true
	local Vehicle = Entity(vehicle).state
	local fuel = Vehicle.fuel or GetVehicleFuelLevel(vehicle)
	local duration = math.ceil((100 - fuel) / Config.refillValue) * Config.refillTick
	local price, moneyAmount
	local durability = 0

	if 100 - fuel < Config.refillValue then
		isFueling = false
		return lib.notify({type = 'error', description = locale('tank_full')})
	end

	if isPump then
		price = 0
		moneyAmount = ox_inventory:Search(2, 'money')
	end

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
			price += Config.priceTick

			if price >= moneyAmount then
				lib.cancelProgress()
			end
		else
			durability += Config.durabilityTick

			if durability >= fuelingCan.metadata.ammo then
				lib.cancelProgress()
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

	setFuel(Vehicle, vehicle, fuel, true)

	if isPump then
		TriggerServerEvent('ox_fuel:pay', price, fuel)
	else
		TriggerServerEvent('ox_fuel:UpdateCanDurability', fuelingCan, fuelingCan.metadata.ammo - durability)
	end
end

local function GetPetrolCan(pumpCoord)
	LocalPlayer.state.invBusy = true
	TaskTurnPedToFaceCoord(cache.ped, pumpCoord, Config.petrolCan.duration)
	Wait(500)

	if lib.progressCircle({
		duration = Config.petrolCan.duration,
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
		local petrolCan = ox_inventory:Search('count', 'WEAPON_PETROLCAN')

		if petrolCan > 0 then
			TriggerServerEvent('ox_fuel:fuelCan', true, Config.petrolCan.refillPrice)
		else
			TriggerServerEvent('ox_fuel:fuelCan', false, Config.petrolCan.price)
		end
	end

	LocalPlayer.state.invBusy = false
end

if not Config.qtarget then
	local bones = {'wheel_rr', 'wheel_lr'}
	RegisterCommand('startfueling', function()
		if lib.progressActive() then return end
		local vehicle = GetPlayersLastVehicle()
		local petrolCan = GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
		local playerCoords = GetEntityCoords(cache.ped)
		local moneyAmount = ox_inventory:Search(2, 'money')

		if not petrolCan then
			if not inStation or isFueling or cache.vehicle then return end

			if not isVehicleCloseEnough(playerCoords, vehicle) and Config.petrolCan.enabled then
				if moneyAmount >= Config.petrolCan.price then
					GetPetrolCan(nearestPump)
				else
					lib.notify({type = 'error', description = locale('petrolcan_cannot_afford')})
				end
			elseif isVehicleCloseEnough(playerCoords, vehicle) then
				if moneyAmount >= Config.priceTick then
					startFueling(vehicle, true)
				else
					lib.notify({type = 'error', description = locale('refuel_cannot_afford')})
				end
			else
				return lib.notify({type = 'error', description = locale('vehicle_far')})
			end
		else
			if not Config.petrolCan.enabled or isFueling or cache.vehicle then return end
			if nearestPump then return lib.notify({type = 'error', description = locale('pump_fuel_with_can')}) end

			local entityHit, _ = Raycast()
			if not entityHit then return end
			for i = 1, #bones do
				local fuelcap = GetEntityBoneIndexByName(entityHit, bones[i])
				local fuelcapPosition = GetWorldPositionOfEntityBone(entityHit, fuelcap)
				local distance = #(GetEntityCoords(cache.ped) - fuelcapPosition)
				local closeToVehicle = distance < 1.3 and true or false
				if closeToVehicle then
					return startFueling(entityHit, false)
				else
					if i == #bones then return lib.notify({type = 'error', description = locale('vehicle_far')}) end
				end
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
						startFueling(GetPlayersLastVehicle(), 1)
					else
						lib.notify({type = 'error', description = locale('refuel_cannot_afford')})
					end
				end,
				icon = "fas fa-gas-pump",
				label = locale('start_fueling'),
				canInteract = function (entity)
					if isFueling or cache.vehicle then
						return false
					end
					return isVehicleCloseEnough(GetEntityCoords(cache.ped), GetPlayersLastVehicle())
				end
			},
			{
				action = function (entity)
					if ox_inventory:Search(2, 'money') >= Config.petrolCan.price then
						GetPetrolCan(GetEntityCoords(entity))
					else
						lib.notify({type = 'error', description = locale('petrolcan_cannot_afford')})
					end
				end,
				icon = "fas fa-faucet",
				label = locale('petrolcan_buy_or_refill'),
			},
		},
		distance = 2
	})

	exports.qtarget:Vehicle({
		options = {
			{
				action = function (entity)
					if fuelingCan.metadata.ammo <= Config.durabilityTick then return end
					startFueling(entity)
				end,
				icon = "fas fa-gas-pump",
				label = locale('start_fueling'),
				canInteract = function (entity)
					if isFueling or cache.vehicle then
						return false
					end
					return GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN` and Config.petrolCan.enabled
				end
			}
		},
		distance = 2
	})
end

AddTextEntry('fuelHelpText', locale('fuel_help'))
AddTextEntry('petrolcanHelpText', locale('petrolcan_help'))
AddTextEntry('fuelLeaveVehicleText', locale('leave_vehicle'))
