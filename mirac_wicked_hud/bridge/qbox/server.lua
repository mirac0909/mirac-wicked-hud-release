Hud.Qbox = Hud.Qbox or {}

function Hud.Qbox.getPlayer(source)
    source = tonumber(source)
    if not source then return nil end
    return exports.qbx_core:GetPlayer(source)
end

function Hud.Qbox.getInitialData(source)
    local player = Hud.Qbox.getPlayer(source)
    if not player or type(player.PlayerData) ~= 'table' then return nil end

    local data = player.PlayerData
    local metadata = type(data.metadata) == 'table' and data.metadata or {}
    local permanentId = data[Config.Identity.permanentIdField]
    if permanentId ~= nil then permanentId = tostring(permanentId) end

    return {
        serverId = source,
        temporaryId = source,
        permanentId = Hud.numericString(permanentId, Config.Identity.permanentIdMaxLength, '0'),
        citizenid = Hud.safeString(data.citizenid, 64, nil),
        metadata = {
            hunger = Hud.clamp(metadata[Config.Metadata.hunger], 0, 100),
            thirst = Hud.clamp(metadata[Config.Metadata.thirst], 0, 100)
        }
    }
end
