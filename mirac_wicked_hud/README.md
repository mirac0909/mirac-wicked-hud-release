# Mirac Wicked HUD

Open-source FiveM HUD for **Qbox** using **ox_lib**. The resource keeps framework logic isolated in bridges, reads authoritative character/status data from Qbox, stores visual preferences with client KVP, and provides a configurable vehicle HUD, minimap behavior, themes, notifications, and settings UI.

## Release

- Resource folder: `mirac_wicked_hud`
- Version: `1.4.0-beta.1`
- License: MIT
- Tested development stack from the supplied server snapshot: qbx_core 1.23.0 and ox_lib 3.39.0

## Features

- Qbox PlayerData integration without `GetCoreObject()`
- ox_lib callbacks, keybinds, locale, cache and notifications
- Server-authoritative initial metadata snapshot
- Health, armour, stamina, hunger and thirst HUD
- Minimal mode with configurable critical-status reveal behavior
- Vehicle speed, gear, fuel, engine and optional nitro display
- Nitro-aware seatbelt indicator with a configurable built-in toggle
- Two-stage fuel and engine warning colors with threshold-entry sounds
- Vehicle-only / always / never minimap modes
- Native fuel, state-bag, export and custom fuel adapters
- GTAV Enhanced voice support without the deprecated Mumble compatibility layer
- Automatic pma-voice detection and three-level proximity adapter
- 10 selectable HUD palettes
- Global HUD opacity setting
- Top-right, top-left and bottom-right layouts
- NUI ready queue and recursive patch/deduplication
- Client KVP settings; no HUD SQL table required
- Turkish and English locales
- Player-owned local visual reset command
- Safe resource restart / character switch cleanup

## Required dependencies

- `qbx_core`
- `ox_lib`

The HUD does **not** require ox_inventory, ox_target, a database table, pma-voice, or a third-party fuel resource unless you choose an adapter that uses them.

## Quick install

1. Put the folder at `resources/[local]/mirac_wicked_hud`.
2. Keep the folder name `mirac_wicked_hud` for the documented exports and integration examples.
3. Start dependencies before the HUD:

```cfg
setr ox:locale "tr"
ensure ox_lib
ensure qbx_core
ensure mirac_wicked_hud
```

See [INSTALL.md](INSTALL.md) for the full setup guide and [README_TR.md](README_TR.md) for Turkish documentation.

## Player commands

| Command | Purpose |
| --- | --- |
| `/hud` | Toggle HUD visibility |
| `/hudayar` / `/hudsettings` | Open HUD settings |
| `/hudminimal` | Toggle minimal mode |
| `/hudrace` / `/hudyaris` | Toggle between the normal vehicle HUD and racing cockpit |
| `/hudkonum` / `/hudposition` | Select or cycle HUD position |
| `/hudreset` | Reset this player's local visual HUD settings |
| `/hudyenile` / `/hudrefresh` | Rebuild the local HUD presentation without changing saved settings |

`/hudreset` restores visibility, normal/minimal mode, vehicle HUD appearance, position, palette and
opacity to `Config.DefaultSettings`. It does not change health, armour,
stamina, hunger, thirst, citizen ID or any other framework/gameplay value.

Default keybinds are configurable in `config/shared.lua`.

## Exports

```lua
exports.mirac_wicked_hud:getHudPosition()
exports.mirac_wicked_hud:getHudPalette()
exports.mirac_wicked_hud:setHudPalette('emerald')
exports.mirac_wicked_hud:getHudOpacity()
exports.mirac_wicked_hud:setHudOpacity(85)
exports.mirac_wicked_hud:getHudLayoutMetrics()
exports.mirac_wicked_hud:isHudVisible()
exports.mirac_wicked_hud:setHudVisible(true)
exports.mirac_wicked_hud:getState()
-- Enhanced/native/custom adapters: 1 whisper, 2 normal, 3 shout.
exports.mirac_wicked_hud:setVoiceMode(2)
exports.mirac_wicked_hud:setSeatbelt(true)
exports.mirac_wicked_hud:isSeatbeltOn()
exports.mirac_wicked_hud:playNitroSound('start') -- start or empty
exports.mirac_wicked_hud:playGearShiftSound('up') -- up or down
exports.mirac_wicked_hud:notify({
    id = 'job-status',
    title = 'Information',
    description = 'Example notification',
    type = 'inform',
    duration = 3000
})
exports.mirac_wicked_hud:showTextUI('door', '[E] Interact', {
    icon = 'hand',
    iconColor = '#60a5fa'
})
exports.mirac_wicked_hud:hideTextUI('door')
exports.mirac_wicked_hud:isTextUIOpen('door')
```

