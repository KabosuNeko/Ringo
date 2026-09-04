import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import IslandBackend

RowLayout {
  id: root
  signal volumeChanged
  onVolChanged: root.volumeChanged()
  onMutedChanged: root.volumeChanged()
  property string fg: Theme.fg
  property string mutedFg: "#fb2a2a"
  property var sink: Pipewire.defaultAudioSink
  readonly property bool ready: sink && sink.ready
  readonly property bool muted: ready && sink.audio.muted
  readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0

  readonly property var sinkProps: ready ? sink.properties : ({})

  readonly property string activePort: AudioController.activePort
  readonly property bool isHeadphone: AudioController.isHeadphone
  spacing: 4 * Config.paddingScale

  property string icon: {
    if (!ready || muted) return isHeadphone ? "\uf025" : String.fromCodePoint(0xf0581)
    if (isHeadphone) return "\uee58"
    if (vol === 0) return String.fromCodePoint(0xf0581)
    if (vol < 40) return String.fromCodePoint(0xf0580)
    return String.fromCodePoint(0xf057e)
  }

  Text {
    text: root.icon

    color: {
      if (root.muted || vol === 0) {
        return root.mutedFg
      }
      return root.fg
    }

    font.family: Theme.nerdFontFamily
    font.pixelSize: 10 * Config.pillScale
  }

  MouseArea {
    id: audioMuted
    cursorShape: Qt.PointingHandCursor
    onClicked: sink.audio.muted = !sink.audio.muted
    hoverEnabled: true
  }

  Text {
    text: {
      if (!root.ready) return "-"
      if (root.muted) return "0%"
      return root.vol + "%"
    }
    color: fg

    font {
      pixelSize: 10 * Config.pillScale
      family: Theme.fontFamily
      weight: 500
    }
  }

  PwObjectTracker {
    objects: [root.sink]
  }
}
