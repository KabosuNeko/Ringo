# Changelog

Notable changes to this project, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Ringo started as a fork of the upstream Ringo configuration; the shell, its C++
backend and the vendored engines are maintained here.

## Unreleased

### Added

- In-process wallpaper engine: a layer-shell renderer adapted from
  [wawa](https://codeberg.org/sewn/wawa) with `fill`, `fit`, `stretch`, `tile`,
  `spread` and solid colour modes, driven by `WallpaperController` instead of
  `swaybg`.
- In-process night light engine: the gamma ramp and sun-position math from
  [wlsunset](https://git.sr.ht/~kennylevinsen/wlsunset) applied over
  `wlr-gamma-control`, exposed as `nightLight status|on|off|toggle` and
  `nightLight force off|high|low`.
- Wallpaper slideshow, toggled over IPC and remembered across restarts.
- `ringo-shell call doctor check`: one report covering both engines, the
  palette and state files, and every external tool the shell drives.
- `ringo-shell call notify post`, so scripts post notifications through the
  running shell instead of starting a second notification daemon.
- A documented IPC command surface for night light, wallpaper, notifications,
  panels, clipboard, brightness, media and lock.
- `config.jsonc` reference table and a credits table for the vendored engines
  and protocol definitions in `README.md`.

### Changed

- Backend controllers reworked around D-Bus signals and events; the only
  repeating timers left poll state while the UI that shows it is on screen.
- CPU and RAM telemetry moved from QML polling into the C++ backend.
- Wallpaper and night light run as threads inside the shell, so there is no
  daemon to start, supervise or restart.
- `install.sh` installs the built plugin atomically, copying beside the target
  and renaming, so a running shell never loads a half-written plugin.
- Bar pills, control center and mini dashboard redesigned around the island
  layout.
- `README.md` restructured around core components, features, keybinds,
  configuration and credits.

### Fixed

- Never destroy an engine thread that is still running.
- Retry a refused gamma ramp, and stop leaking a pending stop, in the night
  light engine.
- Re-enable real-time live reload for installed and removed desktop entries in
  the app launcher.
- Close the control center and the mini dashboard with `Escape`.
- Remove leftover `swaybg` and duplicate-launcher paths.
- Eliminate runtime QML warnings and fix a notification memory leak.

### Removed

- `swaybg` is no longer used or installed; the wallpaper is rendered by the
  shell itself.
