#!/bin/sh
set -eu

RINGO_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_FILE="$RINGO_DIR/pkg.txt"
ISLAND_BACKEND_DIR="$HOME/.config/ringo-shell/IslandBackend"
BACKUP_DIR="$ISLAND_BACKEND_DIR/.backup"

usage() {
    cat <<'EOF'
Ringo installer for Arch Linux (Niri + Wayland only).

Without flags it asks before every step: installs the yay AUR helper, the
packages listed in pkg.txt, deploys the dotfiles with GNU Stow, optionally
clones the Wallpapers collection, applies GTK settings, enables the system
services and builds/installs the ringo-shell C++ backend into
~/.config/ringo-shell/IslandBackend/.

Flags:
  --help                Print this help and exit.
  --dry-run             Print every action that would be taken and change
                        nothing: no package installs, no stow, no file copies,
                        no git clones, no sudo.
  --yes                 Answer yes to every confirmation prompt.
  --non-interactive     Never read stdin. Optional prompts are answered no, so
                        only the steps that need no confirmation are performed
                        and the required packages (stow, git, yay) must
                        already be installed. Combined with --yes the optional
                        prompts are answered yes instead.
  --profile core|full   core installs the dependencies, builds the backend and
                        deploys the dotfiles, skipping the optional Wallpapers
                        clone and the optional/extra package steps (yay, fish).
                        full (default) is the complete install.
  --rollback            Restore the ringo-shell backend from the backup taken
                        by the previous install (~/.config/ringo-shell/
                        IslandBackend/.backup) and exit.
EOF
}

DRY_RUN=0
ASSUME_YES=0
NON_INTERACTIVE=0
PROFILE=full
ROLLBACK=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        --yes)
            ASSUME_YES=1
            ;;
        --non-interactive)
            NON_INTERACTIVE=1
            ;;
        --rollback)
            ROLLBACK=1
            ;;
        --profile)
            if [ "$#" -lt 2 ]; then
                echo "XXX [ERROR] --profile needs an argument: core or full." >&2
                exit 2
            fi
            shift
            case "$1" in
                core|full)
                    PROFILE="$1"
                    ;;
                *)
                    echo "XXX [ERROR] Unknown profile '$1'. Expected core or full." >&2
                    exit 2
                    ;;
            esac
            ;;
        *)
            echo "XXX [ERROR] Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# run executes a command, or only prints it under --dry-run.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] $*"
        return 0
    fi
    "$@"
}

# report prints the result of an action only when the action really ran;
# --dry-run already printed the command itself.
report() {
    if [ "$DRY_RUN" -eq 0 ]; then
        echo "$1"
    fi
}

# ask answers a confirmation prompt: "y" for --yes, "n" without touching stdin
# for --non-interactive, otherwise it reads the answer from stdin.
ask() {
    if [ "$ASSUME_YES" -eq 1 ]; then
        printf "%s (y/n): y (--yes)\n" "$1"
        return 0
    fi
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        printf "%s (y/n): n (--non-interactive)\n" "$1"
        return 1
    fi
    printf "%s (y/n): " "$1"
    confirm=""
    read -r confirm
    [ "$confirm" = y ] || [ "$confirm" = Y ]
}

if [ "$ROLLBACK" -eq 1 ]; then
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "XXX [ERROR] No backend backup found in $BACKUP_DIR." >&2
        echo "    --rollback restores the snapshot taken by the previous install run." >&2
        exit 1
    fi
    echo "==> Restoring ringo-shell backend from $BACKUP_DIR"
    for entry in "$BACKUP_DIR"/* "$BACKUP_DIR"/.[!.]*; do
        [ -e "$entry" ] || continue
        name="${entry##*/}"
        # Restore beside the target and rename, like the install: a running
        # shell must never load a half-written plugin.
        run rm -rf "$ISLAND_BACKEND_DIR/.$name.rollback"
        run cp -a "$entry" "$ISLAND_BACKEND_DIR/.$name.rollback" &&
            run mv -f "$ISLAND_BACKEND_DIR/.$name.rollback" "$ISLAND_BACKEND_DIR/$name"
        report ":: Restored $name"
    done
    echo ":: Rollback complete."
    exit 0
fi

if [ "$NON_INTERACTIVE" -eq 1 ]; then
    # Never prompt for the sudo password either; a cached timestamp is required.
    if ! run sudo -n -v; then
        echo "XXX [ERROR] --non-interactive needs cached sudo credentials. Run 'sudo -v' first." >&2
        exit 1
    fi
else
    run sudo -v
fi

