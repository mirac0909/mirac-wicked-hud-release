Hud.state = Hud.state or { loaded = false, citizenid = nil }
Hud.settings = Hud.settings or {}

local resource = Hud.resource
local kvpPrefix = ('%s:'):format(resource)
local positionAliases = {
    sagust = 'top-right',
    ['top-right'] = 'top-right',
    sol = 'top-left',
    solust = 'top-left',
    ['top-left'] = 'top-left',
    sagalt = 'bottom-right',
    ['bottom-right'] = 'bottom-right'
}
local positionOrder = { 'top-right', 'top-left', 'bottom-right' }
local lastSafeZoneInset = nil

local function readBoolean(name, fallback)
    local value = GetResourceKvpString(kvpPrefix .. name)
    if value == nil then return fallback end
    if value == 'true' then return true end
    if value == 'false' then return false end
    return fallback
end

local function readPosition()
    local value = GetResourceKvpString(kvpPrefix .. 'position')
    return Hud.isPosition(value) and value or Config.DefaultSettings.position
end

local function readPalette()
    local value = GetResourceKvpString(kvpPrefix .. 'palette')
    return type(value) == 'string' and Hud.palettes[value] and value or Config.DefaultSettings.palette
end

local function normalizeOpacity(value)
    value = Hud.clamp(value, 40, 100)
    if not value then return nil end
    return math.floor((value + 2.5) / 5) * 5
end

local function readOpacity()
    return normalizeOpacity(GetResourceKvpString(kvpPrefix .. 'opacity')) or Config.DefaultSettings.opacity
end

Hud.settings.enabled = readBoolean('enabled', Config.DefaultSettings.enabled)
Hud.settings.location = readBoolean('location', Config.DefaultSettings.location)
Hud.settings.minimal = readBoolean('minimalMode', Config.DefaultSettings.minimal)
Hud.settings.position = readPosition()
Hud.settings.palette = readPalette()
Hud.settings.opacity = readOpacity()
Hud.settings.open = false

function Hud.getSettingsState()
    return {
        enabled = Hud.settings.enabled,
        location = Hud.settings.location,
        minimal = Hud.settings.minimal,
        position = Hud.settings.position,
        palette = Hud.settings.palette,
        opacity = Hud.settings.opacity
    }
end

function Hud.getNuiLocale()
    local strings = {}
    for index = 1, #Hud.nuiLocaleKeys do
        local key = Hud.nuiLocaleKeys[index]
        strings[key] = locale(('nui_%s'):format(key))
    end
    return strings
end

function Hud.sendLocale()
    Hud.sendNui(Hud.actions.locale, {
        language = GetConvar('ox:locale', 'en'),
        strings = Hud.getNuiLocale()
    })
end

local function safeZonePayload()
    if not Config.SafeZone.enabled then return { x = 0, y = 0 } end

    local safeZone = tonumber(GetSafeZoneSize()) or 1.0
    local inset = Hud.clamp((1.0 - safeZone) * 50.0, 0, Config.SafeZone.maxInsetPercent) or 0
    inset = math.floor(inset * 100 + 0.5) / 100
    return { x = inset, y = inset }
end

function Hud.getLayoutMetrics()
    local safeZone = safeZonePayload()
    return {
        position = Hud.settings.position,
        safeZoneX = safeZone.x,
        safeZoneY = safeZone.y
    }
end

function Hud.sendConfig()
    local safeZone = safeZonePayload()
    lastSafeZoneInset = safeZone.x

    Hud.sendNui(Hud.actions.config, {
        minimalMode = Hud.settings.minimal,
        locationVisible = Hud.settings.location,
        hudPosition = Hud.settings.position,
        speedUnit = Config.SpeedUnit,
        palette = Hud.settings.palette,
        opacity = Hud.settings.opacity,
        identity = {
            serverLabel = Config.Identity.serverLabel,
            permanentIdMaxLength = Config.Identity.permanentIdMaxLength
        },
        components = Hud.copy(Config.Components),
        vehicleWarnings = {
            warningThreshold = Config.VehicleWarnings.warningThreshold,
            dangerThreshold = Config.VehicleWarnings.dangerThreshold
        },
        vehicleDetails = {
            enabled = Config.VehicleDetails.enabled
        },
        notificationSafetyLimit = Config.Notifications.hardSafetyLimit,
        safeZone = safeZone
    })

