AddTextEntry('ox_fuel_station', locale('fuel_station_blip'))

local function createBlip(station)
	local blip = AddBlipForCoord(station.x, station.y, station.z)
	SetBlipSprite(blip, 361)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.8)
	SetBlipColour(blip, 6)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('ox_fuel_station')
	EndTextCommandSetBlipName(blip)

	return blip
end

return createBlip
