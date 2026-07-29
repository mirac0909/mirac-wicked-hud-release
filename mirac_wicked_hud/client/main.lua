Hud.statusRevealUntil = Hud.statusRevealUntil or 0

local initializing = false
local initializationToken = 0

local function log(level, message)
    if not Config.Client.nuiDebug then return end
    if level == 'error' then lib.print.error(message)
    elseif level == 'warn' then lib.print.warn(message)
    else lib.print.debug(message) end
end

local function validateConfig()
    local valid, errors = Hud.validateSharedConfig()

    local function add(path)
        valid = false
        errors[#errors + 1] = path
    end

    if type(Config.Client) ~= 'table' then
        add('Config.Client')
    else
        local ranges = {
            playerUpdateInterval = { 50, 5000 },
            vehicleUpdateInterval = { 50, 5000 },
            hiddenUpdateInterval = { 100, 10000 },
            idleVehicleInterval = { 100, 10000 },
            locationUpdateInterval = { 100, 10000 },
            showAllStatusesDuration = { 500, 30000 },
            playerDataWaitTimeout = { 1000, 60000 }
        }

        for key, range in pairs(ranges) do
            if not Hud.isNumberInRange(Config.Client[key], range[1], range[2]) then
                add(('Config.Client.%s'):format(key))
            end
        end

        if type(Config.Client.nuiDebug) ~= 'boolean' then add('Config.Client.nuiDebug') end
        if type(Config.Client.enableTestApi) ~= 'boolean' then add('Config.Client.enableTestApi') end
        if type(Config.Client.showOnPause) ~= 'boolean' then add('Config.Client.showOnPause') end
    end

    if type(Config.Oxygen) ~= 'table' then
        add('Config.Oxygen')
    else
        if type(Config.Oxygen.enabled) ~= 'boolean' then add('Config.Oxygen.enabled') end
        if not Hud.isNumberInRange(Config.Oxygen.maxSeconds, 1, 120) then
            add('Config.Oxygen.maxSeconds')
        end
    end

    for index = 1, #errors do
        lib.print.error(('[%s] %s: %s'):format(Hud.resource, locale('config_error'), errors[index]))
    end

    return valid
end

local function clearHud()
    initializationToken = initializationToken + 1
    initializing = false
    Hud.state.loaded = false
    Hud.state.citizenid = nil
    Hud.statusRevealUntil = 0

    Hud.closeSettings()
    Hud.player.clear()
    Hud.sendNuiUpdate({ vehicle = false }, true)
    Hud.clearNuiState()
    Hud.sendNui(Hud.actions.settings, { open = false, state = Hud.getSettingsState() }, true)
    Hud.sendNui(Hud.actions.visibility, {
        panelsVisible = false, notificationsVisible = false, textUiVisible = false
    }, true)
end

function Hud.initialize(reason)
    if Hud.configValid == false or initializing or not Hud.Qbox.isLoggedIn() then return false end

    initializing = true
    initializationToken = initializationToken + 1
    local token = initializationToken

    local ok, data = pcall(function()
        return lib.callback.await(Hud.events.initialData, false)
    end)

    initializing = false
    if token ~= initializationToken then return false end

    if not ok or type(data) ~= 'table' or type(data.citizenid) ~= 'string' then
        log('error', ('[%s] %s (%s)'):format(Hud.resource, locale('initial_data_failed'), tostring(reason or 'unknown')))
        return false
    end

    if data.citizenid ~= Hud.Qbox.getCitizenId() then
        log('warn', ('[%s] Ignored a stale initial data response.'):format(Hud.resource))
        return false
    end

    Hud.state.loaded = true
    Hud.state.citizenid = data.citizenid

    Hud.sendLocale()
    Hud.sendConfig()
    Hud.publishPosition()
    Hud.publishPalette()
    Hud.player.setInitialData(data)
    Hud.sendVisibility(true)
    Hud.vehicle.reapplyNativeHud(180)

    TriggerEvent(('%s:ready'):format(Hud.resource), Hud.copy(data))
    return true
end

AddEventHandler(Hud.events.playerLoaded, function()
    CreateThread(function()
        Wait(250)
        Hud.initialize('playerLoaded')
    end)
end)

-- `playerSpawned` can fire after Qbox has loaded the character. GTA may
-- restore its stock radar/health-armour UI during that spawn transition, so
-- re-assert the configured HUD state after the spawn has settled.
AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(250)
        if Hud.configValid ~= false then Hud.vehicle.reapplyNativeHud(180) end
    end)
end)

AddEventHandler(Hud.events.playerUnloaded, function()
    clearHud()
end)

AddEventHandler(Hud.events.playerDataChanged, function(snapshot)
    if type(snapshot) ~= 'table' then return end

    if not Hud.state.loaded then
        if Hud.Qbox.isLoggedIn() then Hud.initialize('playerDataChanged') end
        return
    end

    if snapshot.citizenid ~= Hud.state.citizenid then
        clearHud()
        if snapshot.citizenid then
            CreateThread(function()
                Wait(250)
                Hud.initialize('characterSwitch')
            end)
        end
        return
    end

    Hud.player.updateFrameworkData(snapshot)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= Hud.resource then return end
    if Hud.configValid == false then
        Hud.sendNui(Hud.actions.visibility, {
            panelsVisible = false, notificationsVisible = false, textUiVisible = false
        }, true)
        return
    end

    CreateThread(function()
        local timeout = GetGameTimer() + Config.Client.playerDataWaitTimeout
        Hud.sendLocale()
        Hud.sendConfig()
        Hud.publishPosition()

        -- During a resource restart the client can finish loading a fraction
        -- earlier than the server callback registration. A single failed
        -- request used to leave the HUD hidden until the next logout/login
        -- lifecycle event. Retry beyond the server callback cooldown.
        -- Server cooldown is intentionally server-only config, so keep the
        -- client retry interval independent and slightly above its default.
        local retryInterval = 1100
        while not Hud.state.loaded and GetGameTimer() < timeout do
            if Hud.Qbox.isLoggedIn() and Hud.initialize('resourceStart') then break end
            Wait(retryInterval)
        end

        if not Hud.state.loaded then
            Hud.sendNui(Hud.actions.visibility, {
                panelsVisible = false, notificationsVisible = false, textUiVisible = false
            }, true)
            log('warn', ('[%s] %s'):format(Hud.resource, locale('player_not_loaded')))
        end
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= Hud.resource then return end

    SetNuiFocus(false, false)
    Hud.sendNui(Hud.actions.visibility, {
        panelsVisible = false, notificationsVisible = false, textUiVisible = false
    }, true)
    Hud.resetNui()
    Hud.vehicle.restoreNativeHud()
end)

exports('getState', function()
    return {
        loaded = Hud.state.loaded,
        enabled = Hud.settings.enabled,
        minimal = Hud.settings.minimal,
        position = Hud.settings.position,
        citizenid = Hud.state.citizenid
    }
end)

Hud.configValid = validateConfig()