end

function Hud.syncSettingsNui()
    if not Hud.settings.open then return end
    Hud.sendNui(Hud.actions.settings, { open = true, state = Hud.getSettingsState() })
end

function Hud.shouldShow()
    if not Hud.state.loaded or not Hud.settings.enabled then return false end
    if Config.Client.showOnPause then return true end
    return not IsPauseMenuActive()
end

function Hud.sendVisibility(force, panelsVisible)
    local pauseAllowsHud = Config.Client.showOnPause or not IsPauseMenuActive()
    local loaded = Hud.state.loaded and pauseAllowsHud
    if type(panelsVisible) ~= 'boolean' then panelsVisible = Hud.shouldShow() end

    Hud.sendNui(Hud.actions.visibility, {
        panelsVisible = panelsVisible,
        notificationsVisible = loaded
            and Config.Notifications.enabled
            and (Hud.settings.enabled or Config.Notifications.showWhenHudHidden),
        textUiVisible = loaded
            and Config.TextUI.enabled
            and (Hud.settings.enabled or Config.TextUI.showWhenHudHidden)
    }, force == true)
end

local notificationTypes = {
    inform = 'inform', info = 'inform', primary = 'inform',
    success = 'success', warning = 'warning', error = 'error'
}
local allowedIcons = {
    ['circle-info'] = true, ['circle-check'] = true,
    ['triangle-exclamation'] = true, ['circle-xmark'] = true,
    hand = true
}
local defaultIcons = {
    inform = 'circle-info', success = 'circle-check',
    warning = 'triangle-exclamation', error = 'circle-xmark'
}
local notificationSequence = 0
local textUiEntries = {}
local textUiSequence = 0

local function ownerName(explicitOwner)
    local owner = explicitOwner or GetInvokingResource() or resource
    owner = Hud.safeString(owner, 64, resource)
    if owner == '' then owner = resource end
    return owner:gsub('[^%w_.-]', '_')
end

local function scopedKey(owner, id, prefix)
    if type(id) == 'number' then id = tostring(id) end
    local safeId = Hud.safeString(id, 80, 'default')
    if safeId == '' then safeId = 'default' end
    return ('%s:%s:%s'):format(owner, prefix, safeId:gsub('[^%w_.-]', '_'))
end

local function normalizeType(value)
    return notificationTypes[string.lower(Hud.safeString(value, 16, 'inform'))] or 'inform'
end

local function normalizeIcon(icon, notificationType)
    icon = Hud.safeString(icon, 32, '')
    return allowedIcons[icon] and icon or defaultIcons[notificationType]
end

local function normalizeColor(value)
    value = Hud.safeString(value, 7, '')
    return value:match('^#%x%x%x%x%x%x$') and value or nil
end

function Hud.notify(data, explicitOwner)
    if not Config.Notifications.enabled or type(data) ~= 'table' then return false end

    local owner = ownerName(explicitOwner or data._hudOwner)
    local notificationType = normalizeType(data.type)
    local publicId = data.id
    if publicId == nil or tostring(publicId) == '' then
        notificationSequence = notificationSequence + 1
        publicId = ('anonymous-%d'):format(notificationSequence)
    end
    local notification = {
        key = scopedKey(owner, publicId, 'notification'),
        id = Hud.safeString(type(publicId) == 'number' and tostring(publicId) or publicId, 80, 'default'),
        title = Hud.safeString(data.title, 80, 'HUD'),
        description = Hud.safeString(data.description, 240, ''),
        type = notificationType,
        duration = Hud.round(Hud.clamp(
            data.duration,
            Config.Notifications.minDuration,
            Config.Notifications.maxDuration
        ) or Config.Notifications.defaultDuration),
        icon = normalizeIcon(data.icon, notificationType),
        iconColor = normalizeColor(data.iconColor),
        restartDuration = data.restartDuration == true
    }

    Hud.sendNui(Hud.actions.notification, notification, true)
    return true
end

local function renderTextUi()
    local active
    for _, entry in pairs(textUiEntries) do
        if not active or entry.order > active.order then active = entry end
    end
    Hud.sendNui(Hud.actions.textUi, active and {
        visible = true, key = active.key, text = active.text,
        icon = active.icon, iconColor = active.iconColor
    } or { visible = false }, true)
end

