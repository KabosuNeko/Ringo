#!/bin/sh
# Ringo screen recorder — ported from Kumin (Mod+F11)
# Toggle: first press -> Quickshell menu -> start wl-screenrec
#         second press -> stop (SIGINT) + notify
# Modes: only-sound | micro | no-sound (args)
# When called without arg and not recording, delegates to Quickshell RecordMenu.

if ! command -v wl-screenrec > /dev/null 2>&1; then
    if ! command -v wf-recorder > /dev/null 2>&1; then
        notify-send -u critical "Recording System" "Error: wl-screenrec / wf-recorder not installed." -i dialog-error
        exit 1
    fi
fi

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/ringo_recording.pid"
SAVE_DIR="$HOME/Videos"
mkdir -p "$SAVE_DIR"

stop_recording() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill -INT "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
        rm -f "$PID_FILE"
        notify-send -u normal "Recording System" "Saved to $SAVE_DIR" -i video-display
        exit 0
    fi
}

start_recording() {
    chosen="$1"
    FILEPATH="$SAVE_DIR/recording_$(date +%Y%m%d_%H%M%S).mp4"
    RECORDER="wl-screenrec"
    if ! command -v wl-screenrec > /dev/null 2>&1; then
        RECORDER="wf-recorder"
    fi

    case "$chosen" in
        "Only Sound"|only-sound|only_sound|system|monitor)
            if [ "$RECORDER" = "wl-screenrec" ]; then
                wl-screenrec --max-fps 60 --audio --audio-device default.monitor -f "$FILEPATH" &
            else
                wf-recorder --audio --audio-device default.monitor -f "$FILEPATH" &
            fi
            MSG="Recording: System Audio"
            ;;
        "Micro and Sound"|micro|mic|both)
            if [ "$RECORDER" = "wl-screenrec" ]; then
                wl-screenrec --max-fps 60 --audio -f "$FILEPATH" &
            else
                wf-recorder --audio -f "$FILEPATH" &
            fi
            MSG="Recording: Microphone/Default"
            ;;
        "No Sound"|no-sound|no_sound|silent|none|"")
            if [ "$RECORDER" = "wl-screenrec" ]; then
                wl-screenrec --max-fps 60 -f "$FILEPATH" &
            else
                wf-recorder -f "$FILEPATH" &
            fi
            MSG="Recording: No Sound"
            ;;
        *) exit 0 ;;
    esac

    echo $! > "$PID_FILE"
    notify-send "Recording System" "$MSG — press Mod+F11 again to stop" -i video-display
    wait $!
    rm -f "$PID_FILE"
}

# 1) if already recording -> stop
if [ -f "$PID_FILE" ]; then
    stop_recording
fi

# 2) explicit mode arg -> start directly (called from Quickshell menu)
if [ -n "$1" ]; then
    start_recording "$1"
    exit 0
fi

# 3) no arg and not recording -> open Quickshell RecordMenu (no rofi)
if command -v qs > /dev/null 2>&1; then
    qs ipc -p "$HOME/.config/ringo-shell" call recordMenu toggle 2>/dev/null || \
    qs ipc -p "$HOME/.config/ringo-shell" call recordMenu show 2>/dev/null || true
    exit 0
else
    start_recording "No Sound"
fi
