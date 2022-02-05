if ox.inventory then
    local ox_inventory = exports.ox_inventory
    local cooldowns = {}

    local function isNearUnit(id, unitType)
        assert(type(id) == "number", "ID isn't number.")
        if(cooldowns[id]) then
            return false
        else
            cooldowns[id] = true
            SetTimeout(2000, function() cooldowns[id] = nil end)
        end
        local ped = GetPlayerPed(id)
        local coords = GetEntityCoords(ped)
        local unitDist = 15000.0
        local comparValue = 0.0
        for k,v in pairs((unitType == "stations") and stations or pumps) do
            local dist = #(coords - ((unitType == "stations") and v.coords or v))
            if(unitType == "stations") then
                comparValue = (v.length >= v.width) and v.length or v.width
            else
                comparValue = 15.0 -- optimal for avg. pump model size
            end
            if(dist < unitDist) then unitDist = dist end
        end
        return (unitDist <= comparValue) and true or false
    end

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
        if not isNearUnit(source, "stations") then return false end

        local money = ox_inventory:GetItem(source, 'money', false, true)

        if not isMoneyEnough(money, price) then return false end

        ox_inventory:RemoveItem(source, 'money', price)
        TriggerClientEvent('ox_inventory:notify', source, {
            type = 'success',
            text = ('Paid %s'):format(price)
        })
    end)

    RegisterNetEvent('ox_fuel:fuelCan', function(hasCan, price)
        local money = ox_inventory:GetItem(source, 'money', false, true)

        if not isMoneyEnough(money, price) then return false end
        if not isNearUnit(source, "pumps") then return false end

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
