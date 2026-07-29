# Mirac Wicked HUD Installation

This document applies to Mirac Wicked HUD `1.2.0`.

## 1. Requirements

- FiveM server running Qbox
- `qbx_core`
- `ox_lib`

The supplied development snapshot used qbx_core 1.23.0 and ox_lib 3.39.0. The HUD itself does not bundle either dependency.

## 2. Resource folder

Place the resource as:

```text
resources/[local]/mirac_wicked_hud/
```

Recommended: do not rename the folder. Internal network event names adapt
automatically, but documented exports and integration examples expect
`mirac_wicked_hud` by default.

## 3. Start order

```cfg
setr ox:locale "en" # or tr

ensure ox_lib
ensure qbx_core
ensure mirac_wicked_hud
```

Do not put the HUD before ox_lib or qbx_core.

## 4. Locale

```cfg
setr ox:locale "tr"
```

Included locales: `tr`, `en`.

## 5. Fuel

Default:

```lua
Config.FuelSystem = 'native'
```

Options:

- `native`: GTA fuel level
- `statebag`: read `Config.FuelStateBag`
- `export`: call `Config.FuelResource` / `Config.FuelExport`
- `custom`: edit `bridge/fuel/client.lua`

Missing external fuel data falls back to state-bag/native behavior.

## 6. Voice

```lua
Config.VoiceSystem = 'auto'
```

`auto` uses pma-voice when it is running, then falls back to the network
talking state supported by both GTAV Legacy and GTAV Enhanced. The HUD does not
need Enhanced's deprecated `sv_mumble` compatibility layer.

For GTAV Enhanced, enable and manage the new server-owned voice API in
`server.cfg` and your voice resource. The HUD only displays its state:

```cfg
voice_internal
```

Enhanced does not expose a client-side proximity index. When your voice
resource changes distance, mirror the HUD level (`1` whisper, `2` normal,
`3` shout) with one of these adapters:

```lua
-- Server-side replicated state bag (recommended)
Player(source).state:set('miracVoiceMode', 2, true)

-- Client-side local event or export
TriggerEvent('mirac_wicked_hud:voice:setMode', 2)
exports.mirac_wicked_hud:setVoiceMode(2)
```

The state-bag key is configurable with `Config.VoiceModeStateBag`.

Voice system options:

- `auto`: prefer pma-voice; otherwise use the Enhanced/native adapter
- `pma-voice`: use pma-voice proximity state and events
- `enhanced`: use network talking state plus the HUD proximity adapters
- `native`: use network talking state plus the HUD proximity adapters
- `custom`: use network talking state and supply proximity through an adapter

## 7. HUD settings

Visual settings are stored with client KVP:

- enabled/disabled
- minimal mode
- position
- palette
- opacity

No SQL migration is required.

Players can reset these local visual settings with:

```text
/hudreset
/hudyenile
```

The command does not write health, armour, stamina, hunger, thirst or any
other gameplay/framework value.

## 8. Minimap

```lua
Config.Minimap.mode = 'vehicle' -- vehicle | always | never
Config.Minimap.hideNativeVitals = true
```

The resource restores native HUD/radar state on resource stop.

## 9. Nitro

```lua
Config.Nitro.enabled = true
Config.Nitro.stateBags = { 'nitro', 'nitroLevel', 'nos', 'nitrous' }
```

The HUD displays the first valid configured state-bag value clamped to
0-100 percent.

## 10. Updating

1. Back up `config/` if you changed it.
2. Replace the `mirac_wicked_hud` folder with the new release.
3. Reapply local config changes.
4. `restart mirac_wicked_hud` is normally sufficient when only the HUD changes.
5. If you update ox_lib, restart dependent resources or perform a clean server restart.

When updating from `1.0.0`, add `Config.VoiceSystem` and
`Config.VoiceModeStateBag` from the current `config/shared.lua`.

## 11. Troubleshooting

### `Dependency ox_lib/qbx_core failed to load`
Verify the dependency itself starts successfully before the HUD.

### HUD does not initialize after character selection
Confirm Qbox PlayerData loads and `@qbx_core/modules/playerdata.lua` is available in your qbx_core build.

### Fuel is wrong
Set the correct `Config.FuelSystem` adapter or use `native` to verify the HUD first.

### Talking works on Enhanced but the proximity level never changes
The new voice API does not automatically expose its proximity level to the
HUD. Add the `miracVoiceMode` state-bag, local event or export adapter to the
voice resource.

### `lib.notify` does not use the Wicked HUD design

Direct ox_lib calls remain owned by ox_lib. Use the Wicked HUD notification
export/event or configure a bridge event when another resource should render
through this HUD.
