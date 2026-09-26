#!/usr/bin/env bash
# Color Picker for Niri Wayland
COLOR=$(niri msg pick-color 2>/dev/null)
if [ -n "$COLOR" ]; then
    printf "%s" "$COLOR" | wl-copy
    "$HOME/.local/bin/ringo-shell" call notify post "Color Picked" \
        "$COLOR copied to clipboard" color-management 1 > /dev/null 2>&1 || \
        notify-send -i color-management -a "Ringo Color Picker" "Color Picked" "$COLOR copied to clipboard" -t 3000
fi
