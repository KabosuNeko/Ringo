pragma Singleton
import Quickshell
import Quickshell.Io
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

  // The file is written once when a recording starts and removed when it stops,
  // so watch it instead of polling once a second. No pid file is the normal idle
  // state, hence printErrors: false.
  FileView {
    path: root.pidFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
