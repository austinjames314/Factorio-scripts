on_tick = function (event)
    -- set loop to run evry x ticks
    delay = 60

    -- read in variables
    charge = greennet["signal-A"]
    if charge == nil then
        charge = 0
    end

    --state 0 is switched off. Initial default
    if var["init"] == nil then
       var["state"] = 0
       var["init"] = true
    end

    if var["state"] == 0 then
        if charge < 10 then
            var["state"] = 1
        end
    else
        if charge > 50 then
            var["state"] = 0
        end
    end

    output = {}
    output["signal-P"] = var["state"]
 end