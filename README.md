# ox_fuel

## Get vehicle fuel level
This is an incredibly complicated task for some people, and they often ask for exports to do it.  
You use the native function [GetVehicleFuelLevel](https://docs.fivem.net/natives/?_0x5F739BB8), or you can use a statebag.

```lua
local fuel = GetVehicleFuelLevel(entity)
-- or Entity(entity).state.fuel
```

## Set vehicle fuel level
```lua
Entity(entity).state.fuel = fuelAmount
```
