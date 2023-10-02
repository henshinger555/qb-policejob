local Plates = {}
local QBCore = exports['qb-core']:GetCoreObject()

if Config.ANPR_Enable then 
QBCore.Commands.Add("flagplate", Lang:t("commands.flagplate"), {{name = "plate", help = Lang:t('info.plate_number')}, {name = "reason", help = Lang:t('info.flag_reason')}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if HasPoliceJob(Player.PlayerData.job.name) and Player.PlayerData.job.onduty then
        local reason = {}
        for i = 2, #args, 1 do
            reason[#reason+1] = args[i]
        end
        Plates[args[1]:upper()] = {
            isflagged = true,
            reason = table.concat(reason, " ")
        }
        TriggerClientEvent('QBCore:Notify', src, Lang:t("info.vehicle_flagged", {vehicle = args[1]:upper(), reason = table.concat(reason, " ")}))
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.on_duty_police_only"), 'error')
    end
end)

QBCore.Commands.Add("unflagplate", Lang:t("commands.unflagplate"), {{name = "plate", help = Lang:t('info.plate_number')}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if HasPoliceJob(Player.PlayerData.job.name) and Player.PlayerData.job.onduty then
        if Plates and Plates[args[1]:upper()] then
            if Plates[args[1]:upper()].isflagged then
                Plates[args[1]:upper()].isflagged = false
                TriggerClientEvent('QBCore:Notify', src, Lang:t("info.unflag_vehicle", {vehicle = args[1]:upper()}))
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.vehicle_not_flag"), 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.vehicle_not_flag"), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.on_duty_police_only"), 'error')
    end
end)

QBCore.Commands.Add("plateinfo", Lang:t("commands.plateinfo"), {{name = "plate", help = Lang:t('info.plate_number')}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if HasPoliceJob(Player.PlayerData.job.name) and Player.PlayerData.job.onduty then
        if Plates and Plates[args[1]:upper()] then
            if Plates[args[1]:upper()].isflagged then
                TriggerClientEvent('QBCore:Notify', src, Lang:t('success.vehicle_flagged', {plate = args[1]:upper(), reason = Plates[args[1]:upper()].reason}), 'success')
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.vehicle_not_flag"), 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.vehicle_not_flag"), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.on_duty_police_only"), 'error')
    end
end)

end

QBCore.Functions.CreateCallback('police:IsPlateFlagged', function(_, cb, plate)
    print("police:IsPlateFlagged")
    local retval = false
    if Plates and Plates[plate] then
        if Plates[plate].isflagged then
            retval = true
        end
    end
    cb(retval)
end)

RegisterNetEvent('police:server:FlaggedPlateTriggered', function(camId, plate, street1, street2, blipSettings)
  
     local src = source
     for k, v in pairs(QBCore.Functions.GetPlayers()) do
         local Player = QBCore.Functions.GetPlayer(v)
         if Player then
             if (HasPoliceJob(Player.PlayerData.job.name) and Player.PlayerData.job.onduty) then

                 if street2 then
                     TriggerClientEvent("112:client:SendPoliceAlert", v, "flagged", {
                         camId = camId,
                         plate = plate,
                         streetLabel = street1 .. " " .. street2
                     }, blipSettings)
                 else
                     TriggerClientEvent("112:client:SendPoliceAlert", v, "flagged", {
                         camId = camId,
                         plate = plate,
                         streetLabel = street1
                     }, blipSettings)
                 end
                 
             end
         end
     end
end)