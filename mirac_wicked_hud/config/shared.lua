Config = Config or {}

-- ox_lib reads the active language from: setr ox:locale tr
Config.Components = {
    identity = true,
    location = true,
    statuses = true,
    vehicle = true,
    voice = true,
    minimap = true
}

Config.Identity = {
    serverLabel = 'OX',
    permanentIdField = 'citizenid',
    permanentIdMaxLength = 12
}

-- Only metadata rendered by the current HUD is tracked.
Config.Metadata = {
    hunger = 'hunger',
    thirst = 'thirst'
}

-- Oxygen is only sent while the player is underwater. The native reports
-- remaining seconds, which are normalized to a 0-100 HUD value.
Config.Oxygen = {
    enabled = true,
    maxSeconds = 10.0
}

Config.Keybinds = {
    toggle = 'F10',
    peek = 'TAB'
}

-- Notification integration stays inside this resource and does not modify
-- ox_lib. Scripts using lib.notify keep the original ox_lib notification.
Config.Notifications = {
    enabled = true,
    useHudForInternal = true,
    defaultDuration = 5000,
    minDuration = 1200,
    maxDuration = 15000,
    showWhenHudHidden = true,
    hardSafetyLimit = 100,
    compatibilityFormats = {
        qb = true,
        esx = true
    },

    -- Add client event names used by other resources to route their messages
    -- into this HUD. Supported calls:
    -- TriggerEvent('my_script:notify', { title = '...', description = '...', type = 'success' })
    -- TriggerEvent('my_script:notify', 'Title', 'Description', 'success', 5000)
    bridgeEvents = {
        -- 'my_script:notify'
    }
}

Config.TextUI = {
    enabled = true,
    showWhenHudHidden = true
}

Config.SpeedUnit = 'kmh' -- kmh or mph
-- auto: pma-voice calisiyorsa onu, aksi halde GTAV Enhanced'in yerlesik
-- network talking durumunu kullanir. Sunucu sahibi isterse sistemi sabitleyebilir.
Config.VoiceSystem = 'auto' -- auto, pma-voice, enhanced, native, custom
-- Enhanced's voice channels are server-owned and do not expose a client-side
-- proximity index. A voice resource can replicate 1/2/3 through this state bag.
Config.VoiceModeStateBag = 'miracVoiceMode'
Config.VoiceShoutAutoReset = {
    enabled = true,
    duration = 60000,
    fallbackMode = 2
}

Config.FuelSystem = 'native' -- native, statebag, export, custom
Config.FuelResource = ''
Config.FuelExport = 'GetFuel'
Config.FuelStateBag = 'fuel'

Config.Nitro = {
    enabled = true,
    stateBags = { 'nitro', 'nitroLevel', 'nos', 'nitrous' },
    sound = true,
    customVolumes = {
        start = 0.06,
        empty = 0.35
    },
    consumptionEpsilon = 0.05,
    customSounds = {
        start = 'sounds/nitro-start-dump-valve.wav',
        empty = 'sounds/nitro-empty-waste-gate.wav'
    }
}

Config.VehicleDetails = {
    enabled = true
}

-- The seatbelt occupies the nitro slot only when the vehicle has no nitro
-- state bag. External resources can also drive it through state bags or API.
Config.Seatbelt = {
    enabled = true,
    builtIn = true,
    defaultKey = 'B',
    preventExit = true,
    sound = true,
    soundMode = 'native', -- native or custom
    soundset = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
    buckleSound = 'SELECT',
    unbuckleSound = 'BACK',
    customVolume = 0.35,
    customSounds = {
        buckle = 'sounds/seatbelt-buckle.ogg',
        unbuckle = 'sounds/seatbelt-unbuckle.ogg'
    },
    stateBags = { 'seatbelt', 'seatbeltOn' }
}

-- Plays a short custom sound when GTA reports a real forward gear change.
-- Only use audio that you own or have permission to redistribute.
Config.GearShiftSound = {
    enabled = false,
    sound = false,
    customVolume = 0.3,
    minimumSpeed = 5.0, -- km/h or mph, matching Config.SpeedUnit
    cooldown = 180, -- milliseconds
    customSounds = {}
}

Config.VehicleWarnings = {
    enabled = true,
    warningThreshold = 60,
    dangerThreshold = 35,
    sound = true,
    soundMode = 'custom', -- native or custom
    soundset = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
    warningSound = 'NAV_UP_DOWN',
    dangerSound = 'ERROR',
    customVolume = 0.65,
    customSounds = {
        warning = 'sounds/vehicle-warning.wav',
        danger = 'sounds/vehicle-warning.wav'
    },
    criticalRepeatInterval = 90000
}

Config.Minimap = {
    mode = 'vehicle', -- vehicle, always, never
    hideNativeVitals = true,
    zoom = 1125 -- subtle zoom-out; higher values show a wider area
}

-- Keeps HUD edges inside the GTA safe-zone without changing the visual design.
Config.SafeZone = {
    enabled = true,
    maxInsetPercent = 6.0
}

Config.DefaultSettings = {
    enabled = true,
    location = true,
    minimal = false,
    position = 'top-right',
    palette = 'ocean',
    opacity = 100 -- 40-100; lower values make the whole HUD more transparent
}
