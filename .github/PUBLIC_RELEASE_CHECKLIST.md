# Public Release Checklist

Complete this checklist before changing the repository visibility to public.

- [x] Replace review-only audio with original, procedurally synthesized assets
      documented in `mirac_wicked_hud/ASSET_LICENSES.md`.
- [ ] Test a clean install with an unmodified ox_lib and supported qbx_core.
- [ ] Test English (`setr ox:locale "en"`) and Turkish
      (`setr ox:locale "tr"`).
- [ ] Verify on-foot, vehicle, minimap, notification, TextUI, voice, nitro,
      seatbelt and warning-sound behavior.
- [ ] Confirm no server configuration, identifiers, logs, secrets, test
      resources or backup files are tracked.
- [ ] Build `mirac-wicked-hud-1.2.0.zip` from the tagged commit and verify its
      SHA-256 checksum.
- [ ] Publish the archive as a GitHub Release asset rather than committing it
      to the repository.
- [ ] Review README links, screenshots, issue templates and security contact
      instructions in the public GitHub view.
- [ ] Enable GitHub private vulnerability reporting after the repository is
      public, then verify the Security policy link.
