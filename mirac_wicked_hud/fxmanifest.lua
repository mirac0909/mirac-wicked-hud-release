fx_version 'cerulean'
game 'gta5'

name 'Mirac Wicked HUD'
author 'Mirac'
description 'Open-source Qbox HUD with ox_lib, secure server data, themes, vehicle HUD and configurable adapters'
version '1.3.0'
license 'MIT'
nui_callback_strict_mode 'true'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/app.js',
    'web/dist/style.css',
    'web/dist/sounds/*.ogg',
    'web/dist/sounds/*.mp3',
    'web/dist/sounds/*.wav',
    'locales/*.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/constants.lua',
    'shared/validation.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'config/client.lua',
    'bridge/qbox/client.lua',
    'bridge/voice/client.lua',
    'bridge/fuel/client.lua',
    'client/nui.lua',
    'client/settings.lua',
    'client/player.lua',
    'client/vehicle.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'bridge/qbox/server.lua',
    'server/notifications.lua',
    'server/callbacks.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'qbx_core'
}
