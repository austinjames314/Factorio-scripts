on_tick = function (event)
    -- read in variables
    coreTemp = rednet["signal-reactor-core-temp"]
    if coreTemp == nil then
        coreTemp = 0
    end

    powerOutput = rednet["signal-reactor-power-output"]
    if powerOutput == nil then
        powerOutput = 0
    end

    CoolantReserve = rednet["water"]
    if CoolantReserve == nil then
        CoolantReserve = 0
    end

    Starting = rednet["signal-state-starting"]
    if Starting == nil then
        Starting = 0
    end

    Stopping = rednet["signal-state-scramed"]
    if Stopping == nil then
        Stopping = 0
    end

    Running = rednet["signal-state-running"]
    if Running == nil then
        Running = 0
    end

    Stopped = rednet["signal-state-stopped"]
    if Stopped == nil then
        Stopped = 0
    end

    Steam = rednet["steam"]
    if Steam == nil then
        Steam = 0
    end

    --'Constants'  *** SET THESE FOR THE SPECIFIC HARDWARE DESIGN ***
    PumpPowerMatrix = {60, 80, 100, 120, 130} -- Thermal power draw at each stage of pump activation.
    PumpSignalMatrix = {"signal-A", "signal-B", "signal-C", "signal-D", "signal-E"} -- Signals to output to activate each level of pumps

    MaxPeakLoadTemp = 980 -- Temp to switch on all pumps, regardless of other considerations.
    CoolingTemp = 985 -- Temp to start ECS
    ScramTemp = 990 -- Temp to shutdown the core
    CoolantCutoff = 14000 --Coolant level below which to scram the core regardless
    TargetPowerOutput = 125 -- Target thermal output from the reactor, in MW

    SteamShutdownLevel = 400000 -- 255 seconds rounded up to 400k (1380 * 255 sec. Gives a buffer for shutdown, and startup, plus room for surplus steam during shutdown) 
    SteamStartupLevel = 82800 -- 60 seconds (1380 steam for 60 sec = 54000)

    ECSPumpSignal = "signal-exmark"
    LightSignal = "signal-L"

    --Wipe the outputs to reset them all
    output = {}

    --Set delay. High precision when risk is high otherwise use less UPS
    if coreTemp >= MaxPeakLoadTemp then
        delay = 1
    else
        delay = 12
    end

    -- Setup Complete

    -- auto startup & shutdown code
    if Running > 0 then
        --if steam level is nearly full then shutdown
        if Steam > SteamShutdownLevel then
            output["signal-control-scram"] = 1
        end
    elseif Stopped > 0 then
        --if steam level is low, startup again
        if Steam < SteamStartupLevel and CoolantReserve > CoolantCutoff then
            output["signal-control-start"] = 1
        end
    end

    -- Always do these thermal control measures:

    --Turn on all heat exchanger pumps when the Maximum nominal temperature is reached, or we're at the max power draw level
    if coreTemp > MaxPeakLoadTemp then
        for i = 1, #PumpSignalMatrix do
            output[PumpSignalMatrix[i]] = 1
        end
    end

    --Activate emergency cooling when appropriate
    if coreTemp > CoolingTemp then
        output[ECSPumpSignal] = 1
    end

    --Scram the core when appropriate
    if coreTemp > ScramTemp then
        output["signal-control-scram"] = 1
    end

    --Scram the core if coolant reserve is getting too low
    if CoolantReserve < CoolantCutoff then
        output["signal-control-scram"] = 1
    end

    --[[
        The compicated bit. The aim here is to be able to support a wide range of power outputs, but turning pumps on progressively.
        At each stage, the pumps to only cool the reactor by a bit less than it's thermal output, in order to allow the reactor to keep heating up.
        Once the reactor reaches it's design power output level, then the last pump kicks on and off to keep the reactor at that point.
        This loop assumes that TargetPowerOutput is a value between the last two values in the PumpPowerMatrix table.
    --]]

    for i = 1, #PumpPowerMatrix do
        if powerOutput >= PumpPowerMatrix[i] then
            -- the power exceed this level of pumps. The pumps should be turned on if either, we're halfway to the next pump level, or we're over the targetpower output
            if i < #PumpPowerMatrix then -- this is here to avoid an out of index error in the next if statement. But if it's false then current power exceeds pump capacity!
                if powerOutput >= (PumpPowerMatrix[i] + PumpPowerMatrix[i + 1]) / 2 then
                    -- then turn on this pump and all lower pumps
                    for j = 1, i do
                        output[PumpSignalMatrix[j]] = 1
                    end
                end

                if i == (#PumpPowerMatrix - 1) then -- if there's only one pump left, we can't afford to exceed it's cooling capacity.
                    if powerOutput > (PumpPowerMatrix[i] + PumpPowerMatrix[i + 1]) / 2 then -- check to see if we're over halfway to to reaching the final pump
                        output[PumpSignalMatrix[i+1]] = 1 -- if we are, turn on the next pump
                    end
                end
            else
                -- if we get here, and powerOutput >= PumpPowerMatrix[i], then the pumps can't cool enough. Turn on all pumps and the Emergency Cooling System.
                -- pumps first.
                for j = 1, #PumpSignalMatrix do
                    output[PumpSignalMatrix[j]] = 1
                end
                -- then the ECS
                output[ECSPumpSignal] = 1
            end
        else
            -- if power output is less than this pump level, then we can stop checking.
            break
        end
    end

    --Control the lights
    if Starting + Stopping + Running > 0 then
        output[LightSignal] = 1
    end
    if Starting > 0 then
        output["signal-yellow"] = 1
    elseif Stopping > 0 then
        output["signal-red"] = 1
    elseif Running == 1 then
        output["signal-green"] = 1
    end
end