Notification fields are `id`, `title`, `description`, `type`, `duration`,
`icon`, `iconColor` and `restartDuration`. Supported types are `inform`,
`info`, `success`, `warning` and `error`; unknown types become `inform`.
Supported icon names are `circle-info`, `circle-check`,
`triangle-exclamation`, `circle-xmark` and `hand`. Free-form HTML, CSS,
`style`, `position` and `sound` inputs are intentionally ignored.

IDs are automatically scoped to the calling resource. Reusing an ID updates
that card in place and preserves its remaining time. Set
`restartDuration = true` to restart it. Notifications stack simultaneously;
the newest is at the top on foot and nearest the minimap in a vehicle.

## Events

Local notification event:

```lua
TriggerEvent('mirac_wicked_hud:notify', {
    title = 'Information',
    description = 'Example',
    type = 'inform'
})

-- Server-side: only the target player receives the validated payload.
exports.mirac_wicked_hud:notifyPlayer(source, {
    title = 'Server',
    description = 'Targeted message',
    type = 'success'
})
TriggerEvent('mirac_wicked_hud:server:notify', source, data)
```

Optional Qbox paycheck integration can call the same export from the
framework's configured paycheck callback without making HUD availability
mandatory:

```lua
if GetResourceState('mirac_wicked_hud') == 'started' then
    exports.mirac_wicked_hud:notifyPlayer(source, {
        id = 'paycheck',
        title = 'Paycheck',
        description = message,
        type = 'success',
        duration = 6000
    })
end
```

This is an integration example, not a required qbx_core modification.

HUD ready event:

```lua
AddEventHandler('mirac_wicked_hud:ready', function(initialData)
    -- HUD is initialized for the active character.
end)
```

Voice-mode adapter event for the GTAV Enhanced server-owned voice API:

```lua
-- 1 whisper, 2 normal, 3 shout
TriggerEvent('mirac_wicked_hud:voice:setMode', 2)
```

With the default `Config.VoiceSystem = 'auto'`, the HUD uses pma-voice when
that resource is running. Otherwise it reads Enhanced's compatible
`NetworkIsPlayerTalking` state. Since the new server-side voice API does not
publish a client proximity index, a voice resource can mirror its selected
level with the `miracVoiceMode` player state bag:

```lua
Player(source).state:set('miracVoiceMode', 2, true)
```

The HUD does not create, join or control voice channels. Enable and manage the
new Enhanced voice stack in your server/voice resource; the HUD only renders
talking and proximity status.

Server callback/event names that contain the resource name are generated from `GetCurrentResourceName()` internally.

## Palettes

`ocean`, `emerald`, `amethyst`, `amber`, `graphite`, `ruby`, `sakura`, `frost`, `royal`, `lime`.

Palette changes affect HUD surfaces and accents. Semantic health/armour/stamina/hunger/thirst and critical-warning colors remain independent.

## ox_lib boundary

The resource still depends on a standard ox_lib installation for callbacks,
locale, keybinds, cache, dialogs and progress UI. HUD notifications and TextUI
now live entirely inside `mirac_wicked_hud`; customers do not replace or patch
their ox_lib folder. Direct `lib.notify` and `lib.showTextUI` calls continue to
use the customer's normal ox_lib design. Input/alert dialogs, progress and
context menus also remain ox_lib-owned.

## Configuration

- `config/shared.lua`: components, metadata keys, keybinds, speed unit, voice, fuel, nitro, minimap, safe-zone and defaults
- `config/client.lua`: update intervals, NUI debug, development test API and pause-menu behavior
- `config/server.lua`: initial-data callback throttle/cache and server logging
- `bridge/`: Qbox, voice and fuel integration points

`Config.Notifications` controls the built-in notification system. Set
`useHudForInternal = false` to keep the HUD's own feedback messages in the
standard ox_lib notification UI. Other client notification events can be
routed into the HUD without editing their resource:

```lua
Config.Notifications.bridgeEvents = {
    'my_script:notify',
    'another_script:client:notify'
}
```

Each bridge accepts either a notification table or
`title, description, type, duration`. Direct `lib.notify` calls remain owned by
ox_lib; migrate those calls to the HUD export/event or list an event emitted
by that resource in `bridgeEvents`.

`showWhenHudHidden` controls whether notification/TextUI content remains
visible when permanent HUD panels are disabled. `hardSafetyLimit` is a
technical browser guard, not a normal visual limit; at the default 100, the
oldest card is removed only when a broken script exceeds the cap.

`compatibilityFormats.qb` and `.esx` expose optional conversion APIs; they do
not automatically intercept framework notifications:

```lua
TriggerEvent('mirac_wicked_hud:notify:qb', textOrTable, type, duration, title)
TriggerEvent('mirac_wicked_hud:notify:esx', message, type, duration, title)
```

