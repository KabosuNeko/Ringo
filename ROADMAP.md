# Roadmap

What is not done yet, in no particular order. No dates and no promises: this is
a personal configuration, and items land when they land.

- [ ] Replace pywal16 with an in-process palette generator, so a wallpaper
      change stops shelling out to `wal` for `colors.json`, `colors-foot-dark.ini`
      and the GTK template.
- [ ] Regression tests for the C engines: the wallpaper scaling modes and the
      night light gamma ramp and sun-position math have no automated coverage.
- [ ] Move clipboard history in-process, instead of driving
      `wl-paste --watch cliphist store` and reading back from `cliphist`.
- [ ] Move screen recording in-process, instead of the `wl-screenrec` wrapper
      in `home/.local/bin/record.sh`.
- [ ] Publish the fork and package it, so `install.sh` is not the only way to
      get a working setup.
