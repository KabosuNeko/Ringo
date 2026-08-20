import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  spacing: 4 * Config.paddingScale

  Text {
    text: String.fromCodePoint(0xf035b) // nf-md-memory
    color: Theme.accent
    font { family: Theme.nerdFontFamily; pixelSize: 10 * Config.pillScale }
  }

  Text {
    id: ramText
    text: "--"
    color: Theme.fg
    font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
  }

  Process {
    id: ramProc
    command: ["sh", "-c", "free -m | awk '/Mem:/ { used=$3; if (used >= 1024) printf \"%.1fG\", used/1024; else printf \"%dM\", used }'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        ramText.text = this.text.trim()
        ramProc.running = false
      }
    }
  }

  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: {
      ramProc.running = false
      ramProc.running = true
    }
  }
}