function Hud.showTextUI(id, text, options, explicitOwner)
    if not Config.TextUI.enabled then return false end
    options = type(options) == 'table' and options or {}
    local owner = ownerName(explicitOwner)
    local key = scopedKey(owner, id, 'textui')
    textUiSequence = textUiSequence + 1
    textUiEntries[key] = {
        key = key, owner = owner, order = textUiSequence,
        text = Hud.safeString(text, 180, ''),
        icon = normalizeIcon(options.icon or 'hand', 'inform'),
        iconColor = normalizeColor(options.iconColor)
    }
    renderTextUi()
    return true
end

function Hud.hideTextUI(id, explicitOwner)
    local key = scopedKey(ownerName(explicitOwner), id, 'textui')
    if not textUiEntries[key] then return false end
    textUiEntries[key] = nil
    renderTextUi()
    return true
end

function Hud.isTextUIOpen(id, explicitOwner)
    return textUiEntries[scopedKey(ownerName(explicitOwner), id, 'textui')] ~= nil
end

function Hud.feedback(data)
    if Config.Notifications.enabled and Config.Notifications.useHudForInternal then
        return Hud.notify(data)
    end

    lib.notify(data)
    return true
end

function Hud.setVisibility(enabled, showNotification)
    Hud.settings.enabled = enabled == true
    SetResourceKvp(kvpPrefix .. 'enabled', Hud.settings.enabled and 'true' or 'false')
    Hud.sendVisibility(true)
    Hud.syncSettingsNui()

    if showNotification then
        Hud.feedback({
            title = 'HUD',
            description = locale(Hud.settings.enabled and 'hud_enabled' or 'hud_disabled'),
            type = 'inform'
        })
    end
end

function Hud.setMinimal(enabled, showNotification)
    Hud.settings.minimal = enabled == true
    SetResourceKvp(kvpPrefix .. 'minimalMode', Hud.settings.minimal and 'true' or 'false')
    if Hud.settings.minimal then Hud.statusRevealUntil = 0 end
    Hud.sendConfig()
    Hud.syncSettingsNui()

    if showNotification then
        Hud.feedback({
            title = 'HUD',
            description = locale(Hud.settings.minimal and 'minimal_enabled' or 'minimal_disabled'),
            type = 'inform'
        })
    end
end

function Hud.setLocationVisible(enabled)
    Hud.settings.location = enabled == true
    SetResourceKvp(kvpPrefix .. 'location', Hud.settings.location and 'true' or 'false')
    Hud.sendConfig()
    Hud.syncSettingsNui()
end

function Hud.setPosition(position, showNotification)
    if not Hud.isPosition(position) then return false end

    Hud.settings.position = position
    SetResourceKvp(kvpPrefix .. 'position', position)
    Hud.sendConfig()
    Hud.syncSettingsNui()

    if showNotification then
        Hud.feedback({ title = 'HUD', description = locale('position_changed'), type = 'inform' })
    end

    return true
end


function Hud.setPalette(palette)
    if type(palette) ~= 'string' or not Hud.palettes[palette] then return false end

    Hud.settings.palette = palette
    SetResourceKvp(kvpPrefix .. 'palette', palette)
    Hud.sendConfig()
    Hud.syncSettingsNui()
    return true
end

function Hud.setOpacity(opacity)
    opacity = normalizeOpacity(opacity)
    if not opacity then return false end

    Hud.settings.opacity = opacity
    SetResourceKvp(kvpPrefix .. 'opacity', tostring(Hud.settings.opacity))
    Hud.sendConfig()
    Hud.syncSettingsNui()
    return true
end

function Hud.closeSettings()
    Hud.settings.open = false
    SetNuiFocus(false, false)
    Hud.sendNui(Hud.actions.settings, { open = false, state = Hud.getSettingsState() })
end

function Hud.openSettings()
    if not Hud.state.loaded then
        Hud.feedback({ title = 'HUD', description = locale('player_not_loaded'), type = 'error' })
        return
    end

    Hud.settings.open = true
    SetNuiFocus(true, true)
    Hud.sendNui(Hud.actions.settings, { open = true, state = Hud.getSettingsState() })
end

