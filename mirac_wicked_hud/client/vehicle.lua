Hud.vehicle = Hud.vehicle or {
    minimapScaleform = nil,
    warmupFrames = 0,
    nativeVitalsGuardFrames = 0,
    active = false,
    radarVisible = nil,
    initialRadarVisible = nil,
    minimapLayoutTouched = false,
    seatbelt = false,
    seatbeltOverride = nil
}

local defaultMinimapLayout = {
    minimap = { -0.0045, 0.002, 0.150, 0.188888 },
    mask = { 0.020, 0.032, 0.111, 0.159 },
    blur = { -0.030, 0.022, 0.266, 0.237 }
}

local function minimapManaged()
    return Config.Components.minimap and Config.Minimap.mode ~= 'never'
end

local function setNativeVitalsVisible(visible)
    local scaleform = Hud.vehicle.minimapScaleform
    if not scaleform or not HasScaleformMovieLoaded(scaleform) then return end

    BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(visible and 0 or 3)
    EndScaleformMovieMethod()
end

local function forceMinimapRefresh()
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
end

local function configureMinimap()
    if not minimapManaged() then return end

    Hud.vehicle.minimapLayoutTouched = true
    SetMinimapClipType(0)
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045, -0.0220, 0.1500, 0.1889)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0200, 0.0320, 0.1110, 0.1590)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.0300, 0.0220, 0.2660, 0.2370)
end

local function restoreMinimapLayout()
    if not Hud.vehicle.minimapLayoutTouched then return end

    local minimap = defaultMinimapLayout.minimap
    local mask = defaultMinimapLayout.mask
    local blur = defaultMinimapLayout.blur

    SetMinimapClipType(0)
    SetMinimapComponentPosition('minimap', 'L', 'B', minimap[1], minimap[2], minimap[3], minimap[4])
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', mask[1], mask[2], mask[3], mask[4])
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', blur[1], blur[2], blur[3], blur[4])
    forceMinimapRefresh()
    Hud.vehicle.minimapLayoutTouched = false
end

local function setRadarVisible(visible, force)
    visible = visible == true

    -- GTA can restore the radar during spawn/respawn after this resource has
    -- already hidden it. Compare against the real game state as well as our
    -- cached state so the HUD can correct external/native state changes.
    local actualVisible = not IsRadarHidden()
    if not force and Hud.vehicle.radarVisible == visible and actualVisible == visible then return end

    DisplayRadar(visible)
    Hud.vehicle.radarVisible = visible
end

local function primeMinimap()
    if not minimapManaged() then return end

    setRadarVisible(false, true)
    forceMinimapRefresh()
    configureMinimap()
    if Config.Minimap.hideNativeVitals then setNativeVitalsVisible(false) end
    Hud.vehicle.warmupFrames = 2
    Hud.vehicle.nativeVitalsGuardFrames = 45
end

local function isRadarAllowed(inVehicle)
    if not minimapManaged() then return false end
    if not Hud.shouldShow() then return false end
    if Config.Minimap.mode == 'always' then return true end
    return inVehicle
end

local function readNitro(vehicle)
    if not Config.Nitro.enabled then return false end

    local state = Entity(vehicle).state
    if not state then return false end

    for index = 1, #Config.Nitro.stateBags do
        local rawValue = state[Config.Nitro.stateBags[index]]
        if rawValue ~= nil then
            return Hud.clamp(rawValue, 0, 100) or 0
        end
    end

    return false
end

local unsupportedSeatbeltClasses = {
    [8] = true,  -- motorcycles
    [13] = true, -- cycles
    [14] = true, -- boats
    [15] = true, -- helicopters
    [16] = true, -- planes
    [21] = true  -- trains
}

local function supportsSeatbelt(vehicle)
    return Config.Seatbelt.enabled and not unsupportedSeatbeltClasses[GetVehicleClass(vehicle)]
end

local function normalizeSeatbeltValue(value)
    if value == true or value == 1 or value == '1' or value == 'true' then return true end
    if value == false or value == 0 or value == '0' or value == 'false' then return false end
