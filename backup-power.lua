on_tick = function (event)
    -- set loop to run evry x ticks. if set to 60, runs once per second.
    delay = 60

    --Initialisation section. This bit runs only once
    if var["init"] == nil then
        var["state"] = 0 -- state 0 is off. initial default.
        var["init"] = true
     end

    -- read in variables
    -- in this case 'charge' is not stored in the var[] table, meaning that it's value is lost between tick. But in this case that's fine.
    charge = greennet["signal-A"]
    if charge == nil then
        charge = 0
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