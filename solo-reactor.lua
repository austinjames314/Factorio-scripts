function on_tick()
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


    --'Constants'
    ReactorNumber = "1" -- Used to send different signals depending on status.

    PumpMatrix = {60, 70} -- Thermal power draw at each stage of pump activation.
    PumpSignals = {"signal-A", "signal-B"} -- Signals to output to activate each level of pumps

    MaxPeakLoadTemp = 980 -- Temp to switch on all pumps, regardless of other considerations.
    CoolingTemp = 985 -- Temp to start ECS
    ScramTemp = 990 -- Temp to shutdown the core
    CoolantCutoff = 7000 -- Coolant level below which to scram the core regardless

    SteamShutdownLevel = 171600 -- 220seconds (gives buffer to keep filling with steam while shutting down)
    SteamStartupLevel = 31200 -- 40 seconds 


    ECSPumpSignal = "signal-E"
    LightSignal = "signal-L"

    --Wipe the outputs to reset them all
    output = {}

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

    --Once we exceed the the base thermal output level, activate the first set of pumps
    if powerOutput >= (PumpMatrix[1] + PumpMatrix[#PumpMatrix]) / 2 then
        output[PumpSignals[1]] = 1
    end
    
    --Turn on all heat exchanger pumps when the Maximum nominal temperature is reached, or we're at the max power draw level
    if coreTemp > MaxPeakLoadTemp or powerOutput >= PumpMatrix[#PumpMatrix] then
        for i = 1, #PumpSignals do
            output[PumpSignals[i]] = 1
        end
    end

    --Activate cooling when appropriate
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

    output["signal-"..ReactorNumber] = Running
end