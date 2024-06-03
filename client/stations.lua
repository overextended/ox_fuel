local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'

if config.showBlips == 2 then
	for station in pairs(stations) do utils.createBlip(station) end
end

if config.ox_target and config.showBlips ~= 1 then return end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end
end

---@param point CPoint
local function nearbyStation(point)
	if point.currentDistance > 15 then return end

	local pumps = point.pumps
	local pumpDistance

	for i = 1, #pumps do
		local pump = pumps[i]
		pumpDistance = #(cache.coords - pump)

		if pumpDistance <= 3 then
			state.nearestPump = pump

			repeat
				local playerCoords = GetEntityCoords(cache.ped)
				pumpDistance = #(GetEntityCoords(cache.ped) - pump)

				if cache.vehicle then
					DisplayHelpTextThisFrame('fuelLeaveVehicleText', false)
				elseif not state.isFueling then
					local vehicleInRange = state.lastVehicle ~= 0 and
						#(GetEntityCoords(state.lastVehicle) - playerCoords) <= 3

					if vehicleInRange then
						DisplayHelpTextThisFrame('fuelHelpText', false)
					elseif config.petrolCan.enabled then
						DisplayHelpTextThisFrame('petrolcanHelpText', false)
					end
				end

				Wait(0)
			until pumpDistance > 3

			state.nearestPump = nil

			return
		end
	end
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end
end

for station, pumps in pairs(stations) do
	lib.points.new({
		coords = station,
		distance = 60,
		onEnter = onEnterStation,
		onExit = onExitStation,
		nearby = nearbyStation,
		pumps = pumps,
	})
end
