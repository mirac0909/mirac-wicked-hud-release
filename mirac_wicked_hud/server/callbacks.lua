local requestState = {}

local function clearRequestState(source)
    requestState[tonumber(source)] = nil
end

lib.callback.register(Hud.events.initialData, function(source)
    source = tonumber(source)
    if not source or source < 1 then return nil end

    local now = GetGameTimer()
    local cached = requestState[source]

    -- This is both a short cache and a real callback throttle: repeated calls
    -- inside the window do not touch qbx_core again.
    if cached and now - cached.timestamp < Config.Server.initialDataCooldown then
        return cached.data and Hud.copy(cached.data) or nil
    end

    requestState[source] = { timestamp = now, data = nil }

    local data = Hud.Qbox.getInitialData(source)
    if not data then return nil end

    requestState[source] = {
        timestamp = now,
        data = Hud.copy(data)
    }

    return data
end)

AddEventHandler('playerDropped', function()
    clearRequestState(source)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    clearRequestState(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == Hud.resource then requestState = {} end
end)