if [ "$PROFILE" = full ]; then
    if ask "===> Install yay (AUR helper)?"; then
        if ! run git clone https://aur.archlinux.org/yay-bin.git /tmp/yay; then
            echo "XXX [ERROR] Failed to clone yay-bin repository." >&2
            exit 1
        fi
        if ! run sh -c 'cd /tmp/yay && makepkg -si --noconfirm'; then
            echo "XXX [ERROR] makepkg failed to build/install yay." >&2
            exit 1
        fi
        run rm -rf /tmp/yay
    else
        echo ":: Skipping yay installation."
    fi
else
    echo ":: [core] Skipping yay installation."
fi

if ! command -v yay > /dev/null 2>&1; then
    echo "XXX [ERROR] yay is not installed. Cannot proceed with package installation." >&2
    echo "    Install yay manually and rerun, or answer 'y' above." >&2
    exit 1
fi

for pkg in stow git; do
    if command -v "$pkg" > /dev/null 2>&1; then
        echo ":: $pkg ... found"
    else
        echo "XXX [MISSING] $pkg"
        if ask "===> Install $pkg now?"; then
            run yay -S --noconfirm "$pkg"
        else
            echo "XXX [ERROR] $pkg is required. Exiting." >&2
            exit 1
        fi
    fi
done

if ask "===> Install packages from pkg.txt?"; then
    run yay -S --noconfirm - < "$PKG_FILE"
else
    echo ":: Skipping package installation."
fi

for folder in \
    "$HOME/Pictures/Screenshots" \
    "$HOME/Pictures/Wallpapers"
do
    if [ ! -d "$folder" ]; then
        run mkdir -p "$folder"
        report ":: Created directory: $folder"
    else
        echo ":: Directory already exists: $folder"
    fi
done

