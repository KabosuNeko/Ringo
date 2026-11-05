#!/bin/sh
# Headless check for the JSONC loader and serialized config writes.
# Needs Quickshell, not a compositor: CI runs it with QT_QPA_PLATFORM=offscreen.
set -eu

QS=${1:-qs}
REPO_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

mkdir -p "$TMP/.config/ringo-shell"
cp "$REPO_DIR/home/.config/ringo-shell/Config.qml" "$TMP/.config/ringo-shell/Config.qml"
cat >"$TMP/.config/ringo-shell/qmldir" <<'EOF'
singleton Config 1.0 Config.qml
EOF

cat >"$TMP/.config/ringo-shell/config.jsonc" <<'EOF'
{
  // line comment
  /* block comment */
  // "notificationDisplayTime": 1, (a commented-out key must never be rewritten)
  "displayPicture": "~/.pfp.png",
  "clockFormat": "hh:mm",
  "notificationDisplayTime": 7000,
  "maxNotificationsInStack": 20,
  "osdDuration": 800,
  "avoidDuplicateNotifications": true,
  "idleDimSeconds": 300,
  "idleLockSeconds": 600,
  "idleScreenOffSeconds": 630,
  "idleSuspendSeconds": 660,
}
EOF

cat >"$TMP/.config/ringo-shell/shell.qml" <<'EOF'
import Quickshell
import QtQuick
import "."

ShellRoot {
  Component.onCompleted: console.log("CONFIG_BOOT", Config.notificationDisplayTime)
  Timer {
    interval: 4500
    running: true
    onTriggered: {
      console.log("CONFIG_TEST", Config.notificationDisplayTime, Config.idleLockSeconds)
      Config.setNotificationPolicy(5000, 30, false, 1200)
      second.start()
    }
  }
  Timer {
    id: second
    interval: 200
    onTriggered: {
      Config.setIdleTimer("lock", 700)
      third.start()
    }
  }
  Timer {
    id: third
    interval: 2000
    onTriggered: {
      console.log("CONFIG_WRITE", Config.notificationDisplayTime, Config.idleLockSeconds)
      Qt.quit()
    }
  }
}
EOF

out=$(HOME="$TMP" timeout 12 "$QS" -p "$TMP/.config/ringo-shell/shell.qml" 2>&1) || {
    printf '%s\n' "$out"
    exit 1
}
printf '%s\n' "$out" | grep -q 'CONFIG_TEST 7000 600'
printf '%s\n' "$out" | grep -q 'CONFIG_WRITE 5000 700'
grep -q '"notificationDisplayTime": 5000' "$TMP/.config/ringo-shell/config.jsonc"
grep -q '"idleLockSeconds": 700' "$TMP/.config/ringo-shell/config.jsonc"
grep -q '// line comment' "$TMP/.config/ringo-shell/config.jsonc"
grep -q '/\* block comment \*/' "$TMP/.config/ringo-shell/config.jsonc"
grep -q '// "notificationDisplayTime": 1, (a commented-out' "$TMP/.config/ringo-shell/config.jsonc"

printf 'config jsonc: ok\n'
