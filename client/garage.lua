local currentGarage = 0
local inGarage = false

RegisterNetEvent("police:client:VehicleMenuHeader", function (data)
    MenuGarage(data.currentSelection)
    currentGarage = data.currentSelection
end)

RegisterNetEvent('police:client:TakeOutVehicle', function(data)
    if inGarage then
        local vehicle = data.vehicle
        TakeOutVehicle(vehicle)
    end
end)

local function SetCarItemsInfo()
	local items = {}
	for _, item in pairs(Config.CarItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		items[item.slot] = {
			name = itemInfo["name"],
			amount = tonumber(item.amount),
			info = item.info,
			label = itemInfo["label"],
			description = itemInfo["description"] and itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = item.slot,
		}
	end
	Config.CarItems = items
end

function doCarDamage(currentVehicle, veh)
	local smash = false
	local damageOutside = false
	local damageOutside2 = false
	local engine = veh.engine + 0.0
	local body = veh.body + 0.0

	if engine < 200.0 then engine = 200.0 end
    if engine  > 1000.0 then engine = 950.0 end
	if body < 150.0 then body = 150.0 end
	if body < 950.0 then smash = true end
	if body < 920.0 then damageOutside = true end
	if body < 920.0 then damageOutside2 = true end

    Wait(100)
    SetVehicleEngineHealth(currentVehicle, engine)

	if smash then
		SmashVehicleWindow(currentVehicle, 0)
		SmashVehicleWindow(currentVehicle, 1)
		SmashVehicleWindow(currentVehicle, 2)
		SmashVehicleWindow(currentVehicle, 3)
		SmashVehicleWindow(currentVehicle, 4)
	end

	if damageOutside then
		SetVehicleDoorBroken(currentVehicle, 1, true)
		SetVehicleDoorBroken(currentVehicle, 6, true)
		SetVehicleDoorBroken(currentVehicle, 4, true)
	end

	if damageOutside2 then
		SetVehicleTyreBurst(currentVehicle, 1, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 2, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 3, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 4, false, 990.0)
	end

	if body < 1000 then
		SetVehicleBodyHealth(currentVehicle, 985.1)
	end
end

function TakeOutVehicle(vehicleInfo)
    local coords = Config.Locations["vehicle"][currentGarage]
    if coords then
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            SetCarItemsInfo()
            SetVehicleNumberPlateText(veh, Lang:t('info.police_plate')..tostring(math.random(1000, 9999)))
            SetEntityHeading(veh, coords.w)
            exports['LegacyFuel']:SetFuel(veh, 100.0)
            closeMenuFull()
            if Config.VehicleSettings[vehicleInfo] ~= nil then
                if Config.VehicleSettings[vehicleInfo].extras ~= nil then
			QBCore.Shared.SetDefaultVehicleExtras(veh, Config.VehicleSettings[vehicleInfo].extras)
		end
		if Config.VehicleSettings[vehicleInfo].livery ~= nil then
			SetVehicleLivery(veh, Config.VehicleSettings[vehicleInfo].livery)
		end
            end
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
            TriggerServerEvent("inventory:server:addTrunkItems", QBCore.Functions.GetPlate(veh), Config.CarItems)
            SetVehicleEngineOn(veh, true, true)
        end, vehicleInfo, coords, true)
    end
end


function MenuGarage(currentSelection)
    local vehicleMenu = {
        {
            header = Lang:t('menu.garage_title'),
            isMenuHeader = true
        }
    }

    print(QBCore.Functions.GetPlayerData().job.grade.level)

    local authorizedVehicles = Config.AuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level]

    if authorizedVehicles == nil then 
    else
      for veh, label in pairs(authorizedVehicles) do
          vehicleMenu[#vehicleMenu+1] = {
              header = label,
              txt = "",
              params = {
                  event = "police:client:TakeOutVehicle",
                  args = {
                      vehicle = veh,
                      currentSelection = currentSelection
                  }
              }
          }
        end
    end

    if IsArmoryWhitelist() then
        for veh, label in pairs(Config.WhitelistedVehicles) do
            vehicleMenu[#vehicleMenu+1] = {
                header = label,
                txt = "",
                params = {
                    event = "police:client:TakeOutVehicle",
                    args = {
                        vehicle = veh,
                        currentSelection = currentSelection
                    }
                }
            }
        end
    end

    vehicleMenu[#vehicleMenu+1] = {
        header = Lang:t('menu.close'),
        txt = "",
        params = {
            event = "qb-menu:client:closeMenu"
        }

    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

-- Police Garage Thread
local function garage()
    CreateThread(function()
        while true do
            Wait(0)
            if inGarage and HasPoliceJob(PlayerJob.name) then
                if PlayerJob.onduty then sleep = 5 end
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    if IsControlJustReleased(0, 38) then
                        QBCore.Functions.DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
                        break
                    end
                end
            else
                break
            end
        end
    end)
end


if Config.UseGarageSystem then 
    CreateThread(function()

        -- Police Garage
        local garageZones = {}
        for _, v in pairs(Config.Locations["vehicle"]) do
            garageZones[#garageZones+1] = BoxZone:Create(
                vector3(v.x, v.y, v.z), 3, 3, {
                name="box_zone",
                debugPoly = Config.DebugZone,
                minZ = v.z - 1,
                maxZ = v.z + 1,
            })
        end

        local garageCombo = ComboZone:Create(garageZones, {name = "garageCombo", debugPoly = false})
        garageCombo:onPlayerInOut(function(isPointInside, point)
            if isPointInside then
                inGarage = true
                if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                    if IsPedInAnyVehicle(PlayerPedId(), false) then
                        exports['qb-core']:DrawText(Lang:t('info.store_veh'), 'left')
		                garage()
                    else
                        local currentSelection = 0

                        for k, v in pairs(Config.Locations["vehicle"]) do
                            if #(point - vector3(v.x, v.y, v.z)) < 4 then
                                currentSelection = k
                            end
                        end
                        exports['qb-menu']:showHeader({
                            {
                                header = Lang:t('menu.pol_garage'),
                                params = {
                                    event = 'police:client:VehicleMenuHeader',
                                    args = {
                                        currentSelection = currentSelection,
                                    }
                                }
                            }
                        })
                    end
                end
            else
                inGarage = false
                exports['qb-menu']:closeMenu()
                exports['qb-core']:HideText()
            end
        end)
    end)
end 