# ox_fuel

## Get vehicle fuel level
```lua
local fuel = GetVehicleFuelLevel(entity)
```
Yes, really. You can use statebags if you want.
```lua
local fuel = Entity(entity).state.fuel
```

No, we're not adding exports to do this.
