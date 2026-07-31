Hud.Voice = Hud.Voice or {}

local warnedMissingResource = false
local currentVoiceMode = 2
local testVoiceMode = nil
local testTalking = nil
local testVoiceUntil = 0
local voiceModeGeneration = 0

local function normalizeVoiceMode(value)
    if type(value) == 'table' then
        value = value.index or value.mode
    end

    value = tonumber(value)
    if not value then return nil end

    value = math.floor(value)
    if value < 1 or value > 3 then return nil end
    return value
end

local function getVoiceSystem()
    if Config.VoiceSystem ~= 'auto' then return Config.VoiceSystem end
    if GetResourceState('pma-voice') == 'started' then return 'pma-voice' end

    -- NETWORK_IS_PLAYER_TALKING is supported by both GTAV Legacy and the
    -- rebuilt GTAV Enhanced voice stack, so this adapter needs no Mumble
    -- compatibility layer.
    return 'enhanced'
end

local function pmaVoiceAvailable()
    return GetResourceState('pma-voice') == 'started'
end

local function getReplicatedMode()
    if not LocalPlayer or not LocalPlayer.state then return nil end
    return normalizeVoiceMode(LocalPlayer.state[Config.VoiceModeStateBag])
end

local function testStateActive()
    if testVoiceMode and GetGameTimer() < testVoiceUntil then return true end
    testVoiceMode = nil
    testTalking = nil
    testVoiceUntil = 0
    return false
end

function Hud.Voice.isAvailable()
    local system = getVoiceSystem()
    if system ~= 'pma-voice' then return true end
    return pmaVoiceAvailable()
end

function Hud.Voice.isTalking()
    if not Config.Components.voice then return false end
    if testStateActive() then return testTalking == true end

    local system = getVoiceSystem()
    if Config.VoiceSystem == 'pma-voice' and not pmaVoiceAvailable() and not warnedMissingResource then
        warnedMissingResource = true
        if Config.Client.nuiDebug then
            lib.print.warn(('[%s] pma-voice is not started; Enhanced-compatible network talking state will be used.'):format(Hud.resource))
        end
    end

    -- Enhanced may publish the local speaking state a frame after push-to-talk.
    -- Control 249 follows the player's configured GTA/FiveM PTT binding, so it
    -- also gives the HUD immediate feedback while the key is being held.
    local talking = NetworkIsPlayerTalking(cache.playerId)
    if system == 'enhanced' or system == 'native' then
        talking = talking or IsControlPressed(0, 249)
    end

    return talking
end

function Hud.Voice.setMode(value)
    local mode = normalizeVoiceMode(value)
    if not mode then return false end

    currentVoiceMode = mode
    voiceModeGeneration = voiceModeGeneration + 1
    local generation = voiceModeGeneration
    local autoReset = Config.VoiceShoutAutoReset

    if mode == 3 and getVoiceSystem() == 'pma-voice' and autoReset and autoReset.enabled then
        SetTimeout(math.max(tonumber(autoReset.duration) or 60000, 1000), function()
            if generation ~= voiceModeGeneration or currentVoiceMode ~= 3 then return end
            if GetResourceState('pma-voice') ~= 'started' then return end

            local fallbackMode = normalizeVoiceMode(autoReset.fallbackMode) or 2
            local cycles = (fallbackMode - currentVoiceMode) % 3
            for _ = 1, cycles do
                ExecuteCommand('cycleproximity')
                Wait(50)
            end
        end)
    end

    return true
end

function Hud.Voice.getMode()
    if not Config.Components.voice then return 2 end
    if testStateActive() then return testVoiceMode end

    local system = getVoiceSystem()
    if system == 'pma-voice' then
        if pmaVoiceAvailable() then
            local proximity = LocalPlayer and LocalPlayer.state and LocalPlayer.state.proximity
            local mode = normalizeVoiceMode(proximity)
            currentVoiceMode = mode or 2
        else
            currentVoiceMode = 2
        end
    elseif system == 'enhanced' or system == 'native' then
        -- Enhanced owns channel distance on the server. Voice resources can
        -- mirror their selected HUD level through Config.VoiceModeStateBag.
        currentVoiceMode = getReplicatedMode() or currentVoiceMode
    end

    return currentVoiceMode
end

AddEventHandler('pma-voice:setTalkingMode', function(mode)
    if getVoiceSystem() == 'pma-voice' then Hud.Voice.setMode(mode) end
end)

-- Local adapter event for Enhanced/native/custom voice resources.
AddEventHandler(Hud.events.voiceModeChanged, function(mode)
    if getVoiceSystem() ~= 'pma-voice' then Hud.Voice.setMode(mode) end
end)

exports('setVoiceMode', function(mode)
    if getVoiceSystem() == 'pma-voice' then return false end
    return Hud.Voice.setMode(mode)
end)

exports('setVoiceTestState', function(data)
    if data == false or data == nil then
        testVoiceMode = nil
        testTalking = nil
        testVoiceUntil = 0
        return true
    end
    if type(data) ~= 'table' then return false end

    local mode = normalizeVoiceMode(data.mode)
    if not mode then return false end

    testVoiceMode = mode
    testTalking = data.talking == true
    testVoiceUntil = GetGameTimer() + math.floor(Hud.clamp(data.duration or 2000, 250, 30000) or 2000)
    return true
end)