function Hud.resetSettings(showNotification)
    -- Presentation-only reset. Character vitals and framework metadata are
    -- intentionally left untouched.
    DeleteResourceKvp(kvpPrefix .. 'enabled')
    DeleteResourceKvp(kvpPrefix .. 'location')
    DeleteResourceKvp(kvpPrefix .. 'minimalMode')
    DeleteResourceKvp(kvpPrefix .. 'position')
    DeleteResourceKvp(kvpPrefix .. 'palette')
    DeleteResourceKvp(kvpPrefix .. 'opacity')

    Hud.settings.enabled = Config.DefaultSettings.enabled
    Hud.settings.location = Config.DefaultSettings.location
    Hud.settings.minimal = Config.DefaultSettings.minimal
    Hud.settings.position = Config.DefaultSettings.position
    Hud.settings.palette = Config.DefaultSettings.palette
    Hud.settings.opacity = Config.DefaultSettings.opacity
    Hud.statusRevealUntil = 0

    Hud.sendConfig()
    Hud.sendVisibility(true)
    Hud.syncSettingsNui()

    if showNotification then
        Hud.feedback({ title = 'HUD', description = locale('settings_reset'), type = 'success' })
    end
end

function Hud.refreshLocal(showNotification)
    -- Repairs presentation state without changing the player's saved choices
    -- or requesting a character/framework reload.
    Hud.settings.open = false
    Hud.statusRevealUntil = 0
    SetNuiFocus(false, false)
    Hud.clearNuiState()
    Hud.sendLocale()
    Hud.sendConfig()
    Hud.sendVisibility(true)
    Hud.syncSettingsNui()

    if Hud.vehicle and Hud.vehicle.reapplyNativeHud then
        Hud.vehicle.reapplyNativeHud(90)
    end

    if showNotification then
        Hud.feedback({
            title = 'HUD',
            description = locale('hud_refreshed'),
            type = 'success'
        })
    end

    return true
end

RegisterNUICallback('hudSettingsAction', function(data, callback)
    data = type(data) == 'table' and data or {}
    local action = Hud.safeString(data.action, 32, '')
    local ok = true

    if action == 'close' then
        Hud.closeSettings()
    elseif action == 'toggleVisibility' then
        Hud.setVisibility(not Hud.settings.enabled, false)
    elseif action == 'toggleLocation' then
        Hud.setLocationVisible(not Hud.settings.location)
    elseif action == 'setMode' then
        if data.value ~= 'normal' and data.value ~= 'minimal' then
            ok = false
        else
            Hud.setMinimal(data.value == 'minimal', false)
        end
    elseif action == 'setPosition' then
        ok = Hud.setPosition(data.value, false)
    elseif action == 'setPalette' then
        ok = Hud.setPalette(data.value)
    elseif action == 'setOpacity' then
        ok = Hud.setOpacity(data.value)
    elseif action == 'preview' then
        if not Hud.settings.enabled then Hud.setVisibility(true, false) end
        Hud.statusRevealUntil = GetGameTimer() + Config.Client.showAllStatusesDuration
        Hud.closeSettings()
    else
        ok = false
    end

    callback({ ok = ok })
end)

