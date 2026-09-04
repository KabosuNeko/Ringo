#!/bin/sh
set -eu

RINGO_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_FILE="$RINGO_DIR/pkg.txt"

sudo -v

echo "=========================================="
echo "  Ringo Dotfiles Installer"
echo "  Stow-based deployment to \$HOME"
echo "=========================================="

printf "===> Install yay (AUR helper)? (y/n): "
read -r confirm
if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
    if ! git clone https://aur.archlinux.org/yay-bin.git /tmp/yay; then
        echo "XXX [ERROR] Failed to clone yay-bin repository." >&2
        exit 1
    fi
    if ! (cd /tmp/yay && makepkg -si --noconfirm); then
        echo "XXX [ERROR] makepkg failed to build/install yay." >&2
        exit 1
    fi
    rm -rf /tmp/yay
else
    echo ":: Skipping yay installation."
fi

if ! command -v yay > /dev/null 2>&1; then
    echo "XXX [ERROR] yay is not installed. Cannot proceed with package installation." >&2
    echo "    Install yay manually and rerun, or answer 'y' above." >&2
    exit 1
fi

for pkg in stow git curl; do
    if command -v "$pkg" > /dev/null 2>&1; then
        echo ":: $pkg ... found"
    else
        echo "XXX [MISSING] $pkg"
        printf "===> Install $pkg now? (y/n): "
        read -r confirm
        if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
            yay -S --noconfirm "$pkg"
        else
            echo "XXX [ERROR] $pkg is required. Exiting." >&2
            exit 1
        fi
    fi
done

printf "===> Install packages from pkg.txt? (y/n): "
read -r confirm
if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
    yay -S --noconfirm - < "$PKG_FILE"
else
    echo ":: Skipping package installation."
fi

for folder in \
    "$HOME/.icons" \
    "$HOME/.themes" \
    "$HOME/Pictures/Screenshots"
do
    if [ ! -d "$folder" ]; then
        mkdir -p "$folder"
        echo ":: Created directory: $folder"
    else
        echo ":: Directory already exists: $folder"
    fi
done

printf "===> Deploy dotfiles via GNU Stow (symlinks)? (y/n): "
read -r confirm
if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
    echo ":: Deploying configs and scripts to \$HOME..."
    cd "$RINGO_DIR"
    if stow --restow --no-folding -t "$HOME" home; then
        echo ":: Stow deployment complete."
        for f in "$HOME/.local/bin"/*.sh; do
            [ -f "$f" ] && chmod +x "$f"
        done
        [ -f "$HOME/.local/bin/ringo-shell" ] && chmod +x "$HOME/.local/bin/ringo-shell"
    else
        echo "XXX [ERROR] Stow deployment failed." >&2
        exit 1
    fi
else
    echo ":: Skipping dotfiles deployment."
fi

if ! command -v fish > /dev/null 2>&1; then
    printf "===> Fish shell not found. Install now? (y/n): "
    read -r confirm
    if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
        yay -S --noconfirm fish
    fi
fi

printf "===> Download my Wallpapers collections? (y/n): "
read -r confirm
if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
    echo "==> Fetching Wallpapers..."
    mkdir -p "$HOME/Pictures"
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

    if [ -d "$WALLPAPER_DIR/.git" ]; then
        echo ":: Wallpapers repository already exists. Pulling latest changes..."
        git -C "$WALLPAPER_DIR" pull
    elif [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
        echo ":: Cloning from https://github.com/KabosuNeko/Wallpapers.git..."
        git clone --depth 1 https://github.com/KabosuNeko/Wallpapers.git "$WALLPAPER_DIR"
        rm -rf "$WALLPAPER_DIR/.git" "$WALLPAPER_DIR/README.md"
    else
        echo ":: Directory $WALLPAPER_DIR already exists and is not empty. Skipping clone."
    fi
else
    echo ":: Skipping Wallpapers clone."
fi

if command -v gsettings > /dev/null 2>&1; then
    printf "===> Apply GTK theme settings? (y/n): "
    read -r confirm
    if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
        gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Orange-Dark"
        gsettings set org.gnome.desktop.interface icon-theme "Gruvbox-Plus-Dark"
        gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Amber"
        gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 16"
        gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 16"
        echo ":: GTK settings applied."
    fi
fi

printf "===> Enable system services (NetworkManager, bluetooth, ly)? (y/n): "
read -r confirm
if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
    enable_svc() {
        svc="$1"
        if systemctl is-enabled "$svc" > /dev/null 2>&1; then
            echo ":: $svc already enabled."
            return
        fi
        if systemctl list-unit-files "$svc" > /dev/null 2>&1; then
            sudo systemctl enable --now "$svc" && echo ":: Enabled $svc"
        else
            echo "!!! $svc not found (package may not be installed). Skipping."
        fi
    }

    enable_svc "NetworkManager"
    enable_svc "bluetooth"

    if systemctl list-unit-files "ly@tty1.service" > /dev/null 2>&1; then
        if sudo systemctl enable ly@tty1.service; then
            sudo systemctl disable getty@tty1.service 2>/dev/null || true
            echo ":: ly display manager enabled (getty disabled)."
        fi
    else
        echo "!!! ly not installed. Skipping display manager setup."
    fi
fi

if command -v xdg-mime > /dev/null 2>&1 && command -v thunar > /dev/null 2>&1; then
    xdg-mime default thunar.desktop inode/directory
    echo ":: Default file manager: thunar"
fi

if [ -d "$RINGO_DIR/ringo-shell" ]; then
    printf "===> Build & install ringo-shell C++ backend? (y/n): "
    read -r confirm
    if [ "$confirm" = y ] || [ "$confirm" = Y ]; then
        echo ":: Checking ringo-shell build dependencies..."
        missing=""
        command -v cmake > /dev/null 2>&1 || missing="${missing}cmake "
        pkg-config --exists libpulse > /dev/null 2>&1 || missing="${missing}libpulse "
        if [ -n "$missing" ]; then
            echo "XXX [MISSING] $missing"
            yay -S --noconfirm $missing
        fi

        echo ":: Building ringo-shell C++ backend..."
        cd "$RINGO_DIR/ringo-shell"
        if ! cmake -S . -B build -DCMAKE_BUILD_TYPE=Release; then
            echo "XXX [ERROR] ringo-shell cmake configure failed." >&2
            exit 1
        fi
        if ! cmake --build build -j"$(nproc)"; then
            echo "XXX [ERROR] ringo-shell build failed." >&2
            exit 1
        fi

        echo ":: Installing ringo-shell backend to ~/.config/ringo-shell/IslandBackend..."
        mkdir -p "$HOME/.config/ringo-shell/IslandBackend"
        cp build/libIslandBackend.so build/libIslandBackendPlugin.so build/qmldir build/IslandBackend.qmltypes "$HOME/.config/ringo-shell/IslandBackend/"
        chmod +x "$HOME/.local/bin/ringo-shell"

        echo ":: Cleaning up ringo-shell build files..."
        rm -rf build
        cd "$RINGO_DIR"
        echo ":: ringo-shell installed. Launch with 'ringo-shell'."
    else
        echo ":: Skipping ringo-shell installation."
    fi
else
    echo ":: ringo-shell/ directory not found. Skipping ringo-shell installation."
fi

echo ""
echo "=========================================="
echo "  Installation complete!"
echo "  To uninstall:  cd ~/Ringo && stow -D -t ~ home"
echo "  To update:     cd ~/Ringo && stow --restow -t ~ home"
echo "=========================================="
