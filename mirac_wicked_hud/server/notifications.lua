local validTypes = {
    inform = 'inform', info = 'inform', primary = 'inform',
    success = 'success', warning = 'warning', error = 'error'
}

local function ownerName()
    local owner = GetInvokingResource() or Hud.resource
    owner = Hud.safeString(owner, 64, Hud.resource)
    if owner == '' then owner = Hud.resource end
    return owner:gsub('[^%w_.-]', '_')
end

local function notifyPlayer(playerSource, data)
    playerSource = Hud.isPlayerSource(playerSource)
    if not playerSource or type(data) ~= 'table' then return false end

    local notificationType = validTypes[string.lower(Hud.safeString(data.type, 16, 'inform'))] or 'inform'
    local payload = {
        _hudOwner = ownerName(),
        id = data.id,
        title = Hud.safeString(data.title, 80, 'HUD'),
        description = Hud.safeString(data.description, 240, ''),
        type = notificationType,
        duration = Hud.round(Hud.clamp(
            data.duration,
            Config.Notifications.minDuration,
            Config.Notifications.maxDuration
        ) or Config.Notifications.defaultDuration),
        icon = Hud.safeString(data.icon, 32, ''),
        iconColor = Hud.safeString(data.iconColor, 7, ''),
        restartDuration = data.restartDuration == true
    }

    TriggerClientEvent(Hud.events.notify, playerSource, payload)
    return true
end

local function notifyPlayerQB(playerSource, text, notificationType, duration, title)
    local data = type(text) == 'table' and text or { text = title, caption = text }
    return notifyPlayer(playerSource, {
        id = data.id,
        title = data.text or title or 'HUD',
        description = data.caption or (type(text) == 'string' and text or ''),
        type = notificationType,
        duration = duration,
        icon = data.icon,
        iconColor = data.iconColor
    })
end

local function notifyPlayerESX(playerSource, message, notificationType, duration, title)
    return notifyPlayer(playerSource, {
        title = title or 'HUD', description = message,
        type = notificationType, duration = duration
    })
end

AddEventHandler(Hud.events.serverNotify, notifyPlayer)
if Config.Notifications.compatibilityFormats.qb then
    AddEventHandler(('%s:server:notify:qb'):format(Hud.resource), notifyPlayerQB)
end
if Config.Notifications.compatibilityFormats.esx then
    AddEventHandler(('%s:server:notify:esx'):format(Hud.resource), notifyPlayerESX)
end

exports('notifyPlayer', notifyPlayer)
exports('notifyPlayerQB', notifyPlayerQB)
exports('notifyPlayerESX', notifyPlayerESX)
