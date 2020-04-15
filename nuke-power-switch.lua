on_tick = function (event)
    -- set loop to run evry x ticks
    delay = 60

    -- read in variables
    nukeSteam = rednet["steam"]
    if nukeSteam == nil then
        nukeSteam = 0
    end

    solarSteam = greennet["steam"]
    if solarSteam == nil then
        solarSteam = 0
    end

    --state 0 is switched off. Initial default
    if var["init"] == nil then
       var["state"] = 0
       var["init"] = true
    end

    if var["state"] == 0 then
        if (solarSteam < 5000 or nukeSteam < 500) then
            var["state"] = 1
        end
    else
        if (solarSteam > 6000 and nukeSteam > 5000) then
            var["state"] = 0
        end
    end

    output = {}
    output["signal-N"] = var["state"]
 end