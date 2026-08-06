function Hud.clamp(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return math.max(minimum, math.min(maximum, value))
end

function Hud.round(value)
    value = tonumber(value)
    if not value then return nil end
    return math.floor(value + 0.5)
end

function Hud.isPosition(value)
    return type(value) == 'string' and Hud.positions[value] == true
end

function Hud.safeString(value, maximumLength, fallback)
    if type(value) ~= 'string' then return fallback end
    value = value:gsub('%z', '')
    if #value > maximumLength then value = value:sub(1, maximumLength) end
    return value
end

function Hud.numericString(value, maximumLength, fallback)
    value = tostring(value or ''):gsub('%D', '')
    if #value == 0 then return fallback end
    if #value > maximumLength then value = value:sub(1, maximumLength) end
    return value
end

function Hud.copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Hud.copy(key, seen)] = Hud.copy(child, seen)
    end
    return result
end

function Hud.sameValue(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= 'table' then return left == right end
    if left == right then return true end

    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right

    for key, value in pairs(left) do
        if not Hud.sameValue(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

function Hud.isPlayerSource(value)
    value = tonumber(value)
    if not value then return nil end
    value = math.floor(value)
    if value < 1 or not GetPlayerName(value) then return nil end
    return value
end

function Hud.isOneOf(value, allowed)
    if type(value) ~= 'string' or type(allowed) ~= 'table' then return false end
    for index = 1, #allowed do
        if allowed[index] == value then return true end
    end
    return false
end

function Hud.isNumberInRange(value, minimum, maximum)
    return type(value) == 'number'
        and value == value
        and value >= minimum
        and value <= maximum
end

function Hud.validateSharedConfig()
    local errors = {}
    local function add(path) errors[#errors + 1] = path end
    local function validCustomSoundPath(value)
        if type(value) ~= 'string'
            or #value > 128
            or not value:match('^sounds/[%w%._%-%/]+$')
            or value:find('..', 1, true)
        then
            return false
        end

        local extension = value:lower():match('%.([%w]+)$')
        return extension == 'ogg' or extension == 'mp3' or extension == 'wav'
    end

    if type(Config.Identity) ~= 'table' then
        add('Config.Identity')
    else
        if type(Config.Identity.serverLabel) ~= 'string'
            or #Config.Identity.serverLabel < 1
            or #Config.Identity.serverLabel > 12
        then
            add('Config.Identity.serverLabel')
        end
        if type(Config.Identity.permanentIdField) ~= 'string'
            or #Config.Identity.permanentIdField < 1
            or #Config.Identity.permanentIdField > 64
        then
            add('Config.Identity.permanentIdField')
        end
        if not Hud.isNumberInRange(Config.Identity.permanentIdMaxLength, 1, 32) then
            add('Config.Identity.permanentIdMaxLength')
        end
    end

    local componentKeys = { 'identity', 'location', 'statuses', 'vehicle', 'voice', 'minimap' }
    if type(Config.Components) ~= 'table' then
        add('Config.Components')
    else
        for index = 1, #componentKeys do
            local key = componentKeys[index]
            if type(Config.Components[key]) ~= 'boolean' then add(('Config.Components.%s'):format(key)) end
        end
    end

    if type(Config.Metadata) ~= 'table' then
        add('Config.Metadata')
    else
        for _, key in ipairs({ 'hunger', 'thirst' }) do
            local value = Config.Metadata[key]
            if type(value) ~= 'string' or value == '' or #value > 64 then
                add(('Config.Metadata.%s'):format(key))
            end
        end
    end

    if type(Config.Keybinds) ~= 'table' then
        add('Config.Keybinds')
    else
        for _, key in ipairs({ 'toggle', 'peek' }) do
            local value = Config.Keybinds[key]
            if type(value) ~= 'string' or value == '' or #value > 32 then
                add(('Config.Keybinds.%s'):format(key))
            end
        end
    end

    if type(Config.Notifications) ~= 'table' then
        add('Config.Notifications')
    else
        if type(Config.Notifications.enabled) ~= 'boolean' then add('Config.Notifications.enabled') end
        if type(Config.Notifications.useHudForInternal) ~= 'boolean' then
            add('Config.Notifications.useHudForInternal')
        end
        if type(Config.Notifications.showWhenHudHidden) ~= 'boolean' then
            add('Config.Notifications.showWhenHudHidden')
        end
        if not Hud.isNumberInRange(Config.Notifications.hardSafetyLimit, 10, 500) then
            add('Config.Notifications.hardSafetyLimit')
        end
        if type(Config.Notifications.compatibilityFormats) ~= 'table' then
            add('Config.Notifications.compatibilityFormats')
        else
            for _, format in ipairs({ 'qb', 'esx' }) do
                if type(Config.Notifications.compatibilityFormats[format]) ~= 'boolean' then
                    add(('Config.Notifications.compatibilityFormats.%s'):format(format))
                end
            end
        end
        if not Hud.isNumberInRange(Config.Notifications.defaultDuration, 250, 60000) then
            add('Config.Notifications.defaultDuration')
        end
        if not Hud.isNumberInRange(Config.Notifications.minDuration, 250, 60000) then
            add('Config.Notifications.minDuration')
        end
        if not Hud.isNumberInRange(Config.Notifications.maxDuration, 250, 60000) then
            add('Config.Notifications.maxDuration')
        end
        if type(Config.Notifications.minDuration) == 'number'
            and type(Config.Notifications.maxDuration) == 'number'
            and Config.Notifications.minDuration > Config.Notifications.maxDuration
        then
            add('Config.Notifications.minDuration')
        end
        if type(Config.Notifications.defaultDuration) == 'number'
            and type(Config.Notifications.minDuration) == 'number'
            and type(Config.Notifications.maxDuration) == 'number'
            and (Config.Notifications.defaultDuration < Config.Notifications.minDuration
                or Config.Notifications.defaultDuration > Config.Notifications.maxDuration)
        then
            add('Config.Notifications.defaultDuration')
        end

        if type(Config.Notifications.bridgeEvents) ~= 'table' then
            add('Config.Notifications.bridgeEvents')
        else
            local seenEvents = {}
            for index = 1, #Config.Notifications.bridgeEvents do
                local eventName = Config.Notifications.bridgeEvents[index]
                if type(eventName) ~= 'string'
                    or eventName == ''
                    or #eventName > 96
                    or eventName == Hud.events.notify
                    or eventName == ('%s:notify'):format(Hud.resource)
                    or seenEvents[eventName]
                then
                    add(('Config.Notifications.bridgeEvents[%d]'):format(index))
                else
                    seenEvents[eventName] = true
                end
            end
        end
    end

    if type(Config.TextUI) ~= 'table' then
        add('Config.TextUI')
    else
        if type(Config.TextUI.enabled) ~= 'boolean' then add('Config.TextUI.enabled') end
        if type(Config.TextUI.showWhenHudHidden) ~= 'boolean' then add('Config.TextUI.showWhenHudHidden') end
    end

    if not Hud.isOneOf(Config.SpeedUnit, { 'kmh', 'mph' }) then add('Config.SpeedUnit') end
    if not Hud.isOneOf(Config.VoiceSystem, { 'auto', 'pma-voice', 'enhanced', 'native', 'custom' }) then
        add('Config.VoiceSystem')
    end
    if type(Config.VoiceModeStateBag) ~= 'string'
        or Config.VoiceModeStateBag == ''
        or #Config.VoiceModeStateBag > 64
    then
        add('Config.VoiceModeStateBag')
    end

    if type(Config.VoiceShoutAutoReset) ~= 'table' then
        add('Config.VoiceShoutAutoReset')
    else
        if type(Config.VoiceShoutAutoReset.enabled) ~= 'boolean' then
            add('Config.VoiceShoutAutoReset.enabled')
        end
        if not Hud.isNumberInRange(Config.VoiceShoutAutoReset.duration, 1000, 600000) then
            add('Config.VoiceShoutAutoReset.duration')
        end
        if not Hud.isNumberInRange(Config.VoiceShoutAutoReset.fallbackMode, 1, 3)
            or math.floor(Config.VoiceShoutAutoReset.fallbackMode or 0) ~= Config.VoiceShoutAutoReset.fallbackMode
        then
            add('Config.VoiceShoutAutoReset.fallbackMode')
        end
    end

    if not Hud.isOneOf(Config.FuelSystem, { 'native', 'statebag', 'export', 'custom' }) then add('Config.FuelSystem') end

    if type(Config.FuelStateBag) ~= 'string' or Config.FuelStateBag == '' or #Config.FuelStateBag > 64 then
        add('Config.FuelStateBag')
    end
    if Config.FuelSystem == 'export' then
        if type(Config.FuelResource) ~= 'string' or Config.FuelResource == '' or #Config.FuelResource > 96 then
            add('Config.FuelResource')
        end
        if type(Config.FuelExport) ~= 'string' or Config.FuelExport == '' or #Config.FuelExport > 96 then
            add('Config.FuelExport')
        end
    end

    if type(Config.Nitro) ~= 'table' then
        add('Config.Nitro')
    else
        if type(Config.Nitro.enabled) ~= 'boolean' then add('Config.Nitro.enabled') end
        if type(Config.Nitro.sound) ~= 'boolean' then add('Config.Nitro.sound') end
        if type(Config.Nitro.customVolumes) ~= 'table' then
            add('Config.Nitro.customVolumes')
        else
            for _, key in ipairs({ 'start', 'empty' }) do
                if not Hud.isNumberInRange(Config.Nitro.customVolumes[key], 0, 1) then
                    add(('Config.Nitro.customVolumes.%s'):format(key))
                end
            end
        end
        if not Hud.isNumberInRange(Config.Nitro.consumptionEpsilon, 0.001, 100) then
            add('Config.Nitro.consumptionEpsilon')
        end
        if type(Config.Nitro.customSounds) ~= 'table' then
            add('Config.Nitro.customSounds')
        else
            for _, key in ipairs({ 'start', 'empty' }) do
                if not validCustomSoundPath(Config.Nitro.customSounds[key]) then
                    add(('Config.Nitro.customSounds.%s'):format(key))
                end
            end
        end
        if type(Config.Nitro.stateBags) ~= 'table' or #Config.Nitro.stateBags == 0 then
            add('Config.Nitro.stateBags')
        else
            for index = 1, #Config.Nitro.stateBags do
                local value = Config.Nitro.stateBags[index]
                if type(value) ~= 'string' or value == '' or #value > 64 then
                    add(('Config.Nitro.stateBags[%d]'):format(index))
                end
            end
        end
    end

    if type(Config.VehicleDetails) ~= 'table' then
        add('Config.VehicleDetails')
    else
        if type(Config.VehicleDetails.enabled) ~= 'boolean' then
            add('Config.VehicleDetails.enabled')
        end
    end

    if type(Config.Seatbelt) ~= 'table' then
        add('Config.Seatbelt')
    else
        for _, key in ipairs({ 'enabled', 'builtIn', 'preventExit', 'sound' }) do
            if type(Config.Seatbelt[key]) ~= 'boolean' then
                add(('Config.Seatbelt.%s'):format(key))
            end
        end
        if type(Config.Seatbelt.defaultKey) ~= 'string'
            or Config.Seatbelt.defaultKey == ''
            or #Config.Seatbelt.defaultKey > 32
        then
            add('Config.Seatbelt.defaultKey')
        end
        for _, key in ipairs({ 'soundset', 'buckleSound', 'unbuckleSound' }) do
            local value = Config.Seatbelt[key]
            if type(value) ~= 'string' or value == '' or #value > 64 then
                add(('Config.Seatbelt.%s'):format(key))
            end
        end
        if not Hud.isOneOf(Config.Seatbelt.soundMode, { 'native', 'custom' }) then
            add('Config.Seatbelt.soundMode')
        end
        if not Hud.isNumberInRange(Config.Seatbelt.customVolume, 0, 1) then
            add('Config.Seatbelt.customVolume')
        end
        if type(Config.Seatbelt.customSounds) ~= 'table' then
            add('Config.Seatbelt.customSounds')
        else
            for _, key in ipairs({ 'buckle', 'unbuckle' }) do
                if not validCustomSoundPath(Config.Seatbelt.customSounds[key]) then
                    add(('Config.Seatbelt.customSounds.%s'):format(key))
                end
            end
        end
        if type(Config.Seatbelt.stateBags) ~= 'table' or #Config.Seatbelt.stateBags == 0 then
            add('Config.Seatbelt.stateBags')
        else
            for index = 1, #Config.Seatbelt.stateBags do
                local value = Config.Seatbelt.stateBags[index]
                if type(value) ~= 'string' or value == '' or #value > 64 then
                    add(('Config.Seatbelt.stateBags[%d]'):format(index))
                end
            end
        end
    end

    if type(Config.GearShiftSound) ~= 'table' then
        add('Config.GearShiftSound')
    else
        for _, key in ipairs({ 'enabled', 'sound' }) do
            if type(Config.GearShiftSound[key]) ~= 'boolean' then
                add(('Config.GearShiftSound.%s'):format(key))
            end
        end
        if not Hud.isNumberInRange(Config.GearShiftSound.customVolume, 0, 1) then
            add('Config.GearShiftSound.customVolume')
        end
        if not Hud.isNumberInRange(Config.GearShiftSound.minimumSpeed, 0, 500) then
            add('Config.GearShiftSound.minimumSpeed')
        end
        if not Hud.isNumberInRange(Config.GearShiftSound.cooldown, 0, 10000) then
            add('Config.GearShiftSound.cooldown')
        end
        if type(Config.GearShiftSound.customSounds) ~= 'table' then
            add('Config.GearShiftSound.customSounds')
        elseif Config.GearShiftSound.enabled and Config.GearShiftSound.sound then
            for _, key in ipairs({ 'up', 'down' }) do
                if not validCustomSoundPath(Config.GearShiftSound.customSounds[key]) then
                    add(('Config.GearShiftSound.customSounds.%s'):format(key))
                end
            end
        end
    end

    if type(Config.VehicleWarnings) ~= 'table' then
        add('Config.VehicleWarnings')
    else
        for _, key in ipairs({ 'enabled', 'sound' }) do
            if type(Config.VehicleWarnings[key]) ~= 'boolean' then
                add(('Config.VehicleWarnings.%s'):format(key))
            end
        end
        if not Hud.isNumberInRange(Config.VehicleWarnings.warningThreshold, 1, 99) then
            add('Config.VehicleWarnings.warningThreshold')
        end
        if not Hud.isNumberInRange(Config.VehicleWarnings.dangerThreshold, 0, 98)
            or (type(Config.VehicleWarnings.warningThreshold) == 'number'
                and type(Config.VehicleWarnings.dangerThreshold) == 'number'
                and Config.VehicleWarnings.dangerThreshold >= Config.VehicleWarnings.warningThreshold)
        then
            add('Config.VehicleWarnings.dangerThreshold')
        end
        if not Hud.isNumberInRange(Config.VehicleWarnings.criticalRepeatInterval, 10000, 600000) then
            add('Config.VehicleWarnings.criticalRepeatInterval')
        end
        for _, key in ipairs({ 'soundset', 'warningSound', 'dangerSound' }) do
            local value = Config.VehicleWarnings[key]
            if type(value) ~= 'string' or value == '' or #value > 64 then
                add(('Config.VehicleWarnings.%s'):format(key))
            end
        end
        if not Hud.isOneOf(Config.VehicleWarnings.soundMode, { 'native', 'custom' }) then
            add('Config.VehicleWarnings.soundMode')
        end
        if not Hud.isNumberInRange(Config.VehicleWarnings.customVolume, 0, 1) then
            add('Config.VehicleWarnings.customVolume')
        end
        if type(Config.VehicleWarnings.customSounds) ~= 'table' then
            add('Config.VehicleWarnings.customSounds')
        else
            for _, key in ipairs({ 'warning', 'danger' }) do
                if not validCustomSoundPath(Config.VehicleWarnings.customSounds[key]) then
                    add(('Config.VehicleWarnings.customSounds.%s'):format(key))
                end
            end
        end
    end

    if type(Config.VehicleCrashEffect) ~= 'table' then
        add('Config.VehicleCrashEffect')
    else
        if type(Config.VehicleCrashEffect.enabled) ~= 'boolean' then
            add('Config.VehicleCrashEffect.enabled')
        end
        if not Hud.isNumberInRange(Config.VehicleCrashEffect.minimumSpeed, 0, 500) then
            add('Config.VehicleCrashEffect.minimumSpeed')
        end
        if not Hud.isNumberInRange(Config.VehicleCrashEffect.speedDrop, 1, 300) then
            add('Config.VehicleCrashEffect.speedDrop')
        end
        if not Hud.isNumberInRange(Config.VehicleCrashEffect.bodyHealthLoss, 1, 1000) then
            add('Config.VehicleCrashEffect.bodyHealthLoss')
        end
        if not Hud.isNumberInRange(Config.VehicleCrashEffect.cooldown, 500, 60000) then
            add('Config.VehicleCrashEffect.cooldown')
        end
    end

    if type(Config.Minimap) ~= 'table' then
        add('Config.Minimap')
    else
        if not Hud.isOneOf(Config.Minimap.mode, { 'vehicle', 'always', 'never' }) then add('Config.Minimap.mode') end
        if type(Config.Minimap.hideNativeVitals) ~= 'boolean' then add('Config.Minimap.hideNativeVitals') end
        if not Hud.isNumberInRange(Config.Minimap.zoom, 0, 2000) then add('Config.Minimap.zoom') end
    end

    if type(Config.SafeZone) ~= 'table' then
        add('Config.SafeZone')
    else
        if type(Config.SafeZone.enabled) ~= 'boolean' then add('Config.SafeZone.enabled') end
        if not Hud.isNumberInRange(Config.SafeZone.maxInsetPercent, 0, 10) then add('Config.SafeZone.maxInsetPercent') end
    end

    if type(Config.DefaultSettings) ~= 'table' then
        add('Config.DefaultSettings')
    else
        if type(Config.DefaultSettings.enabled) ~= 'boolean' then add('Config.DefaultSettings.enabled') end
        if type(Config.DefaultSettings.location) ~= 'boolean' then add('Config.DefaultSettings.location') end
        if type(Config.DefaultSettings.minimal) ~= 'boolean' then add('Config.DefaultSettings.minimal') end
        if type(Config.DefaultSettings.raceMode) ~= 'boolean' then add('Config.DefaultSettings.raceMode') end
        if not Hud.isPosition(Config.DefaultSettings.position) then add('Config.DefaultSettings.position') end
        if type(Config.DefaultSettings.palette) ~= 'string' or not Hud.palettes[Config.DefaultSettings.palette] then
            add('Config.DefaultSettings.palette')
        end
        if not Hud.isNumberInRange(Config.DefaultSettings.opacity, 40, 100) then
            add('Config.DefaultSettings.opacity')
        end
    end

    return #errors == 0, errors
end
