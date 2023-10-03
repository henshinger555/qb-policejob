-- Variables
local currentGarage = 0
local inFingerprint = false
local FingerPrintSessionId = nil
local inStash = false
local inTrash = false
local inArmoury = false
local inHelicopter = false
local inImpound = false
local inGarage = false

local function loadAnimDict(dict) -- interactions, job,
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

local function GetClosestPlayer() -- interactions, job, tracker
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

local function openFingerprintUI()
    SendNUIMessage({
        type = "fingerprintOpen"
    })
    inFingerprint = true
    SetNuiFocus(true, true)
end

function TakeOutImpound(vehicle)
    print("take out of impound")

    local garage = Config.Locations["impound"][currentGarage]

    print(json.encode(garage, {indent=true}))
   
    local coords = Config.Locations["impound"][currentGarage].exit
    

    print(coords)
    if coords then
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            QBCore.Functions.TriggerCallback('qb-garage:server:GetVehicleProperties', function(properties)
                QBCore.Functions.SetVehicleProperties(veh, properties)
                SetVehicleNumberPlateText(veh, vehicle.plate)
		        SetVehicleDirtLevel(veh, 0.0)
                SetEntityHeading(veh, coords.w)
                exports['LegacyFuel']:SetFuel(veh, vehicle.fuel)
                doCarDamage(veh, vehicle)
                TriggerServerEvent('police:server:TakeOutImpound', vehicle.plate, currentGarage)
                closeMenuFull()
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                SetVehicleEngineOn(veh, true, true)
            end, vehicle.plate)
        end, vehicle.vehicle, coords, true)
    end
end

function IsArmoryWhitelist() -- being removed
    local retval = false

    if HasPoliceJob(QBCore.Functions.GetPlayerData().job.name) then
        retval = true
    end
    return retval
end

local function SetWeaponSeries()
    for k, _ in pairs(Config.Items.items) do
        if k < 6 then
            Config.Items.items[k].info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        end
    end
end



function MenuImpound(currentSelection)
    local impoundMenu = {
        {
            header = Lang:t('menu.impound'),
            isMenuHeader = true
        }
    }
    QBCore.Functions.TriggerCallback("police:GetImpoundedVehicles", function(result)
        local shouldContinue = false
        if result == nil then
            QBCore.Functions.Notify(Lang:t("error.no_impound"), "error", 5000)
        else
            shouldContinue = true
            for _ , v in pairs(result) do
                local enginePercent = QBCore.Shared.Round(v.engine / 10, 0)
                local currentFuel = v.fuel
                local vname = QBCore.Shared.Vehicles[v.vehicle].name

                impoundMenu[#impoundMenu+1] = {
                    header = vname.." ["..v.plate.."]",
                    txt =  Lang:t('info.vehicle_info', {value = enginePercent, value2 = currentFuel}),
                    params = {
                        event = "police:client:TakeOutImpound",
                        args = {
                            vehicle = v,
                            currentSelection = currentSelection
                        }
                    }
                }
            end
        end


        if shouldContinue then
            impoundMenu[#impoundMenu+1] = {
                header = Lang:t('menu.close'),
                txt = "",
                params = {
                    event = "qb-menu:client:closeMenu"
                }
            }
            exports['qb-menu']:openMenu(impoundMenu)
        end
    end)

end

function closeMenuFull()
    exports['qb-menu']:closeMenu()
end

--NUI Callbacks
RegisterNUICallback('closeFingerprint', function(_, cb)
    SetNuiFocus(false, false)
    inFingerprint = false
    cb('ok')
end)

--Events
RegisterNetEvent('police:client:showFingerprint', function(playerId)
    openFingerprintUI()
    FingerPrintSessionId = playerId
end)

RegisterNetEvent('police:client:showFingerprintId', function(fid)
    SendNUIMessage({
        type = "updateFingerprintId",
        fingerprintId = fid
    })
    PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
end)

RegisterNUICallback('doFingerScan', function(_, cb)
    TriggerServerEvent('police:server:showFingerprintId', FingerPrintSessionId)
    cb("ok")
end)

RegisterNetEvent('police:client:SendEmergencyMessage', function(coords, message)
    TriggerServerEvent("police:server:SendEmergencyMessage", coords, message)
    TriggerEvent("police:client:CallAnim")
end)

