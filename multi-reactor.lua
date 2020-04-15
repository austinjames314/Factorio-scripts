on_tick = function (event)
    ReactorNumber = "1" -- Used to send different signals depending on status. TO be set individually for each core.

    --'Constants'
    PumpPowerMatrix = {50, 100, 120} -- Thermal power draw at each stage of pump activation.
    PumpSignalMatrix = {"signal-A", "signal-B", "signal-C"} -- Signals to output to activate each level of pumps

    MaxPeakLoadTemp = 980 -- Temp to switch on all pumps, regardless of other considerations.
    CoolingTemp = 985 -- Temp to start ECS
    ScramTemp = 990 -- Temp to shutdown the core
    CoolantCutoff = 14000 -- Coolant level below which to scram the core regardless

    SteamShutdownLevel = 343200 -- 260 seconds (gives buffer to keep filling with steam while shutting down)
    SteamStartupLevel = 62400 -- 47 seconds 

    ECSPumpSignal = "signal-E"
    LightSignal = "signal-L"

    -- Global State variable
    State = 0

    --Set delay. High precision when risk is high otherwise use less UPS
    if coreTemp >= 985 then
        delay = 1
    else
        delay = 12
    end

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

    --Set the state variable based on the current state, scramming the core if something is wrong.
    if not (rednet["signal-state-stopped"] == nil) and rednet["signal-state-stopped"] > 0 then
        State = 0
    elseif not (rednet["signal-state-starting"] == nil) and rednet["signal-state-starting"] > 0 then
        State = 1
    elseif not (rednet["signal-state-running"] == nil) and rednet["signal-state-running"] > 0 then
        State = 2
    elseif not (rednet["signal-state-scramed"] == nil) and rednet["signal-state-scramed"] > 0 then
        State = 3
    else
        output["signal-control-scram"] = 999
        return
    end

    Steam = rednet["steam"]
    if Steam == nil then
        Steam = 0
    end

    --Wipe the outputs to reset them all
    output = {}


    --Setup complete
    

    --State specific logic

    if State == 0 then
        --no lights

        --if steam level is low, startup again
        if Steam < SteamStartupLevel and CoolantReserve > CoolantCutoff then
            output["signal-control-start"] = 1
        end
    elseif State == 1 then
        --set signal light
        output[LightSignal] = 1
        output["signal-yellow"] = 1

    elseif State == 2 then
        --set signal light
        output[LightSignal] = 1
        output["signal-green"] = 1

        --if steam level is nearly full then shutdown
        if Steam > SteamShutdownLevel then
            output["signal-control-scram"] = 1
        end

        -- Scram the core if too hot
        if coreTemp > ScramTemp then
            output["signal-control-scram"] = 1
        end
        --Scram the core if coolant reserve is getting too low
        if CoolantReserve < CoolantCutoff then
            output["signal-control-scram"] = 1
        end
    elseif State == 3 then
        --set signal light
        output[LightSignal] = 1
        output["signal-red"] = 1
    end
    --Output the reactor state for the over-controller to see
    output["signal-"..ReactorNumber] = State


    -- Always do these thermal control measures:

    --Once we exceed the the base thermal output level, activate the first set of pumps
    for i = 1, #PumpSignalMatrix do
        if powerOutput >= PumpPowerMatrix[i] then
            if i < #PumpSignalMatrix then -- if i is not the last index in the table
                if powerOutput >= (PumpPowerMatrix[i] + PumpPowerMatrix[i+1]) / 2 then -- then if the power is halfway to the next level
                    --then turn on the ith pump level and all lower levels
                    for j = 1, i do
                        output[PumpSignalMatrix[j]] = 1
                    end
                else
                    --don't turn the pumps on then...
                end
            else
                -- we're at or above max design power. All pumps on.
                for j = 1, #PumpSignalMatrix do
                    output[PumpSignalMatrix[j]] = 1
                end
            end
        else
            --we're below this power level, so no need to loop further.
            break
        end
    
    end
    
    --Turn on all heat exchanger pumps when the Maximum nominal temperature is reached, or we're at the max power draw level
    if coreTemp > MaxPeakLoadTemp then
        for i = 1, #PumpSignalMatrix do
            output[PumpSignalMatrix[i]] = 1
        end
    end
    
    --Activate cooling when at Max Temp
    if coreTemp > CoolingTemp then
        output[ECSPumpSignal] = 1
    end
end