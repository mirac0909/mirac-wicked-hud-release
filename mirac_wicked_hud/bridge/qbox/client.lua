Hud.Qbox = Hud.Qbox or {}

local function getPlayerData()
    if not QBX or type(QBX.PlayerData) ~= 'table' then return {} end
    return QBX.PlayerData
end

function Hud.Qbox.getPlayerData()
    return getPlayerData()
end

function Hud.Qbox.isLoggedIn()
    local data = getPlayerData()
    return type(data.citizenid) == 'string' and data.citizenid ~= ''
end

function Hud.Qbox.getCitizenId()
    local data = getPlayerData()
    return type(data.citizenid) == 'string' and data.citizenid or nil
end

-- Keep client framework snapshots intentionally small. The HUD only needs
-- character identity for lifecycle checks and the metadata it actually renders.
function Hud.Qbox.getClientSnapshot()
    local data = getPlayerData()
    local metadata = type(data.metadata) == 'table' and data.metadata or {}

    return {
        citizenid = data.citizenid,
        metadata = {
            hunger = metadata[Config.Metadata.hunger],
            thirst = metadata[Config.Metadata.thirst]
        }
    }
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent(Hud.events.playerLoaded, Hud.Qbox.getClientSnapshot())
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    TriggerEvent(Hud.events.playerUnloaded)
end)

AddEventHandler('QBCore:Player:SetPlayerData', function(value)
    if type(value) ~= 'table' then return end
    TriggerEvent(Hud.events.playerDataChanged, Hud.Qbox.getClientSnapshot())
end)
