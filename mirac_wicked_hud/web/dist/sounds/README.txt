Custom HUD sounds

Place .ogg, .mp3, or .wav files in this folder (subfolders are supported).
Set soundMode = 'custom' and point the matching customSounds config entry to
the file using a path relative to web/dist, for example:

sounds/seatbelt-buckle.ogg
sounds/seatbelt-unbuckle.ogg
sounds/vehicle-warning.ogg
sounds/vehicle-danger.ogg

Keep customVolume between 0.0 and 1.0, then restart mirac_wicked_hud.