RegisterNetEvent('police:client:EmergencySound', function()
    PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
end)

RegisterNetEvent('police:client:CallAnim', function()
    local isCalling = true
    local callCount = 5
    loadAnimDict("cellphone@")
    TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 3.0, -1, -1, 49, 0, false, false, false)
    Wait(1000)
    CreateThread(function()
        while isCalling do
            Wait(1000)
            callCount = callCount - 1
            if callCount <= 0 then
                isCalling = false
                StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 1.0)
            end
        end
    end)
end)

RegisterNetEvent('police:client:ImpoundVehicle', function(fullImpound, price)
    local vehicle = QBCore.Functions.GetClosestVehicle()
    local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
    local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
    local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
    if vehicle ~= 0 and vehicle then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehpos = GetEntityCoords(vehicle)
        if #(pos - vehpos) < 5.0 and not IsPedInAnyVehicle(ped) then
           QBCore.Functions.Progressbar('impound', Lang:t('progressbar.impound'), 5000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = 'missheistdockssetup1clipboard@base',
                anim = 'base',
                flags = 1,
            }, {
                model = 'prop_notepad_01',
                bone = 18905,
                coords = { x = 0.1, y = 0.02, z = 0.05 },
                rotation = { x = 10.0, y = 0.0, z = 0.0 },
            },{
                model = 'prop_pencil_01',
                bone = 58866,
                coords = { x = 0.11, y = -0.02, z = 0.001 },
                rotation = { x = -120.0, y = 0.0, z = 0.0 },
            }, function() -- Play When Done
                local plate = QBCore.Functions.GetPlate(vehicle)
                TriggerServerEvent("police:server:Impound", plate, fullImpound, price, bodyDamage, engineDamage, totalFuel)
                while NetworkGetEntityOwner(vehicle) ~= 128 do  -- Ensure we have entity ownership to prevent inconsistent vehicle deletion
                    NetworkRequestControlOfEntity(vehicle)
                    Wait(100)
                end
                QBCore.Functions.DeleteVehicle(vehicle)
                TriggerEvent('QBCore:Notify', Lang:t('success.impounded'), 'success')
                ClearPedTasks(ped)
            end, function() -- Play When Cancel
                ClearPedTasks(ped)
                TriggerEvent('QBCore:Notify', Lang:t('error.canceled'), 'error')
            end)
        end
    end
end)

RegisterNetEvent('police:client:CheckStatus', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if HasPoliceJob(PlayerData.job.name) then
            local player, distance = GetClosestPlayer()
            if player ~= -1 and distance < 5.0 then
                local playerId = GetPlayerServerId(player)
                QBCore.Functions.TriggerCallback('police:GetPlayerStatus', function(result)
                    if result then
                        for _, v in pairs(result) do
                            QBCore.Functions.Notify(''..v..'')
                        end
                    end
                end, playerId)
            else
                QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
            end
        end
    end)
end)




RegisterNetEvent("police:client:ImpoundMenuHeader", function (data)

    local currentSelection = data.currentSelection

    if data.currentSelection == nil then
        currentSelection = data.args.currentSelection
    end

    MenuImpound(currentSelection)
    currentGarage = currentSelection
end)

RegisterNetEvent('police:client:TakeOutImpound', function(data)
    if inImpound or Config.UseTarget then
        local vehicle = data.vehicle
        TakeOutImpound(vehicle)
    end
end)



RegisterNetEvent('police:client:EvidenceStashDrawer', function(data)

    local currentEvidence = data.currentEvidence

    if data.currentEvidence == nil then
        currentEvidence = data.args.currentEvidence
    end

    local pos = GetEntityCoords(PlayerPedId())
    local takeLoc = Config.Locations["evidence"][currentEvidence].coords

    if not takeLoc then return end

    if #(pos - takeLoc) <= 2.0 then
        local drawer = exports['qb-input']:ShowInput({
            header = Lang:t('info.evidence_stash', {value = currentEvidence}),
            submitText = "open",
            inputs = {
                {
                    type = 'number',
                    isRequired = true,
                    name = 'slot',
                    text = Lang:t('info.slot')
                }
            }
        })
        if drawer then
            if not drawer.slot then return end
            TriggerServerEvent("inventory:server:OpenInventory", "stash", Lang:t('info.current_evidence', {value = currentEvidence, value2 = drawer.slot}), {
                maxweight = 4000000,
                slots = 500,
            })
            TriggerEvent("inventory:client:SetCurrentStash", Lang:t('info.current_evidence', {value = currentEvidence, value2 = drawer.slot}))
        end
    else
        exports['qb-menu']:closeMenu()
    end
end)

