#!/bin/sh
# Screen recorder (wl-screenrec) on Mod+F11: first press opens the shell's menu,
# second stops it. Modes: only-sound | micro | no-sound.

# Notifications go through the shell's own server when it is running.
notify() { # summary, body, icon, urgency
    "$HOME/.local/bin/ringo-shell" call notify post "$1" "$2" "$3" "$4" > /dev/null 2>&1 || \
        notify-send -i "$3" "$1" "$2"
}

if ! command -v wl-screenrec > /dev/null 2>&1; then
    notify "Recording System" "Error: wl-screenrec not installed." dialog-error 2
    exit 1
fi

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/ringo_recording.pid"
SAVE_DIR="$HOME/Videos"
REC_PID=""
REC_FILE=""

mkdir -p "$SAVE_DIR"

# A PID file can outlive a crashed recorder and its PID can be reused. Never
# signal a process that is not actually wl-screenrec.
is_recorder() {
    [ -n "$1" ] || return 1
    kill -0 "$1" 2>/dev/null || return 1
    comm=""
    read -r comm < "/proc/$1/comm" 2>/dev/null || return 1
    [ "$comm" = "wl-screenrec" ]
}

cleanup() {
    if [ -n "$REC_PID" ] && is_recorder "$REC_PID"; then
        kill -INT "$REC_PID" 2>/dev/null || true
        wait "$REC_PID" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

stop_recording() {
    [ -f "$PID_FILE" ] || return 1

    PID=""
    FILE=""
    if ! read -r PID FILE < "$PID_FILE"; then
        rm -f "$PID_FILE"
        notify "Recording System" "No active recording state was readable." dialog-information 1
        exit 0
    fi

    if ! is_recorder "$PID"; then
        rm -f "$PID_FILE"
        notify "Recording System" "No active recording; removed a stale state file." dialog-information 1
        exit 0
    fi

    kill -INT "$PID" 2>/dev/null || true
    # Tell the waiting start_recording process to stay quiet; it checks this
    # file after wait and this process reports the outcome.
    rm -f "$PID_FILE"

    if [ "$PID" = "$REC_PID" ]; then
        wait "$PID" 2>/dev/null || true
    else
        i=0
        while is_recorder "$PID" && [ "$i" -lt 50 ]; do
            sleep 0.1
            i=$((i + 1))
        done
    fi

    if [ -n "$FILE" ] && [ -s "$FILE" ]; then
        notify "Recording System" "Saved to $SAVE_DIR" video-display 1
    else
        notify "Recording System" "Recording stopped, but no file was written." dialog-error 2
    fi
    exit 0
}

start_recording() {
    chosen="$1"
    FILEPATH="$SAVE_DIR/recording_$(date +%Y%m%d_%H%M%S).mp4"

    case "$chosen" in
        "Only Sound"|only-sound|only_sound|system|monitor)
            wl-screenrec --max-fps 60 --audio --audio-device default.monitor -f "$FILEPATH" &
            MSG="Recording: System Audio"
            ;;
        "Micro and Sound"|micro|mic|both)
            wl-screenrec --max-fps 60 --audio -f "$FILEPATH" &
            MSG="Recording: Microphone/Default"
            ;;
        "No Sound"|no-sound|no_sound|silent|none|"")
            wl-screenrec --max-fps 60 -f "$FILEPATH" &
            MSG="Recording: No Sound"
            ;;
        *) exit 0 ;;
    esac

    REC_PID=$!
    REC_FILE="$FILEPATH"
    printf '%s %s\n' "$REC_PID" "$REC_FILE" > "$PID_FILE"
    notify "Recording System" "$MSG - press Mod+F11 again to stop" video-display 1

    wait "$REC_PID"
    STATUS=$?

    # stop_recording removes the file before waiting and reports the result.
    # If it is still there, this recorder exited on its own.
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
        if [ "$STATUS" -eq 0 ] && [ -s "$REC_FILE" ]; then
            notify "Recording System" "Saved to $SAVE_DIR" video-display 1
        else
            notify "Recording System" "Recording failed; no file was saved." dialog-error 2
        fi
    fi
    REC_PID=""
    REC_FILE=""
}

if [ -f "$PID_FILE" ]; then
    stop_recording
fi

if [ -n "$1" ]; then
    start_recording "$1"
    exit 0
fi

if [ -x "$HOME/.local/bin/ringo-shell" ]; then
    "$HOME/.local/bin/ringo-shell" call recordMenu toggle 2>/dev/null || \
    "$HOME/.local/bin/ringo-shell" call recordMenu open 2>/dev/null || true
elif command -v qs > /dev/null 2>&1; then
    qs ipc -p "$HOME/.config/ringo-shell" call recordMenu toggle 2>/dev/null || \
    qs ipc -p "$HOME/.config/ringo-shell" call recordMenu open 2>/dev/null || true
    exit 0
else
    start_recording "No Sound"
fi
