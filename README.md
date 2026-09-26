# Ringo

An Arch Linux desktop built on [Niri](https://github.com/YaLTeR/niri) and [Quickshell](https://quickshell.org).

One Quickshell process is the whole shell: bar, launcher, notification daemon, clipboard history, control center, mini dashboard, OSDs, lock screen and wallpaper. A C++ backend (`IslandBackend`) talks to D-Bus directly and runs two Wayland clients **inside that process** — a layer-shell wallpaper renderer and a gamma-ramp night light — so there is no helper daemon to supervise.

## Screenshots

[1](https://github.com/user-attachments/assets/411d7fcc-ba95-4d1c-bc0a-e42f19b012fa) ·
[2](https://github.com/user-attachments/assets/58102f54-8fd8-4645-b7ca-5b0641c3dca7) ·
[3](https://github.com/user-attachments/assets/bf5fb964-78ee-4985-b227-f2e4bb78b2af) ·
[4](https://github.com/user-attachments/assets/48dc4ba1-277a-4523-a57c-6d3d8731fe35)

## Components

- **Compositor** — [Niri](https://github.com/YaLTeR/niri), scrollable tiling.
- **Shell** — `ringo-shell`, QML on Quickshell, plus the `IslandBackend` Qt module.
- **Wallpaper** — `fill`, `fit`, `stretch`, `tile`, `spread`, or a solid colour; decoded and drawn by the shell.
- **Night light** — sun-following colour temperature, applied through `wlr-gamma-control`.
- **Terminal** — [foot](https://codeberg.org/dnkl/foot). **Login** — [ly](https://github.com/fairyglade/ly).
- **Palette** — [pywal16](https://github.com/eylles/pywal16) generates `colors.json`, foot colours and GTK colours from the wallpaper.
- **Themes** — Gruvbox GTK/icon themes, Adwaita cursors (see `pkg.txt`).
- Everything else the shell drives (`cliphist`, `wl-clipboard`, `wl-screenrec`, `power-profiles-daemon`, …) is in `pkg.txt`; `ringo-shell call doctor check` reports what is missing.

## Install

```sh
git clone https://github.com/KabosuNeko/Ringo.git ~/Ringo
cd ~/Ringo
./install.sh
```

The installer asks before each step. Flags:

```sh
./install.sh --dry-run --non-interactive --profile core   # print the plan, change nothing
./install.sh --profile core|full                          # core skips the optional extras
./install.sh --yes                                        # answer yes to every prompt
./install.sh --rollback                                   # restore the previous backend plugin
```

It installs `yay` and the `pkg.txt` packages, deploys the dotfiles with GNU Stow, and builds the backend into `~/.config/ringo-shell/IslandBackend/` (the previous build is kept in `.backup/` before it is replaced).

## Maintenance

```sh
cd ~/Ringo && git pull && stow --restow --no-folding -t ~ home   # update + re-link
cd ~/Ringo && stow -n -t ~ home                                  # preview
cd ~/Ringo && stow -D -t ~ home                                  # unlink (your files stay)
```

Building the backend by hand:

```sh
cmake -S ringo-shell -B ringo-shell/build -DCMAKE_BUILD_TYPE=Release
cmake --build ringo-shell/build -j"$(nproc)"
# copy libIslandBackend.so, libIslandBackendPlugin.so, qmldir, IslandBackend.qmltypes
# into ~/.config/ringo-shell/IslandBackend/
```

## Configuration

`~/.config/ringo-shell/config.jsonc` is the shell's configuration. It is watched, so saving applies immediately; so is everything under `~/.config/niri/`.

| Key | Default | What it does |
| :--- | :--- | :--- |
| `displayPicture` | `~/.pfp.png` | Avatar in the control center and lock screen |
| `clockFormat` | `hh:mm` | Clock format on the bar |
| `pillTopMargin` / `pillBottomMargin` | `9` / `26` | Vertical margins of the island |
| `textFontFamily` / `nerdFontFamily` | `JetBrainsMono Nerd Font[ Propo]` | Text and icon fonts |
| `pillScale` / `dpiScale` | `1.0` / `1.4` | Island scale and global DPI multiplier |
| `notificationDisplayTime` | `3000` | Toast duration, ms |
| `maxNotificationsInStack` | `20` | Notification history depth |
| `avoidDuplicateNotifications` | `true` | Collapse repeats into `(n)` |
| `osdDuration` | `800` | On-screen display duration, ms |
| `weatherLocation` | `Ho Chi Minh City` | City for the weather widget — and the night light's coordinates |
| `weatherUnits` | `metric` | `metric` or `imperial` |
| `weatherRefreshInterval` | `3600000` | Weather refresh, ms |
| `defaultTerminal` | `foot` | Terminal the launcher runs commands in |
| `wallpapersDir` | `~/Pictures/Wallpapers` | Folder the switcher and the slideshow read |
| `wsCloseOnWallpaperSet` / `wsAnimation` | `true` | Wallpaper switcher behaviour |
| `nightLightLowTemperature` / `nightLightHighTemperature` | `4000` / `6500` | Night and day temperature, K (`6500` is neutral) |
| `nightLightLatitude` / `nightLightLongitude` | `0` / `0` | Pin the location; `0` follows `weatherLocation` |
| `slideshowIntervalMinutes` | `30` | How often the slideshow rotates the wallpaper |

What the UI changes (night light on/off and force, wallpaper mode, slideshow on/off) is runtime state, kept in the XDG state directory rather than in this file.

## Commands

Every panel and engine is reachable from a keybind or a script through `ringo-shell call`:

```sh
ringo-shell call doctor check                      # health report
ringo-shell call nightLight status                 # or: on / off / toggle
ringo-shell call nightLight force low              # or: off / high
ringo-shell call wallpaper status                  # or: next / reload
ringo-shell call wallpaper setMode tile            # or: fill / fit / spread / stretch
ringo-shell call wallpaper slideshow on            # or: off / toggle
ringo-shell call wallpaper interval 30             # minutes
ringo-shell call notify post "Summary" "Body" "icon-name" 1
ringo-shell call cliphist toggle                   # or: wipe
ringo-shell call brightness step 5                 # or: up / down
ringo-shell call media playPause                   # or: next / prev / stop
ringo-shell call lock lock                         # or: unlock
```

`controlCenter`, `miniDashboard`, `appLauncher`, `wallpaperSwitcher`, `powerMenu`, `recordMenu`, `keybinds`, `bar`, `calendar` and `weather` each take `toggle`, `open` or `hide`.

## Keybinds

[`docs/KEYBINDS.md`](docs/KEYBINDS.md) lists every binding in `~/.config/niri/keybinds.kdl` next to the shell command it runs. It is generated by `scripts/gen-keybinds-doc.sh`, which has a `--check` mode (also run by CI) that fails when the document goes stale.

## Layout

| Path | What lives there |
| :--- | :--- |
| `home/` | GNU Stow package: `~/.config/{niri,ringo-shell,foot,fish,gtk-3.0,…}` and `~/.local/bin` |
| `ringo-shell/backend/` | C++ controllers and models (`IslandBackend`) |
| `ringo-shell/backend/engines/` | Vendored wallpaper and night-light engines, adapted to run in-process |
| `home/.local/bin/ringo-shell` | Launcher and IPC client |
| `scripts/`, `docs/` | Documentation generator and its output |
| `install.sh`, `pkg.txt` | Installer and package manifest |
| `AGENTS.md` | Repository guidelines (architecture, conventions, how to verify) |

## Credits

Two engines are vendored and adapted to run inside the shell, together with the protocol definitions they speak:

| Component | Author | License | Where |
| :--- | :--- | :--- | :--- |
| [wawa](https://codeberg.org/sewn/wawa) | sewn | MIT | `ringo-shell/backend/engines/wallpaper/` — layer-shell wallpaper renderer |
| [wlsunset](https://git.sr.ht/~kennylevinsen/wlsunset) | Kenny Levinsen | MIT | `ringo-shell/backend/engines/nightlight/` — gamma ramp and sun-position math |
| [stb_image](https://github.com/nothings/stb) / stb_image_resize2 | Sean Barrett and contributors | Public domain / MIT | image decoding and resizing in the wallpaper engine |
| [wayland-protocols](https://gitlab.freedesktop.org/wayland/wayland-protocols) / [wlr-protocols](https://gitlab.freedesktop.org/wlroots/wlr-protocols) | Kristian Høgsberg, Rafael Antognolli, Jasper St. Pierre, Intel, Samsung, Red Hat, Drew DeVault, Giulio Camuffo, Simon Ser | MIT | `xdg-shell`, `xdg-output`, `wlr-layer-shell`, `wlr-gamma-control` |

Their license texts ship with the code: `ringo-shell/backend/engines/wallpaper/LICENSE`, `ringo-shell/backend/engines/nightlight/LICENSE`, the notices inside the `stb_*` headers, and the `<copyright>` blocks of the protocol XML files.

## Related

Other configurations from the same setup: [mpv](https://github.com/KabosuNeko/mpv) ·
[Firefox](https://github.com/KabosuNeko/YuzuFox) ·
[wallpapers](https://github.com/KabosuNeko/Wallpapers) ·
[neovim](https://github.com/KabosuNeko/nvim)

## License

MIT — see [LICENSE](LICENSE).