RegisterNetEvent('qb-policejob:ToggleDuty', function()
    TriggerServerEvent("QBCore:ToggleDuty")
    TriggerServerEvent("police:server:UpdateCurrentCops")
    TriggerServerEvent("police:server:UpdateBlips")
end)

RegisterNetEvent('qb-police:client:scanFingerPrint', function()
    local player, distance = GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent("police:server:showFingerprint", playerId)
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('qb-police:client:openArmoury', function()
    local authorizedItems = {
        label = Config.Items.label,
        slots = Config.Items.slots,
        items = {}
    }
    local index = 1
    for _, armoryItem in pairs(Config.Items.items) do
        for i=1, #armoryItem.authorizedJobGrades do
            if armoryItem.authorizedJobGrades[i] == PlayerJob.grade.level then
                authorizedItems.items[index] = armoryItem
                authorizedItems.items[index].slot = index
                index = index + 1
            end
        end
    end
    SetWeaponSeries()
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "police", authorizedItems)
end)

RegisterNetEvent("qb-police:client:openStash", function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policestash_"..QBCore.Functions.GetPlayerData().citizenid)
    TriggerEvent("inventory:client:SetCurrentStash", "policestash_"..QBCore.Functions.GetPlayerData().citizenid)
end)

RegisterNetEvent('qb-police:client:openTrash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policetrash", {
        maxweight = 4000000,
        slots = 300,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "policetrash")
end)

RegisterNetEvent('qb-police:client:openImpound', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policetrash", {
        maxweight = 4000000,
        slots = 300,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "policetrash")
end)

--##### Threads #####--

local dutylisten = false
local function dutylistener()
    dutylisten = true
    CreateThread(function()
        while dutylisten do
            if HasPoliceJob(PlayerJob.name) then
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent("QBCore:ToggleDuty")
                    TriggerServerEvent("police:server:UpdateCurrentCops")
                    TriggerServerEvent("police:server:UpdateBlips")
                    dutylisten = false
                    break
                end
            else
                break
            end
            Wait(0)
        end
    end)
end

-- Personal Stash Thread
local function stash()
    CreateThread(function()
        while true do
            Wait(0)
            if inStash and HasPoliceJob(PlayerJob.name) then
                if PlayerJob.onduty then sleep = 5 end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policestash_"..QBCore.Functions.GetPlayerData().citizenid)
                    TriggerEvent("inventory:client:SetCurrentStash", "policestash_"..QBCore.Functions.GetPlayerData().citizenid)
                    break
                end
            else
                break
            end
        end
    end)
end

-- Police Trash Thread
local function trash()
    CreateThread(function()
        while true do
            Wait(0)
            if inTrash and HasPoliceJob(PlayerJob.name) then
                if PlayerJob.onduty then sleep = 5 end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policetrash", {
                        maxweight = 4000000,
                        slots = 300,
                    })
                    TriggerEvent("inventory:client:SetCurrentStash", "policetrash")
                    break
                end
            else
                break
            end
        end
    end)
end

-- Fingerprint Thread
local function fingerprint()
    CreateThread(function()
        while true do
            Wait(0)
            if inFingerprint and HasPoliceJob(PlayerJob.name) then
                if PlayerJob.onduty then sleep = 5 end
                if IsControlJustReleased(0, 38) then
                    TriggerEvent("qb-police:client:scanFingerPrint")
                    break
                end
            else
                break
            end
        end
    end)
end

-- Armoury Thread
local function armoury()
    CreateThread(function()
        while true do
            Wait(0)
            if inArmoury and HasPoliceJob(PlayerJob.name) then
                if PlayerJob.onduty then sleep = 5 end
                if IsControlJustReleased(0, 38) then
                    TriggerEvent("qb-police:client:openArmoury")
                    break
                end
            else
                break
            end
        end
    end)