end

local function readSeatbelt(vehicle)
    if not supportsSeatbelt(vehicle) then return false end
    if Hud.vehicle.seatbeltOverride ~= nil then return Hud.vehicle.seatbeltOverride end

    local state = Entity(vehicle).state
    for index = 1, #Config.Seatbelt.stateBags do
        local value = normalizeSeatbeltValue(state[Config.Seatbelt.stateBags[index]])
        if value ~= nil then return value end
    end

    return Hud.vehicle.seatbelt
end

local warningVehicle = nil
local fuelWarningStage = nil
local engineWarningStage = nil
local criticalReminderAt = nil
local gearVehicle = nil
local previousForwardGear = nil
local lastGearSoundAt = 0
local nitroSoundVehicle = nil
local previousNitroLevel = nil
local nitroSoundStarted = false
local previousNitroActive = nil

local function playConfiguredSound(settings, nativeSound, customSound)
    if not settings.sound then return end

    if settings.soundMode == 'custom' then
        if not Hud.isNuiReady() then return end
        Hud.sendNui('hud:vehicleSound', {
            file = customSound,
            volume = settings.customVolume
        }, true)
        return
    end

    PlaySoundFrontend(-1, nativeSound, settings.soundset, true)
end

local function playGearShiftSound(direction)
    local settings = Config.GearShiftSound
    if not settings or not settings.enabled or not settings.sound or not Hud.isNuiReady() then return false end

    local file = settings.customSounds and settings.customSounds[direction]
    if type(file) ~= 'string' or file == '' then return false end

    Hud.sendNui('hud:vehicleSound', {
        file = file,
        volume = settings.customVolume
    }, true)
    return true
end

local function playNitroSound(kind)
    local settings = Config.Nitro
    if not settings or not settings.enabled or not settings.sound or not Hud.isNuiReady() then return false end

    local file = settings.customSounds and settings.customSounds[kind]
    if type(file) ~= 'string' or file == '' then return false end

    Hud.sendNui('hud:vehicleSound', {
        file = file,
        volume = settings.customVolumes and settings.customVolumes[kind] or 0.35
    }, true)
    return true
end

local function updateNitroSounds(vehicle, level)
    if level == false then
        nitroSoundVehicle = nil
        previousNitroLevel = nil
        nitroSoundStarted = false
        previousNitroActive = nil
        return
    end

    local rawActive = Entity(vehicle).state.nitroActive
    local active = rawActive == true

    if nitroSoundVehicle ~= vehicle then
        nitroSoundVehicle = vehicle
        previousNitroLevel = level
        nitroSoundStarted = false
        previousNitroActive = active
        return
    end

    local previous = previousNitroLevel
    previousNitroLevel = level
    if previous == nil then return end

    -- Prefer the explicit active state when the nitro resource provides it.
    -- Falling level remains a compatibility fallback for level-only scripts.
    local explicitActivation = rawActive ~= nil and active and previousNitroActive ~= true
    local inferredActivation = rawActive == nil
        and not nitroSoundStarted
        and level > 0
        and previous - level >= Config.Nitro.consumptionEpsilon

    previousNitroActive = active

    if explicitActivation or inferredActivation then
        nitroSoundStarted = true
        playNitroSound('start')
    end

    if nitroSoundStarted and previous > 0 and level <= 0 then
        nitroSoundStarted = false
        playNitroSound('empty')
    end
end

local function updateGearShiftSound(vehicle, gear, speed)
    local settings = Config.GearShiftSound
    if not settings or not settings.enabled then return end

    if gearVehicle ~= vehicle then
        gearVehicle = vehicle
        previousForwardGear = gear > 0 and gear or nil
        lastGearSoundAt = 0
        return
    end

    -- Neutral/reverse transitions and the initial gear reading are not
    -- forward transmission shifts, so they must not trigger the effect.
    if gear <= 0 then return end
    if not previousForwardGear then
        previousForwardGear = gear
        return
    end
    if gear == previousForwardGear then return end

    local oldGear = previousForwardGear
    previousForwardGear = gear

    if speed < settings.minimumSpeed then return end

    local now = GetGameTimer()
    if now - lastGearSoundAt < settings.cooldown then return end

    lastGearSoundAt = now
    playGearShiftSound(gear > oldGear and 'up' or 'down')
