pragma Singleton
import Quickshell
import QtQuick
import IslandBackend

// Screen recording state, taken from the pid file record.sh keeps in the
// runtime directory. The bar shows a red dot while a recording is running.
Singleton {
  id: root

  readonly property string pidFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ringo_recording.pid"

  property bool active: false

  function refresh(): void {
    root.active = Tools.fileExists(root.pidFile)
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
