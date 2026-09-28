# Repository Guidelines

## Project Overview

Personal Arch + Niri (Wayland) desktop configuration. One Quickshell process draws the bar, panels, launcher and lock screen; a Qt/C++ backend (`IslandBackend`) owns D-Bus integration and runs a layer-shell wallpaper engine **inside that same process**, so there is no wallpaper daemon to supervise; the night light is the `wlsunset` process the backend spawns and watches.

## Architecture & Data Flow

Three layers, one process:

1. **QML** (`home/.config/ringo-shell/*.qml`) — an implicit Quickshell module. `shell.qml` is the root: it wires the controllers, hosts every overlay, and declares the IPC surface.
2. **C++ controllers** (`ringo-shell/backend/*.{h,cpp}`) — `QML_ELEMENT` + `QML_SINGLETON` objects, created lazily by the QML engine on the GUI thread. They read D-Bus signals, spawn `QProcess` helpers, and expose the result as properties.
3. **C engine** (`ringo-shell/backend/engines/wallpaper/`) — a vendored upstream source adapted to run on its own `QThread`. It blocks in its own Wayland event loop and is started/stopped by its controller.

Data flow:

- D-Bus / PipeWire / UPower → controller → `Q_PROPERTY` + `xChanged` → QML.
- QML action → `Q_INVOKABLE` on a controller, or `Quickshell.execDetached([...])` for a real program.
- Controller → `QThreadPool` for decode/blur/PAM, → `QThread` for the wallpaper engine, → `QProcess` for `wlsunset`.
- Shell → `IpcHandler` targets → `ringo-shell call <target> <fn>` from keybinds and scripts.

State split (do not mix these):

- **User configuration**: `~/.config/ringo-shell/config.jsonc`, read through `Config.qml` (`FileView` + `JsonAdapter`, watched, applies on save).
- **Runtime state**: `StateStore` (a small JSON store) for toggles the UI mutates — night light on/off + force, wallpaper mode, slideshow on/off. Under Quickshell it resolves to `~/.local/state/quickshell/ringo-shell/state.json`.

## Key Directories

