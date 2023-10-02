function HasPoliceJob(jobName)

    --print("HasPoliceJob : "..jobname)

    if Config.PoliceJobs[jobName] == nil then 
        return false
    else 
        return true
    end
end

function HasSupportJob(jobName)

    --print("HasSupportJob : "..jobname)

    if Config.SupportJobs[jobName] == nil then 
        return false
    else 
        return true
    end
end

function NotPolice(jobname)

    print("NotPolice :"..jobname)

    if Config.PoliceJobs[jobName] == nil then 
        return true
    else 
        return false
    end
end


function BuildJobTargetTable()

    --print("BuildJobTargetTable")

    policeJobs = {}

    for job, _ in pairs(Config.PoliceJobs) do

        policeJobs[job] = 0
    end

    --print(json.encode(policeJobs, {indent=true}))

    return policeJobs


end

exports('HasPoliceJob', HasPoliceJob)
exports('HasAnyPoliceJob', HasPoliceJob)
exports('HasPoliceJob', HasPoliceJob)
exports('BuildJobTargetTable', BuildJobTargetTable)