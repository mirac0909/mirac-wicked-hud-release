Config.Client = {
    playerUpdateInterval = 220,
    vehicleUpdateInterval = 100,
    hiddenUpdateInterval = 600,
    idleVehicleInterval = 900,
    locationUpdateInterval = 900,
    minimapScaleformTimeout = 5000,
    seatbeltControlInterval = 50,
    showAllStatusesDuration = 5000,
    playerDataWaitTimeout = 10000,
    nuiDebug = false,
    enableTestApi = false,
    showOnPause = false
}

local function validateClientConfig()
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
            minimapScaleformTimeout = { 500, 30000 },
            seatbeltControlInterval = { 10, 250 },
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

    if type(Config.Minimap) == 'table'
        and not Hud.isNumberInRange(Config.Minimap.restoreZoom, 0, 2000)
    then
        add('Config.Minimap.restoreZoom')
    end

    return valid, errors
end

Hud.configValid, Hud.configErrors = validateClientConfig()

function Hud.awaitConfigValidation()
    return Hud.configValid == true
end