| Path | Purpose |
| :--- | :--- |
| `home/.config/ringo-shell/` | The shell: `shell.qml`, panels, `Config.qml`, `Theme.qml` |
| `ringo-shell/backend/` | C++ controllers, models and helpers |
| `ringo-shell/backend/engines/wallpaper/` | Vendored wallpaper renderer (layer-shell; the shell's Qt decoder hands it pixels) |
| `home/.config/niri/autostart.kdl` | What starts with the session; the night light is started by `NightLightController`, not from here |
| `home/.config/niri/` | Compositor config: `config.kdl` includes `keybinds/rules/settings/autostart.kdl` |
| `home/.local/bin/` | User scripts: `ringo-shell`, `record.sh`, `color-picker.sh`, `scratchpad.sh` |
| `scripts/` | `gen-keybinds-doc.sh` (docs generator + `--check`) |
| `docs/KEYBINDS.md` | **Generated** reference — never edit by hand |
| `home/` | GNU Stow package; every file is symlinked into `$HOME` |

## Development Commands

```sh
# build the backend (Qt6 + wayland-client + wayland-scanner + pkg-config)
cmake -S ringo-shell -B ringo-shell/build -DCMAKE_BUILD_TYPE=Release
cmake --build ringo-shell/build -j"$(nproc)"

# deploy: the plugin lives outside Stow, copy it atomically
D=$HOME/.config/ringo-shell/IslandBackend; B=ringo-shell/build
for f in libIslandBackend.so libIslandBackendPlugin.so qmldir IslandBackend.qmltypes; do
  cp -f "$B/$f" "$D/.$f.new" && mv -f "$D/.$f.new" "$D/$f"
done

# restart the shell and look at it
pkill -x qs; setsid nohup ~/.local/bin/ringo-shell >/dev/null 2>&1 &

# health report, IPC, logs
ringo-shell call doctor check
ringo-shell call nightLight status
tail -f /run/user/1000/quickshell/by-id/*/log.log     # ERROR / TypeError lines

# compositor config check, keybind docs, script lint, installer dry run
niri validate
scripts/gen-keybinds-doc.sh && scripts/gen-keybinds-doc.sh --check
sh -n install.sh
grep -lE '^#!.*\b(sh|bash|dash|ksh)\b' install.sh home/.local/bin/* scripts/*.sh | xargs shellcheck --severity=warning
./install.sh --dry-run --non-interactive --profile core
```

QML files need no build step, but **a newly added QML file must be stowed** (`stow --restow --no-folding -t "$HOME" home`) or Quickshell cannot see it — the module listing comes from the config directory.

## Code Conventions & Common Patterns

**C++ controllers**

- 4-space indent, `m_` members, one class per file named `FooController`/`FooModel`.
- Properties are private-setter + signal: `void setError(const QString &); if (m_error == error) return; m_error = error; emit errorChanged();`.
- Surface failures, do not swallow them: a `QString error` property (wallpaper, night light) or a model `errorMessage`. `Notifier` posts user-visible notifications through the shell's own server — no `notify-send` process.
- No polling loops. Timers only run while their UI is on screen (telemetry) or on a long interval (weather, 1 h).
- Anything `new`ed gets a parent, or a cleanup path on every exit — including `errorOccurred`, not only `finished`.
- Async work: D-Bus signals where available, `QProcess` for CLI tools (including `wlsunset`), `QThreadPool` for CPU work, `QThread` only for the wallpaper engine.

**The C engine** (read the file header first, it is a port)

- Tabs, `static` file-scope state, reset at the top of every `run()`.
- Failure is `die()`/`engine_failf()` → `longjmp` to `run()`; **never** `exit()`, `abort()` or `assert()` — the engine is a guest in the shell process.
- `ringo_*_run()` blocks; `ringo_*_stop()` is called from another thread and only writes to a self-pipe (plus a pending flag, so a stop that arrives before the pipe exists is not lost).
- A `pthread` run mutex serialises runs: a stopped engine can still be tearing down when the next one starts, and they share the globals.
- Teardown must pair every fd/mmap/`wl_*` object; destroy Wayland children *before* `wl_display_disconnect()`.
- Keep the upstream file shape and its `LICENSE`; the adaptations are the API (`run`/`stop`/`error`), the run lock, the stop pipe and the teardown.

**QML**

- 2-space indent, PascalCase components, one component per file.
- Colours, fonts and sizes come from `Theme.*` and `Config.*`; no new hardcoded values (the recording dot is the one deliberate exception).
- Animations: `Behavior on <prop> { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }`. Never leave an infinite animation running in an invisible item — it repaints the scene forever.
- Overlays (launcher, clipboard, power menu, keybinds, …) are hosted in an `OverlaySlot` inside `shell.qml`, gated by `blocked:` on higher-priority surfaces, and closed from `closeOverlays()`.
- A panel takes `shown` + `onCloseRequested`, so the host stays in charge of state.
- Paths from `config.jsonc` may start with `~/` — expand them (`QDir::homePath()` in C++, `.replace("~", ...)` in QML).

**IPC and keybinds**

- Add a target in `shell.qml`: `IpcHandler { target: "foo"; function bar(): void { ... } }`, then bind it in `home/.config/niri/keybinds.kdl`: `Mod+X hotkey-overlay-title="…" { spawn-sh "ringo-shell call foo bar"; }`.
- After editing `keybinds.kdl` or adding/removing IPC functions, regenerate `docs/KEYBINDS.md` (CI runs `--check`).

## Important Files

| File | Why it matters |
| :--- | :--- |
| `home/.config/ringo-shell/shell.qml` | Root of the shell: controller wiring, every overlay, all 18 IPC targets, `doctorReport()` |
| `home/.config/ringo-shell/Config.qml` + `config.jsonc` | User knobs (bar, notifications, weather, terminal, wallpaper, night light, slideshow) |
| `home/.config/ringo-shell/Theme.qml` | Palette derived from pywal (`~/.cache/wal/colors.json`) |
| `home/.config/niri/autostart.kdl` | What starts with the session (`ringo-shell`, `fcitx5`, clipboard watchers) |
| `home/.local/bin/ringo-shell` | Launcher + IPC client (`ringo-shell call …`) |
| `ringo-shell/CMakeLists.txt` | Qt module, protocol generation, engine compile flags |
| `ringo-shell/backend/WallpaperController.{h,cpp}` | `wal` → blur → in-process engine pipeline, mode fallback, slideshow |
| `ringo-shell/backend/NightLightController.{h,cpp}` | Engine lifecycle, sun-following schedule, weather-driven location |
| `install.sh` | Arch installer: `--dry-run`, `--yes`, `--non-interactive`, `--profile core\|full`, `--rollback` |
| `docs/KEYBINDS.md` | Generated from `keybinds.kdl` + `shell.qml` |

## Runtime/Tooling Preferences

- **Arch Linux only**, **Niri** compositor, **Quickshell 0.3.x**; no X11 fallback, no other distro path.
- Qt 6 (`Core Gui DBus Qml Network`), CMake ≥ 3.16, C++17 for the backend and **C11** for the wallpaper engine (upstream relies on pre-C23 `()` declarations — do not bump the standard).
- Build deps: `wayland-scanner`, `wayland-client` (pkg-config), plus the runtime tools listed in `pkg.txt` (`wal`, `cliphist`, `wl-clipboard`, `wl-screenrec`, `foot`, `niri`, `qs`, …). `ringo-shell call doctor check` reports which of them are missing and whether they are required.
- Deployment is GNU Stow (`home/` → `$HOME`); the compiled plugin is copied outside Stow into `~/.config/ringo-shell/IslandBackend/`.
- Scripts: POSIX `sh` when they must run anywhere (`record.sh`), bash otherwise, Python 3 for `scratchpad.sh` (despite the `.sh` name). They prefer `ringo-shell call notify post …` and fall back to `notify-send`.
- No Node/Bun/Python build step: `wal` (pywal16) is the only interpreter in the runtime path.

## Testing & QA

Two automated checks run in CI, both without a compositor: a CTest over the wallpaper scaling modes (`ringo-shell/tests/`, wired in `ringo-shell/CMakeLists.txt`) and an end-to-end test of the installer in a throwaway `$HOME` (`scripts/test-install.sh`, which stubs `yay`/`sudo`/`systemctl`/`gsettings`/`xdg-mime` and asserts the stow pre-flight, the 55 deployed symlinks and the rollback path). Verification has three layers:

1. **CI** (`.github/workflows/build.yml`): builds the backend on Ubuntu, runs `ctest` and `scripts/test-install.sh`, `sh -n install.sh`, `shellcheck --severity=warning` over POSIX-shebang scripts, and `scripts/gen-keybinds-doc.sh --check`. It catches compile breaks, shell syntax, stale generated docs, and installer regressions.
2. **Runtime self-check**: `ringo-shell call doctor check` prints the wallpaper engine's state, the night light's, , the palette/state files, and every external tool, with a `verdict:` line. It has caught real bugs (a night light that held no output, a dead weather refresh) — run it after any backend change.
3. **Manual smoke**: build → deploy → restart → check the log for `ERROR` → look at the surface (a screenshot; `niri msg action screenshot-screen`) → exercise the IPC command you touched. Never claim a UI or engine change works without having seen the surface or the reported state.

To test the wallpaper engine without the shell, compile it with the generated protocols into a small `main()` that fills an RGBA buffer, calls `ringo_wallpaper_run()` and stops it from a second thread:

```sh
SRC=ringo-shell/backend/engines/wallpaper
wayland-scanner client-header $SRC/proto/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.h
wayland-scanner private-code  $SRC/proto/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.c
wayland-scanner client-header $SRC/proto/unstable/xdg-output/xdg-output-unstable-v1.xml xdg-output-unstable-v1-protocol.h
wayland-scanner private-code  $SRC/proto/unstable/xdg-output/xdg-output-unstable-v1.xml xdg-output-unstable-v1-protocol.c
wayland-scanner client-header $SRC/wlr-layer-shell-unstable-v1.xml wlr-layer-shell-unstable-v1-protocol.h
wayland-scanner private-code  $SRC/wlr-layer-shell-unstable-v1.xml wlr-layer-shell-unstable-v1-protocol.c
gcc -std=gnu11 -O2 -Wall -Wextra -D_GNU_SOURCE -c $SRC/wallpaper.c \
    xdg-output-unstable-v1-protocol.c wlr-layer-shell-unstable-v1-protocol.c harness.c -I$SRC -I.
gcc -o harness *.o -lwayland-client -lm
```

Useful invariants for such a harness: three sequential runs in one process must each return 0; a run started after a stop must not exit immediately; a NULL image or an unknown mode must return -1 with a message instead of killing the process.

What is still uncovered: the wallpaper engine's run/stop/re-run contract and failure paths (needs a compositor, so the harness above is the way in) and the IPC surface (target + function names) against `docs/KEYBINDS.md`.
