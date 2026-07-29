local function log(message, level)
    if not Config.Server.enableLogs and level ~= 'error' then return end
    local prefix = ('[%s]'):format(Hud.resource)

    if level == 'error' then
        lib.print.error(('%s %s'):format(prefix, message))
    elseif level == 'warn' then
        lib.print.warn(('%s %s'):format(prefix, message))
    else
        lib.print.info(('%s %s'):format(prefix, message))
    end
end

local function validateServerConfig()
    local valid, sharedErrors = Hud.validateSharedConfig()
    if not valid then
        for index = 1, #sharedErrors do
            log(('%s: %s'):format(locale('config_error'), sharedErrors[index]), 'error')
        end
    end

    if type(Config.Server) ~= 'table' then
        log(('%s: Config.Server'):format(locale('config_error')), 'error')
        return false
    end

    if not Hud.isNumberInRange(Config.Server.initialDataCooldown, 250, 10000) then
        valid = false
        log(('%s: Config.Server.initialDataCooldown'):format(locale('config_error')), 'error')
    end

    if type(Config.Server.enableLogs) ~= 'boolean' then
        valid = false
        log(('%s: Config.Server.enableLogs'):format(locale('config_error')), 'error')
    end

    return valid
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= Hud.resource then return end

    if GetResourceState('ox_lib') ~= 'started' then
        log(locale('dependency_missing', 'ox_lib'), 'error')
        return
    end

    if GetResourceState('qbx_core') ~= 'started' then
        log(locale('dependency_missing', 'qbx_core'), 'error')
        return
    end

    if validateServerConfig() then
        log(locale('resource_started'), 'info')
    end
end)