end

-- Police Impound Thread
local function impound()
    CreateThread(function()
        while true do
            Wait(0)
            if inImpound and HasPoliceJob(PlayerJob.name) then
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


if Config.UseTarget then

    targetJobs = BuildJobTargetTable()
    
    CreateThread(function()
        -- Toggle Duty
        for k, duty in pairs(Config.Locations["duty"]) do
            exports['qb-target']:AddBoxZone("PoliceDuty_"..k, duty.coords, duty.zoneLength, duty.zoneWidth, {
                name = "PoliceDuty_"..k,
                heading = duty.heading,
                debugPoly = Config.DebugZone,
                minZ = duty.coords.z - duty.zoneMinZ,
                maxZ = duty.coords.z + duty.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "qb-policejob:ToggleDuty",
                        icon = "fas fa-sign-in-alt",
                        label = "Sign In",
                        job = targetJobs,
                    },
                },
                distance = 1.5
            })
        end

        -- Personal Stash
        for k, stash in pairs(Config.Locations["stash"]) do
            exports['qb-target']:AddBoxZone("PoliceStash_"..k, stash.coords, stash.zoneLength, stash.zoneWidth, {
                name = "PoliceStash_"..k,
                heading = stash.heading,
                debugPoly = Config.DebugZone,
                minZ = stash.coords.z - stash.zoneMinZ,
                maxZ = stash.coords.z + stash.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "qb-police:client:openStash",
                        icon = "fas fa-dungeon",
                        label = "Open Personal Stash",
                        job = targetJobs,
                    },
                },
                distance = 1.5
            })
        end

        -- Police Trash
        for k, trash in pairs(Config.Locations["trash"]) do
            exports['qb-target']:AddBoxZone("PoliceTrash_"..k, trash.coords, trash.zoneLength, trash.zoneWidth, {
                name = "PoliceTrash_"..k,
                heading = trash.heading,
                debugPoly = Config.DebugZone,
                minZ = trash.coords.z - trash.zoneMinZ,
                maxZ = trash.coords.z + trash.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "qb-police:client:openTrash",
                        icon = "fas fa-trash",
                        label = "Open Trash",
                        job = targetJobs,
                    },
                },
                distance = 1.5
            })
        end

        -- Fingerprint
        for k, fingerprint in pairs(Config.Locations["fingerprint"]) do
            exports['qb-target']:AddBoxZone("PoliceFingerprint_"..k, fingerprint.coords, fingerprint.zoneLength, fingerprint.zoneWidth, {
                name = "PoliceFingerprint_"..k,
                heading = fingerprint.heading,
                debugPoly = Config.DebugZone,
                minZ = fingerprint.coords.z - fingerprint.zoneMinZ,
                maxZ = fingerprint.coords.z + fingerprint.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "qb-police:client:scanFingerPrint",
                        icon = "fas fa-fingerprint",
                        label = "Open Fingerprint",
                        job = targetJobs,
                    },
                },
                distance = 1.5
            })
        end

        -- Armoury
        for k, armoury in pairs(Config.Locations["armory"]) do
            exports['qb-target']:AddBoxZone("PoliceArmory_"..k, armoury.coords, armoury.zoneLength, armoury.zoneWidth, {
                name = "PoliceArmory_"..k,
                heading = armoury.heading,
                debugPoly = Config.DebugZone,
                minZ = armoury.coords.z - armoury.zoneMinZ,
                maxZ = armoury.coords.z + armoury.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "qb-police:client:openArmoury",
                        icon = "fas fa-swords",
                        label = "Open Armory",
                        job = targetJobs,
                    },
                },
                distance = 1.5
            })
        end

        -- PD Impound
        for k, impound in pairs(Config.Locations["impound"]) do
            currentSelection = k
            exports['qb-target']:AddBoxZone("PoliceImpound_"..k, impound.coords, impound.zoneLength, impound.zoneWidth, {
                name = "PoliceImpound_"..k,
                heading = impound.heading,
                debugPoly = Config.DebugZone,
                minZ = impound.coords.z - impound.zoneMinZ,
                maxZ = impound.coords.z + impound.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "police:client:ImpoundMenuHeader",
                        icon = "fas fa-swords",
                        label = "Open Impound",
                        job = targetJobs,
                        args = {
                            currentSelection = currentSelection,
                        }
                    },
                },
                distance = 1.5
            })
        end

        -- PD Evidence
        for k, evidence in pairs(Config.Locations["evidence"]) do
            currentSelection = k
            exports['qb-target']:AddBoxZone("PoliceEvidence_"..k, evidence.coords, evidence.zoneLength, evidence.zoneWidth, {
                name = "PoliceEvidence_"..k,
                heading = evidence.heading,
                debugPoly = Config.DebugZone,
                minZ = evidence.coords.z - evidence.zoneMinZ,
                maxZ = evidence.coords.z + evidence.zoneMinZ,
            }, {
                options = {
                    {
                        type = "client",
                        event = "police:client:EvidenceStashDrawer",
                        icon = "fas fa-swords",
                        label = "Open Evidence",
                        job = targetJobs,
                        args = {
                            currentEvidence = currentSelection,
                        }
                    },
                },
                distance = 2
            })
        end

    end)

