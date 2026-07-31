local nuiReady = false
local stateCache = {}
local messageCache = {}
local pendingMessages = {}
local queuedNotifications = {}

local function debugMessage(direction, payload)
    if not Config.Client.nuiDebug then return end
    lib.print.debug(('[%s] NUI %s: %s'):format(Hud.resource, direction, json.encode(payload)))
end

local function post(payload)
    debugMessage('send', payload)
    SendNUIMessage(payload)
end

local function queueNotification(payload)
    local configuredLimit = type(Config.Notifications) == 'table'
        and Config.Notifications.hardSafetyLimit
        or 100
    local maximum = math.floor(Hud.clamp(configuredLimit, 10, 500) or 100)

    if #queuedNotifications >= maximum then
        table.remove(queuedNotifications, 1)
    end

    queuedNotifications[#queuedNotifications + 1] = payload
end

local function diffAndMerge(target, patch, force)
    local changes = {}
    local changed = false

    for key, value in pairs(patch) do
        if value ~= nil then
            local current = target[key]

            if not force and type(value) == 'table' and type(current) == 'table' then
                local nestedChanges, nestedChanged = diffAndMerge(current, value, false)
                if nestedChanged then
                    changes[key] = nestedChanges
                    changed = true
                end
            elseif force or not Hud.sameValue(current, value) then
                target[key] = Hud.copy(value)
                changes[key] = Hud.copy(value)
                changed = true
            end
        end
    end

    return changes, changed
end

function Hud.isNuiReady()
    return nuiReady
end

function Hud.getNuiState()
    return Hud.copy(stateCache)
end

function Hud.sendNuiUpdate(patch, force)
    if type(patch) ~= 'table' then return false end

    local changes, changed = diffAndMerge(stateCache, patch, force == true)
    if not changed then return false end
    if not nuiReady then return true end

    post({ action = Hud.actions.update, data = changes })
    return true
end

function Hud.sendNui(action, data, force)
    if action == Hud.actions.update then
        return Hud.sendNuiUpdate(data, force)
    end
    if type(action) ~= 'string' or type(data) ~= 'table' then return false end

    if action == Hud.actions.notification
        or action == Hud.actions.notificationUpdate
        or action == Hud.actions.notificationRemove
    then
        local payload = { action = action, data = Hud.copy(data) }
        if nuiReady then
            post(payload)
        else
            queueNotification(payload)
        end
        return true
    end

    if not force and Hud.sameValue(messageCache[action], data) then return false end
    messageCache[action] = Hud.copy(data)

    local payload = { action = action, data = Hud.copy(data) }
    if not nuiReady then
        pendingMessages[action] = payload
        return true
    end

    post(payload)
    return true
end

function Hud.clearNuiState()
    stateCache = {}
    messageCache = {}
    pendingMessages = {}
    queuedNotifications = {}

    if nuiReady then
        post({ action = Hud.actions.reset, data = {} })
    end
end

function Hud.resetNui()
    nuiReady = false
    stateCache = {}
    messageCache = {}
    pendingMessages = {}
    queuedNotifications = {}
end

function Hud.setNuiReady()
    -- Chromium can reload the NUI page without restarting the Lua runtime.
    -- Replay the cached persistent messages so the replacement page receives
    -- the same locale, config, visibility, settings and TextUI state.
    if nuiReady then
        for action, data in pairs(messageCache) do
            pendingMessages[action] = {
                action = action,
                data = Hud.copy(data)
            }
        end
    end

    nuiReady = true

    local orderedActions = {
        Hud.actions.locale,
        Hud.actions.config,
        Hud.actions.visibility,
        Hud.actions.settings
    }

    for index = 1, #orderedActions do
        local action = orderedActions[index]
        local payload = pendingMessages[action]
        if payload then post(payload) end
        pendingMessages[action] = nil
    end

    for _, payload in pairs(pendingMessages) do post(payload) end
    pendingMessages = {}

    if next(stateCache) then
        post({ action = Hud.actions.update, data = Hud.copy(stateCache) })
    end

    for index = 1, #queuedNotifications do post(queuedNotifications[index]) end
    queuedNotifications = {}
end

RegisterNUICallback('hudReady', function(_, callback)
    Hud.setNuiReady()
    callback({ ok = true })
end)
