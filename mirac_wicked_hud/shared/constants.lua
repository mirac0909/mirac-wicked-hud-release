Hud = Hud or {}

Hud.resource = GetCurrentResourceName()

Hud.actions = {
    update = 'hud:update',
    visibility = 'hud:visibility',
    config = 'hud:config',
    settings = 'hud:settings',
    notification = 'hud:notification:add',
    notificationUpdate = 'hud:notification:update',
    notificationRemove = 'hud:notification:remove',
    notificationReset = 'hud:notification:reset',
    textUi = 'hud:textui',
    locale = 'hud:locale',
    reset = 'hud:reset'
}

Hud.events = {
    initialData = ('%s:server:getInitialData'):format(Hud.resource),
    notify = ('%s:client:notify'):format(Hud.resource),
    serverNotify = ('%s:server:notify'):format(Hud.resource),
    playerLoaded = ('%s:bridge:playerLoaded'):format(Hud.resource),
    playerUnloaded = ('%s:bridge:playerUnloaded'):format(Hud.resource),
    playerDataChanged = ('%s:bridge:playerDataChanged'):format(Hud.resource),
    voiceModeChanged = ('%s:voice:setMode'):format(Hud.resource)
}

Hud.positions = {
    ['top-right'] = true,
    ['top-left'] = true,
    ['bottom-right'] = true
}

Hud.palettes = {
    ocean = true,
    emerald = true,
    amethyst = true,
    amber = true,
    graphite = true,
    ruby = true,
    sakura = true,
    frost = true,
    royal = true,
    lime = true
}

Hud.nuiLocaleKeys = {
    'document_title',
    'player_info',
    'label_id',
    'label_temporary_id',
    'label_permanent_id',
    'label_time',
    'voice_status',
    'voice_mode_status',
    'voice_mode_whisper',
    'voice_mode_normal',
    'voice_mode_shout',
    'location',
    'locating',
    'player_statuses',
    'health',
    'armour',
    'stamina',
    'oxygen',
    'hunger',
    'thirst',
    'vehicle_status',
    'vehicle_details',
    'nitro_remaining',
    'speed',
    'gear',
    'fuel',
    'engine',
    'nitro_percent',
    'seatbelt_on',
    'seatbelt_off',
    'close_settings',
    'interface',
    'settings_title',
    'settings_description',
    'hud_visibility',
    'location_visibility',
    'location_visibility_description',
    'enabled',
    'disabled',
    'display_mode',
    'display_mode_description',
    'normal',
    'normal_description',
    'minimal',
    'minimal_description',
    'vehicle_hud_mode',
    'vehicle_hud_mode_description',
    'vehicle_mode_normal_description',
    'race',
    'race_description',
    'palette_title',
    'palette_description',
    'palette_ocean',
    'palette_emerald',
    'palette_amethyst',
    'palette_amber',
    'palette_graphite',
    'palette_ruby',
    'palette_sakura',
    'palette_frost',
    'palette_royal',
    'palette_lime',
    'opacity_title',
    'opacity_description',
    'hud_position',
    'hud_position_description',
    'top_right',
    'top_left',
    'bottom_right',
    'preview_panels',
    'preview_description',
    'close_hint',
    'notification'
}

lib.locale()
