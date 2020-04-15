on_tick = function (event)
    if var["init"] == nil then
       var["light"] = 1
       var["init"] = true
    end
    colour = "signal-green"
    delay = 60
    output = {}
    output[colour] = 1
    var["light"]  = var["light"]  * -1
    output["signal-L"] = var["light"]
 end