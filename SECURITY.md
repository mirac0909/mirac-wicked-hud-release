# Security Policy

## Supported version

Security fixes are applied to the latest release, currently `1.2.x`.

## Reporting

Do not publish exploitable details in a public issue. When GitHub's
**Security → Report a vulnerability** flow is available, use it. Otherwise,
open a minimal issue asking the maintainer for a private contact channel
without including exploit details. A private report should include:

- affected version and environment
- reproduction steps or a minimal proof of concept
- expected and observed behavior
- likely impact
- any suggested mitigation

Allow time for validation and a coordinated fix before public disclosure.

## Security boundaries

- Character identity and initial hunger/thirst values are resolved
  server-side from the callback source.
- `/hudreset` runs locally and only changes presentation KVP values; it cannot
  change character vitals or authoritative framework metadata.
- NUI callbacks validate action names and values, and strict NUI callback mode
  is enabled.
- Client KVP and voice/fuel state affect presentation only; they are not
  authoritative gameplay data.
- The HUD does not create or control GTAV Enhanced voice channels.
- The resource supports a standard ox_lib installation and does not ship an
  ox_lib replacement or patch.

Third-party issues in qbx_core, ox_lib, pma-voice, FiveM or GTAV Enhanced
should also be reported to the corresponding upstream project.
