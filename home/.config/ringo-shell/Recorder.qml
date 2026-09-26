pragma Singleton
import Quickshell
import QtQuick
import IslandBackend

// Screen recording state, taken from the pid file record.sh keeps in the
// runtime directory. The bar shows a red dot and the elapsed time while a
// recording is running; clicking the chip stops it.
Singleton {
  id: root

  readonly property string pidFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ringo_recording.pid"

  property bool active: false
  property int elapsedSeconds: 0

  readonly property string elapsedText: {
    const pad = (n) => (n < 10 ? "0" + n : "" + n)
    const hours = Math.floor(elapsedSeconds / 3600)
    const minutes = Math.floor((elapsedSeconds % 3600) / 60)
    const seconds = elapsedSeconds % 60
    return hours > 0
      ? hours + ":" + pad(minutes) + ":" + pad(seconds)
      : pad(minutes) + ":" + pad(seconds)
  }

  function stop(): void {
    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/record.sh"])
  }

  function refresh(): void {
    if (!Tools.fileExists(root.pidFile)) {
      if (root.active) {
        root.active = false
        root.elapsedSeconds = 0
      }
      return
    }

    const pid = Tools.readText(root.pidFile).trim()
    // /proc/<pid>/stat field 22 is the start time in clock ticks; the comm field
    // can contain spaces, so parse from the last ')'.
    const stat = Tools.readText("/proc/" + pid + "/stat")
    const close = stat.lastIndexOf(")")
    if (pid.length === 0 || close < 0) {
      root.active = false
      root.elapsedSeconds = 0
      return
    }

    const fields = stat.slice(close + 2).split(" ")
    const startTicks = parseFloat(fields[19])
    const uptime = parseFloat(Tools.readText("/proc/uptime").split(" ")[0])
    if (!isFinite(startTicks) || !isFinite(uptime)) {
      root.active = false
      root.elapsedSeconds = 0
      return
    }

    root.active = true
    root.elapsedSeconds = Math.max(0, Math.floor(uptime - startTicks / 100))
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
