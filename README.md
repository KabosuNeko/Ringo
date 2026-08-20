# Ringo

<p><br/></p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/45a8450f-2c36-46b7-a130-9d6132b87d3e" alt="Ringo Logo" style="width: 192px" />
</p>
<p><br/></p>

**A niri dotfile setup that doesn't suck.**

Ringo is a Niri configuration for Arch-based distros. It is highly optimized (~900MB/16GB RAM on boot), super clean, simple, and just works.

## Preview

| <img width="1920" height="1080" alt="screenshot_1" src="https://github.com/user-attachments/assets/7cbe867f-f2a7-446d-b5ba-3d47307dfebb" /> | <img width="1920" height="1080" alt="screenshot_2" src="https://github.com/user-attachments/assets/bbd942b4-3582-4a15-a6e3-9727f965456a" /> |
|---|---|
| <img width="1920" height="1080" alt="screenshot_3" src="https://github.com/user-attachments/assets/1472d4a5-90df-47b2-b860-808c65e74fa0" /> | <img width="1920" height="1080" alt="screenshot_4" src="https://github.com/user-attachments/assets/b3a943df-f381-4d4c-9552-97f2358b94e5" /> |


## Core Components

| Category        | Software                                                                              |
| --------------- | ------------------------------------------------------------------------------------- |
| Compositor      | [Niri](https://github.com/YaLTeR/niri)                                                |
| Terminal        | [Foot](https://codeberg.org/dnkl/foot)                                                |
| Status Bar      | ringo-shell                                                                            |
| Launcher        | ringo-shell                                                                            |
| Notifications   | ringo-shell                                                                            |
| Lock Screen     | ringo-shell (PAM)                                                                      |
| Idle Daemon     | ringo-shell (Quickshell IdleMonitor)                                                   |
| Wallpaper       | [Swaybg](https://github.com/swaywm/swaybg) |
| Power Profiles  | [power-profiles-daemon](https://gitlab.freedesktop.org/upower/power-profiles-daemon)  |
| Display Manager | [Ly](https://github.com/fairyglade/ly)                                                |
| Browser         | [Firefox-pure](https://packages.cachyos.org/package/cachyos/x86_64/firefox-pure)      |

- **Theme**: [Gruvbox-BL-LB-dark](https://www.gnome-look.org/p/1681313)
- **Icons**: [Gruvbox-Plus-Icon](https://www.gnome-look.org/p/1961046)
- **Cursor**: [Bibata-Modern-Amber](https://www.gnome-look.org/p/1914819)

> **Note**: Firefox-pure is a pre-hardened Firefox build by the CachyOS team, optimized for Wayland with privacy/security defaults. It's not recommended to layer additional `user.js` configs (Betterfox, Arkenfox, etc.) on top. For standard Firefox, uninstall `firefox-pure` and install the regular package instead.

## Features

- **pywal16 color scheme** — colors come straight from the config files `wal` generates in `~/.cache/wal/` (Foot reads `colors-foot-dark.ini`, ringo-shell reads `colors.json`, GTK reads `gtk-colors`), refreshed automatically whenever the wallpaper changes
- **All-in-one shell (ringo-shell)** — a Quickshell-based pill bar that replaces the traditional status bar, launcher, notifications, lock screen, and idle daemon: app launcher, clipboard history, control center (wifi/bluetooth/volume/brightness/media/power profiles), mini dashboard (system info + power controls), wallpaper switcher, power menu, and a PAM-backed lock screen with blur
- **GNU Stow deployment** — symlink-based, safe to rerun, trivial to uninstall
- **Hardware-adaptive** — no hardcoded monitor names, backlight devices, battery IDs, or GPU drivers
- **Progressive idle** — 300s dim → 330s lock → 360s monitor off → 600s suspend

## Installation

### Prerequisites

- Arch Linux (or Arch-based like CachyOS, EndeavourOS)
- Git
- An active internet connection

### Fresh Install

```sh
git clone https://github.com/KabosuNeko/Ringo.git ~/Ringo
cd ~/Ringo
chmod +x install.sh
./install.sh
```

The script is fully interactive — each phase prompts for confirmation:

1. Installs `yay` (AUR helper) if needed
2. Ensures `stow`, `git`, and `curl` are available
3. Installs all packages from `pkg.txt`
4. Creates required directories
5. Deploys dotfiles via **GNU Stow** (symlinks to `~/.config`, `~/.local/bin`, `~/Pictures/Wallpapers`)
6. Installs Fish shell (optional, with confirmation for default shell)
7. Extracts GTK theme and icon packs to `~/.themes` and `~/.icons`
8. Enables systemd services with safety checks (won't break TTY login)
9. Builds the ringo-shell C++ backend (`IslandBackend` module with WiFi, Bluetooth, and PAM lock support) into `~/.config/ringo-shell/IslandBackend`

### Daily Management

```sh
# Update after pulling changes:
cd ~/Ringo && git pull && stow --restow --no-folding -t ~ home

# Uninstall (remove symlinks, your files are untouched):
cd ~/Ringo && stow -D -t ~ home

# Preview what would change:
cd ~/Ringo && stow -n -t ~ home
```

## Keybinds

All bindings use `Mod` (Super/Windows key) unless noted otherwise.

| Key               | Action                                  |
| ----------------- | --------------------------------------- |
| `Mod+Return`      | Terminal (Foot)                         |
| `Mod+D`           | App launcher (ringo-shell)              |
| `Mod+V`           | Clipboard history (ringo-shell)         |
| `Mod+Ctrl+C`      | Control center                          |
| `Mod+Ctrl+B`      | Mini dashboard                          |
| `Mod+Ctrl+W`      | Wallpaper switcher                      |
| `Mod+Shift+P`     | Power menu                              |
| `Mod+Shift+C`     | Wipe clipboard history                  |
| `Mod+Q`           | Close window                            |
| `Mod+Space`       | Toggle floating                         |
| `Mod+O`           | Toggle overview                         |
| `Mod+F`           | Maximize column                         |
| `Mod+Shift+F`     | Fullscreen window                       |
| `Mod+H/J/K/L`     | Focus left / down / up / right          |
| `Mod+Ctrl+H/J/K/L`| Move column                             |
| `Mod+1-9`         | Focus workspace 1–9                     |
| `Mod+Ctrl+1-9`    | Move to workspace 1–9                   |
| `Mod+R`           | Cycle column width (1/3, 1/2, 2/3)      |
| `Mod+C`           | Center column                           |
| `Mod+Alt+C`       | Center visible columns                  |
| `Mod+W`           | Toggle tabbed display                   |
| `Mod+[` / `]`     | Consume/expel window left or right       |
| `Mod+-`/`Mod+=`   | Adjust column width                     |
| `Mod+B`           | Browser (Firefox)                       |
| `Mod+Shift+/`     | Hotkey overlay                          |
| `Mod+Shift+E`     | Quit Niri                               |
| `Print`           | Screenshot (region)                     |
| `Ctrl+Print`      | Screenshot (output)                     |
| `Alt+Print`       | Screenshot (window)                     |

Media keys (volume, brightness, playback) are mapped to standard XF86 symbols.

## Additional Configurations

If you are looking to add more configurations or expand your setup, you can check out my other specific config repositories here:

- [MPV](https://github.com/KabosuNeko/mpv)
- [FireFox Config](https://github.com/KabosuNeko/YuzuFox/)
- [Wallpapers](https://github.com/KabosuNeko/Wallpapers)
- [Nvim](https://github.com/KabosuNeko/nvim)