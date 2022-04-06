local ox_inventory = exports.ox_inventory

local function isMoneyEnough(money, price)
	if money < price then
		local missingMoney = price - money
		TriggerClientEvent('ox_inventory:notify', source, {
			type = 'error',
			text = ('Not enough money! Missing %s$'):format(missingMoney)
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
	TriggerClientEvent('ox_inventory:notify', source, {
		type = 'success',
		text = ('Fueled to ' .. fuel .. '% ' .. '- $' .. price)
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
			TriggerClientEvent('ox_inventory:notify', source, {
				type = 'success',
				text = ('Paid $%s for refilling your fuel can'):format(price)
			})
		end
	else
		local petrolCan = exports.ox_inventory:GetItem(source, 'WEAPON_PETROLCAN', false, true)

		if petrolCan == 0 then
			local canCarry = ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1)

			if not canCarry then 
				return TriggerClientEvent('ox_inventory:notify', source, {
					type = 'error',
					text = ('You can\'t carry anymore stuff'):format(missingMoney)
				}) 
			end

			ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

			ox_inventory:RemoveItem(source, 'money', price)
			TriggerClientEvent('ox_inventory:notify', source, {
				type = 'success',
				text = ('Paid $%s for buying a fuel can'):format(price)
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

RegisterNetEvent('ox_fuel:initFuel')
AddEventHandler('ox_fuel:initFuel', function(sentVeh)
	local veh = NetworkGetEntityFromNetworkId(sentVeh)
	if veh ~= 0 then
		Entity(veh).state.fuel = math.random(40, 60)
	end
end)

AddEventHandler('ox_fuel:setFuel', function(sentVeh, sentFuel)
	if type(sentFuel) == 'number' and sentFuel >= 0 and sentFuel <= 100 then
		if DoesEntityExist(sentVeh) then
			Entity(sentVeh).state.fuel = sentFuel
		else
			Entity(NetworkGetEntityFromNetworkId(sentVeh)).state.fuel = sentFuel
		end
	end
end)

local function GetFuel(sentVeh)
	if DoesEntityExist(sentVeh) then
		return Entity(sentVeh).state.fuel
	else
		return Entity(NetworkGetEntityFromNetworkId(sentVeh)).state.fuel
	end
end
exports('GetFuel', GetFuel)