end

local function getWarningStage(value)
    if value <= Config.VehicleWarnings.dangerThreshold then return 2 end
    if value <= Config.VehicleWarnings.warningThreshold then return 1 end
    return 0
end

local function updateVehicleWarningSounds(vehicle, fuel, engine)
    if not Config.VehicleWarnings.enabled then return end

    local nextFuelStage = getWarningStage(fuel)
    local nextEngineStage = getWarningStage(engine)

    if warningVehicle ~= vehicle or fuelWarningStage == nil or engineWarningStage == nil then
        warningVehicle = vehicle
        fuelWarningStage = nextFuelStage
        engineWarningStage = nextEngineStage
        criticalReminderAt = (nextFuelStage == 2 or nextEngineStage == 2)
            and (GetGameTimer() + Config.VehicleWarnings.criticalRepeatInterval)
            or nil
        return
    end

    local enteredStage = 0
    if nextFuelStage > fuelWarningStage then enteredStage = nextFuelStage end
    if nextEngineStage > engineWarningStage then enteredStage = math.max(enteredStage, nextEngineStage) end

    fuelWarningStage = nextFuelStage
    engineWarningStage = nextEngineStage

    local now = GetGameTimer()
    local hasCriticalWarning = nextFuelStage == 2 or nextEngineStage == 2
    local soundStage = enteredStage

    if enteredStage == 2 then
        criticalReminderAt = now + Config.VehicleWarnings.criticalRepeatInterval
    elseif hasCriticalWarning and criticalReminderAt and now >= criticalReminderAt then
        soundStage = 2
        criticalReminderAt = now + Config.VehicleWarnings.criticalRepeatInterval
    elseif hasCriticalWarning and not criticalReminderAt then
        criticalReminderAt = now + Config.VehicleWarnings.criticalRepeatInterval
    elseif not hasCriticalWarning then
        criticalReminderAt = nil
    end

    if soundStage > 0 then
        local danger = soundStage == 2
        playConfiguredSound(
            Config.VehicleWarnings,
            danger and Config.VehicleWarnings.dangerSound or Config.VehicleWarnings.warningSound,
            danger and Config.VehicleWarnings.customSounds.danger or Config.VehicleWarnings.customSounds.warning
        )
    end
end