if ask "===> Deploy dotfiles via GNU Stow (symlinks)?"; then
    echo ":: Deploying configs and scripts to \$HOME..."
    cd "$RINGO_DIR"

    # stow aborts mid-tree on the first target it does not own: simulate first.
    if ! run stow -n --restow --no-folding -t "$HOME" home; then
        echo "XXX [ERROR] Stow would refuse to replace files already in \$HOME (listed above)." >&2
        echo "    Nothing was changed. Move each one aside and re-run:" >&2
        echo "      mv <file> <file>.before-ringo" >&2
        echo "    Keep your version instead? Re-run the installer without the niri" >&2
        echo "    and ringo-shell configs, then copy in only what you want." >&2
        exit 1
    fi

    if run stow --restow --no-folding -t "$HOME" home; then
        report ":: Stow deployment complete."
        for f in "$HOME/.local/bin"/*.sh; do
            [ -f "$f" ] && run chmod +x "$f"
        done
        [ -f "$HOME/.local/bin/ringo-shell" ] && run chmod +x "$HOME/.local/bin/ringo-shell"
    else
        echo "XXX [ERROR] Stow deployment failed." >&2
        exit 1
    fi
else
    echo ":: Skipping dotfiles deployment."
fi

if ! command -v fish > /dev/null 2>&1; then
    if [ "$PROFILE" = full ]; then
        if ask "===> Fish shell not found. Install now?"; then
            run yay -S --noconfirm fish
        fi
    else
        echo ":: [core] Skipping fish installation."
    fi
fi

if [ "$PROFILE" = full ]; then
    if ask "===> Download my Wallpapers collections?"; then
        echo "==> Fetching Wallpapers..."
        run mkdir -p "$HOME/Pictures"
        WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

        if [ -d "$WALLPAPER_DIR/.git" ]; then
            echo ":: Wallpapers repository already exists. Pulling latest changes..."
            run git -C "$WALLPAPER_DIR" pull
        elif [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
            echo ":: Cloning from https://github.com/KabosuNeko/Wallpapers.git..."
            run git clone --depth 1 https://github.com/KabosuNeko/Wallpapers.git "$WALLPAPER_DIR"
            run rm -rf "$WALLPAPER_DIR/.git" "$WALLPAPER_DIR/README.md"
        else
            echo ":: Directory $WALLPAPER_DIR already exists and is not empty. Skipping clone."
        fi
    else
        echo ":: Skipping Wallpapers clone."
    fi
else
    echo ":: [core] Skipping Wallpapers clone."
fi

if command -v gsettings > /dev/null 2>&1; then
    if ask "===> Apply GTK theme settings?"; then
        run gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
        run gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Orange-Dark"
        run gsettings set org.gnome.desktop.interface icon-theme "Gruvbox-Plus-Dark"
        run gsettings set org.gnome.desktop.interface cursor-theme "Adwaita"
        run gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 16"
        run gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 16"
        report ":: GTK settings applied."
    fi
fi

if ask "===> Enable system services (NetworkManager, bluetooth, ly)?"; then
    enable_svc() {
        svc="$1"
        if systemctl is-enabled "$svc" > /dev/null 2>&1; then
            echo ":: $svc already enabled."
            return
        fi
        if systemctl list-unit-files "$svc" > /dev/null 2>&1; then
            run sudo systemctl enable --now "$svc" && report ":: Enabled $svc"
        else
            echo "!!! $svc not found (package may not be installed). Skipping."
        fi
    }

    enable_svc "NetworkManager"
    enable_svc "bluetooth"

    # ly@.service is a template; only "ly@.service" matches an installed unit file.
    # Use tty2 and free it: ly@tty1 conflicts with the default getty@tty1 console.
    if systemctl list-unit-files "ly@.service" > /dev/null 2>&1; then
        if run sudo systemctl enable ly@tty2.service; then
            run sudo systemctl disable getty@tty2.service 2>/dev/null || true
            report ":: ly display manager enabled on tty2 (getty@tty2 disabled, getty@tty1 kept)."
        fi
    else
        echo "!!! ly not installed. Skipping display manager setup."
    fi
fi

if command -v xdg-mime > /dev/null 2>&1 && command -v thunar > /dev/null 2>&1; then
    run xdg-mime default thunar.desktop inode/directory
    report ":: Default file manager: thunar"
fi

if [ -d "$RINGO_DIR/ringo-shell" ]; then
    if ask "===> Build & install ringo-shell C++ backend?"; then
        echo ":: Checking ringo-shell build dependencies..."
        missing=""
        command -v cmake > /dev/null 2>&1 || missing="${missing}cmake "
        command -v pkg-config > /dev/null 2>&1 || missing="${missing}pkgconf "
        command -v wayland-scanner > /dev/null 2>&1 || missing="${missing}wayland "
        pkg-config --exists wayland-client 2>/dev/null || missing="${missing}wayland "
        if [ -n "$missing" ]; then
            echo "XXX [MISSING] $missing"
            run yay -S --noconfirm $missing
        fi

        echo ":: Building ringo-shell C++ backend..."
        cd "$RINGO_DIR/ringo-shell"
        if ! run cmake -S . -B build -DCMAKE_BUILD_TYPE=Release; then
            echo "XXX [ERROR] ringo-shell cmake configure failed." >&2
            exit 1
        fi
        if ! run cmake --build build -j"$(nproc)"; then
            echo "XXX [ERROR] ringo-shell build failed." >&2
            exit 1
        fi

        echo ":: Installing ringo-shell backend to ~/.config/ringo-shell/IslandBackend..."
        run mkdir -p "$ISLAND_BACKEND_DIR"

        # --rollback snapshot; .backup sits inside the directory it snapshots.
        echo ":: Backend backup path: $BACKUP_DIR"
        if [ -d "$ISLAND_BACKEND_DIR" ]; then
            run rm -rf "$BACKUP_DIR"
            run mkdir -p "$BACKUP_DIR"
            for entry in "$ISLAND_BACKEND_DIR"/* "$ISLAND_BACKEND_DIR"/.[!.]*; do
                [ -e "$entry" ] || continue
                case "$entry" in
                    "$BACKUP_DIR") continue ;;
                esac
                run cp -a "$entry" "$BACKUP_DIR/"
            done
        fi

        # Copy beside the target and rename: a running shell must never load a
        # half-written plugin. run() keeps --dry-run from deploying anything.
        for f in libIslandBackend.so libIslandBackendPlugin.so qmldir IslandBackend.qmltypes; do
            run cp -f "build/$f" "$HOME/.config/ringo-shell/IslandBackend/.$f.new" &&
                run mv -f "$HOME/.config/ringo-shell/IslandBackend/.$f.new" \
                      "$HOME/.config/ringo-shell/IslandBackend/$f"
        done
        run chmod +x "$HOME/.local/bin/ringo-shell"

        if [ -f "$RINGO_DIR/assets/ringo.png" ]; then
            echo ":: Installing ringo-shell icon..."
            run mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
            run mkdir -p "$HOME/.local/share/pixmaps"
            run cp "$RINGO_DIR/assets/ringo.png" "$HOME/.local/share/icons/hicolor/256x256/apps/ringo.png"
            run cp "$RINGO_DIR/assets/ringo.png" "$HOME/.local/share/pixmaps/ringo.png"
        fi

        echo ":: Cleaning up ringo-shell build files..."
        run rm -rf build
        cd "$RINGO_DIR"
        report ":: ringo-shell installed. Launch with 'ringo-shell'."
    else
        echo ":: Skipping ringo-shell installation."
    fi
else
    echo ":: ringo-shell/ directory not found. Skipping ringo-shell installation."
fi

echo ""
