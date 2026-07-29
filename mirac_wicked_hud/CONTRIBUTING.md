# Contributing to Mirac Wicked HUD

Contributions are welcome. Keep changes focused, compatible with the current
Qbox/ox_lib bridge architecture, and safe for both GTAV Legacy and GTAV
Enhanced where applicable.

## Development rules

- Do not introduce `GetCoreObject()`; use the existing Qbox bridge and
  `@qbx_core/modules/playerdata.lua`.
- Keep framework, fuel and voice integrations inside their bridge files.
- Treat client-supplied identity, metadata and permissions as untrusted.
- Validate new configuration fields in `shared/validation.lua` or the
  appropriate client/server validator.
- Preserve locale parity between `locales/en.json` and `locales/tr.json`.
- Keep NUI messages diffed and avoid adding high-frequency work to idle loops.
- Keep the resource compatible with an unmodified ox_lib installation.
- Treat the static NUI files under `web/dist` as source files; no hidden build
  step is required.

## Before submitting

1. Test resource start, character load/unload and resource restart.
2. Test pedestrian and vehicle HUD transitions.
3. Test both normal and minimal display modes.
4. Run `git diff --check`.
5. Verify every documented export, event, command and configuration example.
6. Rebuild the distribution ZIP when release content changes.
7. Confirm the package root is exactly `mirac_wicked_hud/`.

## Voice changes

Legacy pma-voice support must remain optional. GTAV Enhanced integrations must
not require the deprecated `sv_mumble` compatibility layer. The HUD is
display-only: channel creation and membership remain the responsibility of the
server's voice resource.

## License

Contributions to the HUD are accepted under the MIT license. Audio assets are
covered separately in `ASSET_LICENSES.md`.
