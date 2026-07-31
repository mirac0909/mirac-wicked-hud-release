Hud.player = Hud.player or {
    metadata = {},
    street = '',
    area = '',
    lastLocationUpdate = 0
}

local activeLanguage = GetConvar('ox:locale', 'en'):lower()
local directions = activeLanguage:sub(1, 2) == 'tr'
    and { 'K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB' }
    or { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }
local watchedMetadata = {}

local function localPlayerBagName()
    return ('player:%s'):format(GetPlayerServerId(cache.playerId))
end

local function statusValue(name)
    local value = Hud.clamp(Hud.player.metadata[name], 0, 100)
    return value and Hud.round(value) or false
end

local function metadataPatch()
    return {
        hunger = statusValue('hunger'),
        thirst = statusValue('thirst')
    }
end

local function syncMetadataFromState(initialMetadata)
    initialMetadata = type(initialMetadata) == 'table' and initialMetadata or {}
    local state = LocalPlayer.state

    for logicalName, stateKey in pairs(Config.Metadata) do
        local value = state[stateKey]
        if value == nil then value = initialMetadata[logicalName] end
        Hud.player.metadata[logicalName] = Hud.clamp(value, 0, 100)
    end

    Hud.sendNuiUpdate(metadataPatch())
end

local function updateLocation(ped)
    local now = GetGameTimer()
    if now - Hud.player.lastLocationUpdate < Config.Client.locationUpdateInterval then return end
    Hud.player.lastLocationUpdate = now

    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local primary = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or ''
    local crossing = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''

    Hud.player.street = crossing ~= '' and ('%s / %s'):format(primary, crossing) or primary

    local zone = GetNameOfZone(coords.x, coords.y, coords.z)
    local label = zone and GetLabelText(zone) or ''
    Hud.player.area = label ~= 'NULL' and label or ''
end

local function compassFromHeading(heading)
    local index = math.floor(((heading + 22.5) % 360) / 45) + 1
    return directions[index]
end

function Hud.player.setIdentityIds(data)
    data = type(data) == 'table' and data or {}
    local temporaryId = Hud.numericString(
        data.temporaryId or data.serverId or GetPlayerServerId(cache.playerId),
        10,
        '0'
    )
    local permanentId = data.permanentId or data.citizenid or '0'

    Hud.sendNuiUpdate({
        temporaryId = temporaryId,
        permanentId = Hud.numericString(permanentId, Config.Identity.permanentIdMaxLength, '0')
    })
end

function Hud.player.setInitialData(data)
    data = type(data) == 'table' and data or {}
    syncMetadataFromState(data.metadata)
    Hud.player.setIdentityIds(data)

    Hud.sendNuiUpdate({
        street = Hud.player.street,
        area = Hud.player.area
    })
end

function Hud.player.updateFrameworkData(snapshot)
    if type(snapshot) ~= 'table' then return end
    local metadata = type(snapshot.metadata) == 'table' and snapshot.metadata or {}
    local state = LocalPlayer.state
    local changed = false

    for logicalName, stateKey in pairs(Config.Metadata) do
        if state[stateKey] == nil then
            local value = Hud.clamp(metadata[logicalName], 0, 100)
            if Hud.player.metadata[logicalName] ~= value then
                Hud.player.metadata[logicalName] = value
                changed = true
            end
        end
    end

    if changed then Hud.sendNuiUpdate(metadataPatch()) end
end

function Hud.player.clear()
    Hud.player.metadata = {}
    Hud.player.street = ''
    Hud.player.area = ''
    Hud.player.lastLocationUpdate = 0
end

RegisterNetEvent(('%s:identity:set'):format(Hud.resource), function(data)
    Hud.player.setIdentityIds(data)
end)

exports('setIdentityIds', function(data)
    Hud.player.setIdentityIds(data)
end)

for logicalName, stateKey in pairs(Config.Metadata) do
    local logicalNames = watchedMetadata[stateKey]
    if not logicalNames then
        logicalNames = {}
        watchedMetadata[stateKey] = logicalNames
        AddStateBagChangeHandler(stateKey, nil, function(bagName, _, value)
            if bagName ~= localPlayerBagName() then return end

            local normalized = Hud.clamp(value, 0, 100)
            for index = 1, #logicalNames do
                Hud.player.metadata[logicalNames[index]] = normalized
            end

            if Hud.state.loaded then Hud.sendNuiUpdate(metadataPatch()) end
        end)
    end
    logicalNames[#logicalNames + 1] = logicalName
end

CreateThread(function()
    while true do
        if not Hud.shouldShow() then
            Hud.sendVisibility(false, false)
            Wait(Config.Client.hiddenUpdateInterval)
        else
            local ped = cache.ped
            if not ped or ped == 0 or not DoesEntityExist(ped) then
                Hud.sendVisibility()
                Wait(Config.Client.hiddenUpdateInterval)
            else
                updateLocation(ped)

                local currentHealth = GetEntityHealth(ped)
                local maximumHealth = math.max(GetEntityMaxHealth(ped) - 100, 1)
                local health = IsEntityDead(ped) and 0 or ((currentHealth - 100) / maximumHealth) * 100
                local hours = GetClockHours()
                local minutes = GetClockMinutes()
                local oxygen = false

                if Config.Oxygen.enabled and IsPedSwimmingUnderWater(ped) then
                    local remaining = GetPlayerUnderwaterTimeRemaining(cache.playerId)
                    oxygen = Hud.round(Hud.clamp((remaining / Config.Oxygen.maxSeconds) * 100, 0, 100) or 0)
                end

                Hud.sendVisibility(false, true)
                Hud.sendNuiUpdate({
                    health = Hud.round(Hud.clamp(health, 0, 100) or 0),
                    armour = Hud.round(Hud.clamp(GetPedArmour(ped), 0, 100) or 0),
                    stamina = Hud.round(Hud.clamp(100 - GetPlayerSprintStaminaRemaining(cache.playerId), 0, 100) or 0),
                    oxygen = oxygen,
                    talking = Hud.Voice.isTalking(),
                    voiceMode = Hud.Voice.getMode(),
                    time = ('%02d:%02d'):format(hours, minutes),
                    compass = compassFromHeading(GetEntityHeading(ped)),
                    street = Hud.player.street,
                    area = Hud.player.area,
                    showAllStatuses = GetGameTimer() < (Hud.statusRevealUntil or 0)
                })

                Wait(Config.Client.playerUpdateInterval)
            end
        end
    end
end)
