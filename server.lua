if ox.inventory then
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

    RegisterNetEvent('ox_fuel:pay', function(price)
        assert(type(price) == 'number', ('Price expected a number, received %s'):format(type(price)))

        local money = ox_inventory:GetItem(source, 'money', false, true)

        if not isMoneyEnough(money, price) then return false end

        ox_inventory:RemoveItem(source, 'money', price)
        TriggerClientEvent('ox_inventory:notify', source, {
            type = 'success',
            text = ('Paid %s'):format(price)
        })
    end)
    
    RegisterNetEvent('ox_fuel:candeduction', function(slot, amount)
	    local fuelcan = ox_inventory:Search(source, 'slots', 'WEAPON_PETROLCAN')
		for _, v in pairs(fuelcan) do
			if v.slot == slot then
				fuelcan = v
			end
		end
		if fuelcan.metadata.durability - amount < 0 then
		    fuelcan.metadata.durability = 0
		    else
		    fuelcan.metadata.durability = fuelcan.metadata.durability - amount
		end
		if fuelcan.metadata.ammo ~= nil then
		    if fuelcan.metadata.ammo - amount < 0 then
			    fuelcan.metadata.ammo = 0
			else
		        fuelcan.metadata.ammo = fuelcan.metadata.ammo - amount
		    end
		end
        exports.ox_inventory:SetMetadata(source, slot, fuelcan.metadata)
    end)

    RegisterNetEvent('ox_fuel:fuelCan', function(hasCan, price)
        local money = ox_inventory:GetItem(source, 'money', false, true)

        if not isMoneyEnough(money, price) then return false end

        if hasCan then
            ox_inventory:RemoveItem(source, 'WEAPON_PETROLCAN', 1)
            ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

            ox_inventory:RemoveItem(source, 'money', price)
            TriggerClientEvent('ox_inventory:notify', source, {
                type = 'success',
                text = ('Paid %s for refilling your fuel can'):format(price)
            })
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
                    text = ('Paid %s for buying a fuel can'):format(price)
                })
            else
                -- manually triggered event, cheating?
            end
        end
    end)
end