QB tables accept `{ text = 'Title', caption = 'Description' }`.
`primary` and `info` map to `inform`; unknown QB/ESX types also map to
`inform`. Matching client exports and server exports
`notifyPlayerQB`/`notifyPlayerESX` are available.

TextUI displays one entry at a time. The last opened entry is active, earlier
entries wait, and closing the active ID restores the previous valid entry.
IDs are resource-scoped, and entries owned by a stopped resource are removed.

## Nitro and seatbelt slot

The vehicle HUD treats the presence of a configured nitro state bag as an
installed nitro system. A value of `0` therefore remains an empty nitro gauge.
When none of the configured nitro state bags exists, the same slot becomes a
seatbelt indicator. It pulses red while unfastened and stays green while
fastened.

`Config.Nitro` can also play custom start and empty sounds. Because the common
state-bag integration exposes level rather than the input key, the first
measurable level decrease is treated as activation. The empty sound plays once
when that active charge reaches zero. `consumptionEpsilon` filters insignificant
value jitter. `customVolumes.start` and `customVolumes.empty` control the two
sound levels independently.

While driving, the existing HUD peek key (`TAB` by default) opens a compact
detail card directly above the speed panel. It shows the remaining nitro
percentage only when a nitro state bag is installed; without nitro the card
stays hidden.

The identity panel label and permanent Qbox player-data field are configured
through `Config.Identity`. The compact panel keeps its original single server
ID; holding the HUD peek key shows a separate card containing both the
temporary server ID and permanent ID. By default, the permanent value comes
from `citizenid`. Other client resources can update both display values without
editing the NUI:

```lua
exports.mirac_wicked_hud:setIdentityIds({
    temporaryId = GetPlayerServerId(PlayerId()),
    permanentId = 10042
})

TriggerEvent('mirac_wicked_hud:identity:set', {
    temporaryId = 12,
    permanentId = 10042
})
```

Server resources can target a player with the same event and data table via
`TriggerClientEvent('mirac_wicked_hud:identity:set', source, data)`.

`Config.Seatbelt` enables the built-in `B` keybind, optional exit control and
configurable native buckle/unbuckle sounds.
External seatbelt resources can disable `builtIn`, publish one of the
configured vehicle state bags, or use:

```lua
exports.mirac_wicked_hud:setSeatbelt(true)
TriggerEvent('mirac_wicked_hud:seatbelt:set', true)
```

Motorcycles, bicycles, boats, aircraft and trains do not display the seatbelt
fallback. State bags must be written by the server when state-bag strict mode
is enabled.

## Gear-change sound

`Config.GearShiftSound` plays a custom NUI audio file when GTA reports a real
forward gear change. Neutral/reverse transitions and the initial gear reading
after entering a vehicle are ignored. The minimum speed, repeat cooldown,
volume and separate up/down sound paths are configurable.

The configured file may be used as a local extracted test asset. Do not
redistribute audio extracted from GTA V without distribution rights.

`Config.VehicleWarnings` controls the shared warning/danger thresholds and
their native frontend sounds. The warning stage plays once. The critical
stage plays on entry and repeats every `criticalRepeatInterval` (90 seconds by
default) while fuel or engine remains critical. Recovery silently rearms it.

Both `Config.Seatbelt` and `Config.VehicleWarnings` support `soundMode =
'native'` or `'custom'`. For custom audio, place an `.ogg`, `.mp3`, or `.wav`
file under `web/dist/sounds`, select `custom`, configure the relative
`customSounds` paths and set `customVolume` between `0.0` and `1.0`:

```lua
soundMode = 'custom',
customVolume = 0.4,
customSounds = {
    warning = 'sounds/vehicle-warning.ogg',
    danger = 'sounds/vehicle-danger.ogg'
}
```

The same structure uses `buckle` and `unbuckle` keys under
`Config.Seatbelt.customSounds`. Restart the HUD after adding or changing audio
files.

Config and bridge registrations are read when the HUD starts. Restart
`mirac_wicked_hud` after changing them. A bridge event does not disable an
existing notification handler; remove that old handler if it would otherwise
produce a duplicate card.

## Security model

The client is not trusted for citizen ID, Qbox metadata or other authoritative
framework state. Initial HUD metadata is resolved server-side from callback
`source`. The local reset only clears presentation KVP values. NUI callbacks
validate their action/value inputs and NUI strict callback mode is enabled.

## Performance model

Framework metadata is event-driven. Vehicle telemetry runs at the configured high frequency only while needed; idle/hidden loops sleep longer. NUI messages are recursively diffed so unchanged values are not resent.

## License

MIT. See [LICENSE](LICENSE).

Third-party dependencies are not bundled with the main release and remain under their own licenses.
Included audio is documented separately in
[ASSET_LICENSES.md](ASSET_LICENSES.md) and is not automatically covered by
the MIT license.
