lib.locale()

if Config.versionCheck then lib.versionCheck('overextended/ox_fuel') end

local ox_inventory = exports.ox_inventory

local function isMoneyEnough(money, price)
	if money < price then
		local missingMoney = price - money
		TriggerClientEvent('ox_lib:notify', source, {
			type = 'error',
			description = locale('not_enough_money', missingMoney)
		})
		return false
	else
		return true
	end
end

RegisterNetEvent('ox_fuel:pay', function(price, fuel)
	assert(type(price) == 'number', ('Price expected a number, received %s'):format(type(price)))

	ox_inventory:RemoveItem(source, 'money', price)

	fuel = math.floor(fuel)
	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale('fuel_success', fuel, price)
	})
end)

RegisterNetEvent('ox_fuel:fuelCan', function(hasCan, price)
	local money = ox_inventory:GetItem(source, 'money', false, true)

	if not isMoneyEnough(money, price) then return false end

	if hasCan then
		local item = ox_inventory:Search(source, 'slots', 'WEAPON_PETROLCAN')
		if item then
			item = item[1]
			item.metadata.durability = 100
			item.metadata.ammo = 100

			ox_inventory:SetMetadata(source, item.slot, item.metadata)
			ox_inventory:RemoveItem(source, 'money', price)
			TriggerClientEvent('ox_lib:notify', source, {
				type = 'success',
				description = locale('petrolcan_refill', price)
			})
		end
	else
		local petrolCan = exports.ox_inventory:GetItem(source, 'WEAPON_PETROLCAN', false, true)

		if petrolCan == 0 then
			local canCarry = ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1)

			if not canCarry then 
				return TriggerClientEvent('ox_lib:notify', source, {
					type = 'error',
					description = locale('petrolcan_cannot_carry')
				})
			end

			ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

			ox_inventory:RemoveItem(source, 'money', price)
			TriggerClientEvent('ox_lib:notify', source, {
				type = 'success',
				description = locale('petrolcan_buy', price)
			})
		else
			-- manually triggered event, cheating?
		end
	end
end)

RegisterNetEvent('ox_fuel:UpdateCanDurability', function(fuelingCan, durability)
	durability = math.floor(durability)
	fuelingCan.metadata.durability = durability
	fuelingCan.metadata.ammo = durability
	exports.ox_inventory:SetMetadata(source, fuelingCan.slot, fuelingCan.metadata)
end)

RegisterNetEvent('ox_fuel:createStatebag', function(netid, fuel)
	local vehicle = NetworkGetEntityFromNetworkId(netid)
	local state = vehicle and Entity(vehicle).state

	if state and not state.fuel and GetEntityType(vehicle) == 2 and NetworkGetEntityOwner(vehicle) == source then
		state:set('fuel', fuel > 100 and 100 or fuel, true)
	end
end)
