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

RegisterNetEvent('police:server:FlaggedPlateTriggered', function(camId, plate, street1, street2, blipSettings)
  
    TriggerClientEvent("tgiann-policeAlert:alert", source, "ANPR: Plate Found", plate, street1, true)

end)