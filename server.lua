if ox.inventory then
    local ox_inventory = exports.ox_inventory

    RegisterNetEvent('ox_fuel:pay', function(price)
        assert(type(price) == 'number', ('Price expected a number, received %s'):format(type(price)))

        local money = ox_inventory:GetItem(source, 'money', false, true)

        if money < price then
            return TriggerClientEvent('ox_inventory:notify', source, {
                type = 'error',
                text = ('Not enough money! Missing %s'):format(price)
            })
        end

        ox_inventory:RemoveItem(source, 'money', price)
        TriggerClientEvent('ox_inventory:notify', source, {
            type = 'success',
            text = ('Paid %s'):format(price)
        })
    end)
end