else

    -- Toggle Duty
    local dutyZones = {}
    for _, duty in pairs(Config.Locations["duty"]) do
        dutyZones[#dutyZones+1] = BoxZone:Create(
            duty.coords, duty.zoneLength, duty.zoneWidth, {
            name="box_zone",
            debugPoly = Config.DebugZone,
            minZ = duty.coords.z - duty.zoneMinZ,
            maxZ = duty.coords.z + duty.zoneMinZ,
        })
    end

    local dutyCombo = ComboZone:Create(dutyZones, {name = "dutyCombo", debugPoly = false})
    dutyCombo:onPlayerInOut(function(isPointInside)
        if isPointInside then
            dutylisten = true
            if not PlayerJob.onduty then
                exports['qb-core']:DrawText(Lang:t('info.on_duty'),'left')
                dutylistener()
            else
                exports['qb-core']:DrawText(Lang:t('info.off_duty'),'left')
                dutylistener()
            end
        else
            dutylisten = false
            exports['qb-core']:HideText()
        end
    end)

    -- Personal Stash
    local stashZones = {}
    for _, stash in pairs(Config.Locations["stash"]) do
        stashZones[#stashZones+1] = BoxZone:Create(
            stash.coords, stash.zoneLength, stash.zoneWidth, {
            name="box_zone",
            debugPoly = Config.DebugZone,
            minZ = stash.coords.z - stash.zoneMinZ,
            maxZ = stash.coords.z + stash.zoneMinZ
        })
    end

    local stashCombo = ComboZone:Create(stashZones, {name = "stashCombo", debugPoly = false})
    stashCombo:onPlayerInOut(function(isPointInside, _, _)
        if isPointInside then
            inStash = true
            if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                exports['qb-core']:DrawText(Lang:t('info.stash_enter'), 'left')
                stash()
            end
        else
            inStash = false
            exports['qb-core']:HideText()
        end
    end)

    -- Police Trash
    local trashZones = {}
    for _, trash in pairs(Config.Locations["trash"]) do
        trashZones[#trashZones+1] = BoxZone:Create(
            trash.coords, trash.zoneLength, trash.zoneWidth, {
            name="box_zone",
            debugPoly = Config.DebugZone,
            minZ = v.z - 1,
            maxZ = v.z + 1,
        })
    end

    local trashCombo = ComboZone:Create(trashZones, {name = "trashCombo", debugPoly = false})
    trashCombo:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inTrash = true
            if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                exports['qb-core']:DrawText(Lang:t('info.trash_enter'),'left')
                trash()
            end
        else
            inTrash = false
            exports['qb-core']:HideText()
        end
    end)

    -- Fingerprints
    local fingerprintZones = {}
    for _, fingerprint in pairs(Config.Locations["fingerprint"]) do
        fingerprintZones[#fingerprintZones+1] = BoxZone:Create(
            fingerprint.coords, fingerprint.zoneLength, fingerprint.zoneWidth, {
            name="box_zone",
            debugPoly = Config.DebugZone,
            minZ = fingerprint.coords - fingerprint.zoneMinZ,
            maxZ = fingerprint.coords + fingerprint.zoneMinZ,
        })
    end

    local fingerprintCombo = ComboZone:Create(fingerprintZones, {name = "fingerprintCombo", debugPoly = false})
    fingerprintCombo:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inFingerprint = true
            if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                exports['qb-core']:DrawText(Lang:t('info.scan_fingerprint'),'left')
                fingerprint()
            end
        else
            inFingerprint = false
            exports['qb-core']:HideText()
        end
    end)

    -- Armoury
    local armouryZones = {}
    for _, v in pairs(Config.Locations["armory"]) do
        armouryZones[#armouryZones+1] = BoxZone:Create(
            vector3(vector3(v.x, v.y, v.z)), 5, 1, {
            name="box_zone",
            debugPoly = Config.DebugZone,
            minZ = v.z - 1,
            maxZ = v.z + 1,
        })
    end

    local armouryCombo = ComboZone:Create(armouryZones, {name = "armouryCombo", debugPoly = false})
    armouryCombo:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inArmoury = true
            if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                exports['qb-core']:DrawText(Lang:t('info.enter_armory'),'left')
                armoury()
            end
        else
            inArmoury = false
            exports['qb-core']:HideText()
        end
    end)

    -- Police Impound
    local impoundZones = {}
    for _, impound in pairs(Config.Locations["impound"]) do
        impoundZones[#impoundZones+1] = BoxZone:Create(
            impound.coords, impound.zoneLength, impound.zoneWidth, {
            name="box_zone",
            debugPoly = false,
            minZ = impound.coords.z - impound.zoneMinZ,
            maxZ = impound.coords.z + impound.zoneMinZ,
            heading =c.heading,
        })
    end

    local impoundCombo = ComboZone:Create(impoundZones, {name = "impoundCombo", debugPoly = false})
    impoundCombo:onPlayerInOut(function(isPointInside, point)
        if isPointInside then
            inImpound = true
            if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    exports['qb-core']:DrawText(Lang:t('info.impound_veh'), 'left')
                    impound()
                else
                    local currentSelection = 0

                    for k, v in pairs(Config.Locations["impound"]) do
                        if #(point - vector3(v.coords.x, v.coords.y, v.coords.z)) < 4 then
                            currentSelection = k
                        end
                    end
                    exports['qb-menu']:showHeader({
                        {
                            header = Lang:t('menu.pol_impound'),
                            params = {
                                event = 'police:client:ImpoundMenuHeader',
                                args = {
                                    currentSelection = currentSelection,
                                }
                            }
                        }
                    })
                end
            end
        else
            inImpound = false
            exports['qb-menu']:closeMenu()
            exports['qb-core']:HideText()
        end
    end)

        -- Evidence Storage
        local evidenceZones = {}
        for _, evidence in pairs(Config.Locations["evidence"]) do
            evidenceZones[#evidenceZones+1] = BoxZone:Create(
                evidence.coords, evidence.zoneLength, evidence.zoneWidth, {
                name="box_zone",
                debugPoly = Config.DebugZone,
                minZ = evidence.coords.z - evidence.zoneMinZ,
                maxZ = evidence.coords.z + evidence.zoneMinZ,
            })
        end
    
        local evidenceCombo = ComboZone:Create(evidenceZones, {name = "evidenceCombo", debugPoly = false})
        evidenceCombo:onPlayerInOut(function(isPointInside)
            if isPointInside then
                if HasPoliceJob(PlayerJob.name) and PlayerJob.onduty then
                    local currentEvidence = 0
                    local pos = GetEntityCoords(PlayerPedId())
    
                    for k, v in pairs(Config.Locations["evidence"]) do
                        if #(pos - v) < 2 then
                            currentEvidence = k
                        end
                    end
                    exports['qb-menu']:showHeader({
                        {
                            header = Lang:t('info.evidence_stash', {value = currentEvidence}),
                            params = {
                                event = 'police:client:EvidenceStashDrawer',
                                args = {
                                    currentEvidence = currentEvidence
                                }
                            }
                        }
                    })
                end
            else
                exports['qb-menu']:closeMenu()
            end
        end)

end
