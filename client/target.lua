local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'

if config.petrolCan.enabled then
	exports.ox_target:addModel(config.pumpModels, {
		{
			distance = 2,
			onSelect = function()
				if utils.getMoney() >= config.priceTick then
					fuel.startFueling(state.lastVehicle, 1)
				else
					lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
				end
			end,
			icon = "fas fa-gas-pump",
			label = locale('start_fueling'),
			canInteract = function(entity)
				if state.isFueling or cache.vehicle or lib.progressActive() then
					return false
				end

				return state.lastVehicle and #(GetEntityCoords(state.lastVehicle) - GetEntityCoords(cache.ped)) <= 3
			end
		},
		{
			distance = 2,
			onSelect = function(data)
				local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
				local moneyAmount = utils.getMoney()

				if moneyAmount < config.petrolCan.price then
					return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
				end

				return fuel.getPetrolCan(data.coords, petrolCan)
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
				if utils.getMoney() >= config.priceTick then
					if GetVehicleFuelLevel(state.lastVehicle) >= 100 then
						return lib.notify({ type = 'error', description = locale('vehicle_full') })
					end
					fuel.startFueling(state.lastVehicle, 1)
				else
					lib.notify({ type = 'error', description = locale('refuel_cannot_afford') })
				end
			end,
			icon = "fas fa-gas-pump",
			label = locale('start_fueling'),
			canInteract = function(entity)
				if state.isFueling or cache.vehicle or not DoesVehicleUseFuel(state.lastVehicle) then
					return false
				end

				return state.lastVehicle and #(GetEntityCoords(state.lastVehicle) - GetEntityCoords(cache.ped)) <= 3
			end
		},
	})
end

if config.petrolCan.enabled then
	exports.ox_target:addGlobalVehicle({
		{
			distance = 2,
			onSelect = function(data)
				if not state.petrolCan then
					return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
				end

				if state.petrolCan.metadata.ammo <= config.durabilityTick then
					return lib.notify({
						type = 'error',
						description = locale('petrolcan_not_enough_fuel')
					})
				end

				fuel.startFueling(data.entity)
			end,
			icon = "fas fa-gas-pump",
			label = locale('start_fueling'),
			canInteract = function(entity)
				if state.isFueling or cache.vehicle or lib.progressActive() or not DoesVehicleUseFuel(entity) then
					return false
				end
				return state.petrolCan and config.petrolCan.enabled
			end
		}
	})
end