local function vehicleSnapshot(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local speedKmh = math.max(0, GetEntitySpeed(vehicle) * 3.6)
    local speed = Config.SpeedUnit == 'mph' and speedKmh * 0.621371 or speedKmh
    local gear = GetVehicleCurrentGear(vehicle)
    local rpm = Hud.round((Hud.clamp(GetVehicleCurrentRpm(vehicle), 0, 1) or 0) * 100)
    updateGearShiftSound(vehicle, gear, speed)
    local nitro = readNitro(vehicle)
    updateNitroSounds(vehicle, nitro)
    local nitroValue = false
    local fuel = Hud.round(Hud.clamp(Hud.Fuel.get(vehicle), 0, 100) or 0)
    local engine = Hud.round(Hud.clamp(GetVehicleEngineHealth(vehicle) / 10, 0, 100) or 0)
    if nitro ~= false then nitroValue = Hud.round(nitro) end
    updateVehicleWarningSounds(vehicle, fuel, engine)

    return {
        speed = Hud.round(speed),
        rpm = rpm,
        fuel = fuel,
        engine = engine,
        nitro = nitroValue,
        seatbeltAvailable = supportsSeatbelt(vehicle),
        seatbelt = readSeatbelt(vehicle),
        gear = gear == 0 and (speed < 1 and 'N' or 'R') or tostring(gear)
    }
end

function Hud.vehicle.setSeatbelt(enabled)
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not supportsSeatbelt(vehicle) then
        return false
    end

    local previous = readSeatbelt(vehicle)
    Hud.vehicle.seatbelt = enabled == true
    Hud.vehicle.seatbeltOverride = Hud.vehicle.seatbelt

    if previous ~= Hud.vehicle.seatbelt then
        playConfiguredSound(
            Config.Seatbelt,
            Hud.vehicle.seatbelt and Config.Seatbelt.buckleSound or Config.Seatbelt.unbuckleSound,
            Hud.vehicle.seatbelt and Config.Seatbelt.customSounds.buckle or Config.Seatbelt.customSounds.unbuckle
        )
    end

    Hud.sendNuiUpdate({ vehicle = vehicleSnapshot(vehicle) })
    return true
end

function Hud.vehicle.isSeatbeltOn()
    local vehicle = cache.vehicle
    return vehicle and vehicle ~= 0 and readSeatbelt(vehicle) == true or false
end

function Hud.vehicle.reapplyNativeHud(guardFrames)
    guardFrames = math.max(tonumber(guardFrames) or 180, 1)
    Hud.vehicle.nativeVitalsGuardFrames = math.max(Hud.vehicle.nativeVitalsGuardFrames or 0, guardFrames)

    if minimapManaged() then
        configureMinimap()
        if Config.Minimap.hideNativeVitals then setNativeVitalsVisible(false) end
    end

    local vehicle = cache.vehicle
    local inVehicle = vehicle and vehicle ~= 0
    setRadarVisible(isRadarAllowed(inVehicle), true)
end

local function onVehicleChanged(vehicle)
    local inVehicle = vehicle and vehicle ~= 0
    Hud.vehicle.active = inVehicle == true
    Hud.vehicle.seatbelt = false
    Hud.vehicle.seatbeltOverride = nil
    warningVehicle = nil
    fuelWarningStage = nil
    engineWarningStage = nil
    criticalReminderAt = nil
    gearVehicle = nil
    previousForwardGear = nil
    lastGearSoundAt = 0
    nitroSoundVehicle = nil
    previousNitroLevel = nil
    nitroSoundStarted = false
    previousNitroActive = nil

    if inVehicle then
        CreateThread(primeMinimap)
    else
        Hud.vehicle.warmupFrames = 0
        Hud.vehicle.nativeVitalsGuardFrames = 0
        Hud.sendNuiUpdate({ vehicle = false }, true)
        if Config.Minimap.mode ~= 'always' then setRadarVisible(false) end
    end
end

lib.onCache('vehicle', function(value)
    onVehicleChanged(value)
end)

if Config.Seatbelt.enabled and Config.Seatbelt.builtIn then
    lib.addKeybind({
        name = ('%s_seatbelt'):format(Hud.resource:gsub('[^%w_]', '_')),
        description = locale('seatbelt_toggle'),
        defaultKey = Config.Seatbelt.defaultKey,
        onPressed = function()
            Hud.vehicle.setSeatbelt(not Hud.vehicle.isSeatbeltOn())
        end
    })
end

RegisterNetEvent(('%s:seatbelt:set'):format(Hud.resource), function(enabled)
    Hud.vehicle.setSeatbelt(enabled == true)
end)

exports('setSeatbelt', function(enabled)
    return Hud.vehicle.setSeatbelt(enabled == true)
end)

exports('isSeatbeltOn', function()
    return Hud.vehicle.isSeatbeltOn()
end)

exports('playGearShiftSound', function(direction)
    direction = direction == 'down' and 'down' or 'up'
    return playGearShiftSound(direction)
end)

exports('playNitroSound', function(kind)
    kind = kind == 'empty' and 'empty' or 'start'
    local played = playNitroSound(kind)
    if kind == 'empty' and Hud.isNuiReady() then
        Hud.sendNui('hud:nitroEmptyAttempt', {}, true)
    end
    return played
end)

CreateThread(function()
    while true do
        if Config.Seatbelt.preventExit and Hud.vehicle.isSeatbeltOn() then
            DisableControlAction(0, 75, true)
            DisableControlAction(27, 75, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    Hud.vehicle.initialRadarVisible = not IsRadarHidden()

    if minimapManaged() then
        Hud.vehicle.minimapScaleform = RequestScaleformMovie('minimap')
        while not HasScaleformMovieLoaded(Hud.vehicle.minimapScaleform) do Wait(100) end

        forceMinimapRefresh()
        configureMinimap()
        if Config.Minimap.hideNativeVitals then setNativeVitalsVisible(false) end
    end

    onVehicleChanged(cache.vehicle)
    setRadarVisible(isRadarAllowed(cache.vehicle and cache.vehicle ~= 0), true)
end)

CreateThread(function()
    while true do
        local vehicle = cache.vehicle
        if not Config.Components.vehicle or not Hud.shouldShow() or not vehicle or vehicle == 0 then
            if not vehicle or vehicle == 0 then Hud.sendNuiUpdate({ vehicle = false }) end
            Wait(vehicle and Config.Client.hiddenUpdateInterval or Config.Client.idleVehicleInterval)
        else
            Hud.sendNuiUpdate({ vehicle = vehicleSnapshot(vehicle) })
            Wait(Config.Client.vehicleUpdateInterval)
        end
    end
end)

CreateThread(function()
    while true do
        local vehicle = cache.vehicle
        local inVehicle = vehicle and vehicle ~= 0
        local enteringVehicle = not inVehicle and GetVehiclePedIsTryingToEnter(cache.ped) ~= 0
        local radarVisible = isRadarAllowed(inVehicle) and Hud.vehicle.warmupFrames == 0

        if enteringVehicle and minimapManaged() then
            Hud.vehicle.nativeVitalsGuardFrames = 45
            if Config.Minimap.hideNativeVitals then setNativeVitalsVisible(false) end
            setRadarVisible(false)
        end

        if Hud.vehicle.nativeVitalsGuardFrames > 0 then
            if Config.Minimap.hideNativeVitals then setNativeVitalsVisible(false) end
            Hud.vehicle.nativeVitalsGuardFrames = Hud.vehicle.nativeVitalsGuardFrames - 1
        end

        if Hud.vehicle.warmupFrames > 0 then
            Hud.vehicle.warmupFrames = Hud.vehicle.warmupFrames - 1
            radarVisible = false
        end

        setRadarVisible(radarVisible)

        if inVehicle and Hud.shouldShow() then
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            Wait(0)
        elseif enteringVehicle or Config.Minimap.mode == 'always' or Hud.vehicle.nativeVitalsGuardFrames > 0 then
            -- During initial spawn/respawn GTA may recreate its HUD for a few
            -- frames. Stay frame-synchronous while the guard is active.
            Wait(0)
        else
            Wait(350)
        end
    end
end)

-- The pause frontend rebuilds parts of the minimap scaleform when it closes.
-- Reassert the custom HUD state on that exact transition so GTA's native
-- health/armour panel or radar does not remain visible until another event.
CreateThread(function()
    local pauseWasActive = IsPauseMenuActive()

    while true do
        local pauseActive = IsPauseMenuActive()

        if pauseWasActive and not pauseActive then
            Hud.vehicle.reapplyNativeHud(180)
            Hud.sendVisibility(true)
        end

        pauseWasActive = pauseActive
        Wait(pauseActive and 0 or 100)
    end
end)

function Hud.vehicle.restoreNativeHud()
    Hud.vehicle.warmupFrames = 0
    Hud.vehicle.nativeVitalsGuardFrames = 0

    if Hud.vehicle.minimapScaleform and Config.Minimap.hideNativeVitals then
        setNativeVitalsVisible(true)
    end

    restoreMinimapLayout()
    local originalRadarVisible = Hud.vehicle.initialRadarVisible
    if originalRadarVisible == nil then originalRadarVisible = true end
    setRadarVisible(originalRadarVisible, true)
end
