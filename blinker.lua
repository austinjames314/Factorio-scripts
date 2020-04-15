on_tick = function (event)
    if var["init"] == nil then
       var["light"] = 1
       var["init"] = true
    end
    delay = 60
    output = {}
    output["signal-green"] = 1
    var["light"]  = var["light"]  * -1
    output["signal-L"] = var["light"]
 end