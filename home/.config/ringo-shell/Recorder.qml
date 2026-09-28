pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import IslandBackend

// recording state from the pid file record.sh keeps in XDG_RUNTIME_DIR
Singleton {
  id: root

  readonly property string pidFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ringo_recording.pid"

  property bool active: false

  function refresh(): void {
    root.active = Tools.fileExists(root.pidFile)
  }

  // pid file absent is the normal idle state, hence printErrors: false
  FileView {
    path: root.pidFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
