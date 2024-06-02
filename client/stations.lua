local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'

CreateThread(function()
	local stations = lib.load 'data.stations'

	if config.showBlips == 2 then
		for station in pairs(stations) do utils.createBlip(station) end
	end

	local blip

	if config.ox_target and config.showBlips ~= 1 then return end

	while true do
		local playerCoords = GetEntityCoords(cache.ped)

		for station, pumps in pairs(stations) do
			local stationDistance = #(playerCoords - station)

			if stationDistance < 60 then
				if config.showBlips == 1 and not blip then
					blip = utils.createBlip(station)
				end

				if not config.ox_target then
					repeat
						if stationDistance < 15 then
							local pumpDistance

							repeat
								playerCoords = GetEntityCoords(cache.ped)
								for i = 1, #pumps do
									local pump = pumps[i]
									pumpDistance = #(playerCoords - pump)

									if pumpDistance < 3 then
										state.nearestPump = pump

										while pumpDistance < 3 do
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

											pumpDistance = #(GetEntityCoords(cache.ped) - pump)
											Wait(0)
										end

										state.nearestPump = nil
									end
								end
								Wait(100)
							until pumpDistance > 15
							break
						end

						Wait(100)
						stationDistance = #(GetEntityCoords(cache.ped) - station)
					until stationDistance > 60
				end
			end
		end

		Wait(500)

		if blip then
			RemoveBlip(blip)
			blip = nil
		end
	end
end)