RegisterCommand('hudreset', function() Hud.resetSettings(true) end, false)
RegisterCommand('hudyenile', function() Hud.refreshLocal(true) end, false)
RegisterCommand('hudrefresh', function() Hud.refreshLocal(true) end, false)
RegisterCommand('hudayar', function() Hud.openSettings() end, false)
RegisterCommand('hudsettings', function() Hud.openSettings() end, false)
RegisterCommand('hud', function() Hud.setVisibility(not Hud.settings.enabled, true) end, false)
RegisterCommand('hudminimal', function() Hud.setMinimal(not Hud.settings.minimal, true) end, false)
local function positionCommand(_, args)
    local requested = args[1] and positionAliases[string.lower(args[1])] or nil
    if args[1] and not requested then
        Hud.feedback({ title = 'HUD', description = locale('invalid_position'), type = 'error' })
        return
    end

    if not requested then
        for index = 1, #positionOrder do
            if positionOrder[index] == Hud.settings.position then
                requested = positionOrder[(index % #positionOrder) + 1]
                break
            end
        end
    end

    Hud.setPosition(requested or Config.DefaultSettings.position, true)
end

RegisterCommand('hudkonum', positionCommand, false)
RegisterCommand('hudposition', positionCommand, false)

local keybindName = resource:gsub('[^%w_]', '_')
lib.addKeybind({
    name = ('%s_toggle'):format(keybindName),
    description = locale('toggle_hud'),
    defaultKey = Config.Keybinds.toggle,
    onPressed = function() Hud.setVisibility(not Hud.settings.enabled, true) end
})

lib.addKeybind({
    name = ('%s_peek'):format(keybindName),
    description = locale('peek_status'),
    defaultKey = Config.Keybinds.peek,
    onPressed = function()
        if Hud.settings.enabled and Hud.state.loaded then
            Hud.statusRevealUntil = GetGameTimer() + Config.Client.showAllStatusesDuration
        end
    end
})

CreateThread(function()
    while true do
        Wait(2000)
        if Config.SafeZone.enabled and Hud.state.loaded then
            local safeZone = safeZonePayload()
            if safeZone.x ~= lastSafeZoneInset then Hud.sendConfig() end
        end
    end
end)

RegisterNetEvent(Hud.events.notify, function(data) Hud.notify(data, type(data) == 'table' and data._hudOwner or nil) end)
AddEventHandler(('%s:notify'):format(resource), function(data) Hud.notify(data) end)

local function qbNotification(text, notificationType, duration, title, owner)
    local data = type(text) == 'table' and text or { text = title, caption = text }
    return Hud.notify({
        id = data.id,
        title = data.text or title or 'HUD',
        description = data.caption or (type(text) == 'string' and text or ''),
        type = notificationType,
        duration = duration,
        icon = data.icon,
        iconColor = data.iconColor
    }, owner)
end

local function esxNotification(message, notificationType, duration, title, owner)
    return Hud.notify({
        title = title or 'HUD', description = message,
        type = notificationType, duration = duration
    }, owner)
end

if Config.Notifications.compatibilityFormats.qb then
    RegisterNetEvent(('%s:notify:qb'):format(resource), function(text, notificationType, duration, title)
        qbNotification(text, notificationType, duration, title, GetInvokingResource())
    end)
end
if Config.Notifications.compatibilityFormats.esx then
    RegisterNetEvent(('%s:notify:esx'):format(resource), function(message, notificationType, duration, title)
        esxNotification(message, notificationType, duration, title, GetInvokingResource())
    end)
end

local notificationBridgeEvents = type(Config.Notifications) == 'table'
    and type(Config.Notifications.bridgeEvents) == 'table'
    and Config.Notifications.bridgeEvents
    or {}

for index = 1, #notificationBridgeEvents do
    local eventName = notificationBridgeEvents[index]
    if type(eventName) == 'string' and eventName ~= '' then
        RegisterNetEvent(eventName, function(data, description, notificationType, duration)
            if type(data) == 'table' then
                Hud.notify(data, ('bridge-%s'):format(eventName))
                return
            end

            Hud.notify({
                title = data,
                description = description,
                type = notificationType,
                duration = duration
            }, ('bridge-%s'):format(eventName))
        end)
    end
end

AddEventHandler('onClientResourceStop', function(resourceName)
    local changed = false
    for key, entry in pairs(textUiEntries) do
        if entry.owner == resourceName then
            textUiEntries[key] = nil
            changed = true
        end
    end
    if changed then renderTextUi() end
end)

exports('getHudPosition', function() return Hud.settings.position end)
exports('getHudPalette', function() return Hud.settings.palette end)
exports('getHudOpacity', function() return Hud.settings.opacity end)
exports('getHudLayoutMetrics', function() return Hud.getLayoutMetrics() end)
exports('isHudVisible', function() return Hud.settings.enabled end)
exports('setHudVisible', function(enabled) Hud.setVisibility(enabled == true, false) end)
exports('setHudPalette', function(palette) return Hud.setPalette(palette) end)
exports('setHudOpacity', function(opacity) return Hud.setOpacity(opacity) end)
exports('notify', function(data) return Hud.notify(data) end)
exports('notifyQB', function(text, notificationType, duration, title)
    return qbNotification(text, notificationType, duration, title, GetInvokingResource())
end)
exports('notifyESX', function(message, notificationType, duration, title)
    return esxNotification(message, notificationType, duration, title, GetInvokingResource())
end)
exports('showTextUI', function(id, text, options) return Hud.showTextUI(id, text, options) end)
exports('hideTextUI', function(id) return Hud.hideTextUI(id) end)
exports('isTextUIOpen', function(id) return Hud.isTextUIOpen(id) end)
