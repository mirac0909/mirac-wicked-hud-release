# Changelog

## 1.4.0-beta.2 — 2026-08-02

- Added an ultra-minimal pedestrian HUD mode with a compact status layout and
  the `/hudultra` command.
- Added five palettes: Copper, Coral, Petrol, Orchid and Sage.
- Added smooth, bidirectional pedestrian/vehicle transitions for the HUD
  frame, segmented status bars and microphone indicator.
- Improved critical-status card entry and exit behavior, including the 10%
  pedestrian and 50% vehicle reveal thresholds.
- Fixed status cards remaining visible during vehicle exit and values not
  returning to their normal pedestrian presentation after vehicle entry.
- Fixed the ultra-minimal microphone being clipped while keeping its voice
  range dots aligned with the oxygen status line.

## 1.4.0-beta.1 — 2026-07-31

- Added a persistent race vehicle HUD selectable from settings or with
  `/hudrace` and `/hudyaris`, while preserving the original vehicle layout.
- Added a centered race cockpit with gear, speed, RPM, seatbelt, nitro and
  enlarged C-shaped fuel and engine meters.
- Added palette-aware race styling, RPM thresholds, nitro feedback and smooth
  transitions between normal, race, gear, seatbelt and nitro states.
- Added a race minimap layout with corrected native radar alignment and the
  normal HUD frame design.
- Added matching top and bottom minimap vignette shading without changing the
  native radar size or alignment.
- Added a crash reboot effect synchronized across the vehicle HUD, minimap
  frame and native radar.
- Improved settings persistence, reset behavior, localization, validation and
  NUI cache handling for the new vehicle mode.

## 1.3.0 — 2026-07-29

- Added interaction-aware ownership for the shared nitro and seatbelt
  indicator, including safe fallback after nitro use or depletion.
- Preserved the flashing unbuckled warning even when nitro is installed.
- Added robust emergency-signal detection for standard and add-on vehicles.
- Moved siren feedback to a subtle animated red-purple-blue vehicle accent.
- Added configurable minimap zoom and changed the default HUD opacity to 100%.
- Updated configuration validation and NUI cache versions.

## 1.2.0 — 2026-07-29

- Added resource-owned notification and TextUI systems with pedestrian and
  vehicle-aware placement, animations, palette and opacity integration.
- Added validated client/server notification APIs, QB/ESX format adapters,
  resource-scoped IDs and duplicate-update behavior.
- Added normal/minimal status fixes, stamina and oxygen support, critical
  reveal settling and synchronized status-card transitions.
- Added configurable location-panel visibility and local HUD refresh support.
- Expanded the vehicle HUD with entry/exit transitions, minimap-frame
  synchronization, nitro, seatbelt, RPM gear ring and TAB detail cards.
- Added configurable native/custom seatbelt, nitro, fuel and engine warning
  sounds with staged repeat behavior.
- Added pma-voice and Enhanced/native voice compatibility, three proximity
  levels and optional shout auto-reset.
- Added English command aliases and completed runtime English localization.
- Removed the ox_lib adaptive overlay requirement; the HUD now works with an
  unmodified ox_lib installation.
- Removed browser-demo and test-server files from the production resource.
- Updated installation, API, security, contribution and asset documentation.

## 1.1.1 — 2026-07-26

- Replaced the ACE-protected remote HUD reset with a player-owned local `/hudreset` command.
- Local reset now restores only HUD visibility, display mode, position, palette and opacity.
- Removed the unused remote refresh/reset events, server admin commands and ACE configuration.

## 1.1.0 — 2026-07-26

- Added a GTAV Enhanced voice adapter that does not require the deprecated Mumble compatibility layer.
- Added automatic pma-voice detection with an Enhanced-compatible native fallback.
- Added state-bag, local event and export inputs for server-owned Enhanced proximity modes.
- Updated English and Turkish setup, integration, security and contribution documentation.
- Rebuilt stock ox_lib and optional ox_lib 3.39.0 adaptive distribution packages.

## 1.0.0 — 2026-07-25

- Initial private distribution release.
- Qbox and ox_lib integration.
- Player, status, vehicle, voice and minimap HUD components.
- Three-level whisper, normal and shout proximity indicator for pma-voice and custom voice adapters.
- Turkish and English locale support.
- Client KVP settings, themes, opacity and positioning.
- ACE-protected administrative refresh/reset commands.
- Separate stock ox_lib and optional ox_lib 3.39.0 adaptive packages.
