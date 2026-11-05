import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Workspace dots for one output, fed by `niri msg -j event-stream`: niri pushes
// every change, nothing polls. The active workspace is the long dot; click a dot
// to focus that workspace. Hidden at rest so the clock stays centred: shown while
// the island is hovered, and briefly (an OSD's time) after a workspace switch.
Item {
  id: root

  property string output: ""
  property bool hovered: false
  property bool peeking: false
  property var all: []
  // this output's workspaces by index, minus niri's trailing empty one
  readonly property var shown: {
    const list = root.all
      .filter(w => root.output === "" || w.output === root.output)
      .sort((a, b) => a.idx - b.idx)
    const last = list[list.length - 1]
    if (list.length > 1 && last && last.active_window_id === null && !last.is_active) list.pop()
    return list
  }

  // the bar row's spacing, folded into the slide so the gap opens with the dots
  // instead of popping in when the item turns visible
  property real gap: 0
  readonly property bool open: shown.length > 1 && (hovered || peeking)

  implicitHeight: dots.implicitHeight
  implicitWidth: open ? dots.implicitWidth + gap : 0
  Layout.rightMargin: -gap
  clip: true
  opacity: open ? 1 : 0

  // in-out, not out: an out-curve does ~80% of the slide in the first frames,
  // which reads as a jump rather than a glide
  Behavior on implicitWidth { NumberAnimation { duration: Theme.motionOverlay; easing.type: Theme.easeInOut } }
  Behavior on opacity { NumberAnimation { duration: Theme.motionOverlay; easing.type: Theme.easeInOut } }

  function handle(line: string): void {
    // the stream also carries every window/title change; only workspace events matter
    if (!line.startsWith('{"Workspace')) return
    let event
    try { event = JSON.parse(line) } catch (e) { return }

    if (event.WorkspacesChanged) {
      root.all = event.WorkspacesChanged.workspaces
      return
    }
    const activated = event.WorkspaceActivated
    if (activated) {
      const target = root.all.find(w => w.id === activated.id)
      if (!target) return
      if (activated.focused) {
        root.peeking = true
        peekTimer.restart()
      }
      root.all = root.all.map(w => Object.assign({}, w, {
        is_active: w.output === target.output ? w.id === activated.id : w.is_active,
        is_focused: activated.focused ? w.id === activated.id : w.is_focused
      }))
      return
    }
    const urgency = event.WorkspaceUrgencyChanged
    if (urgency)
      root.all = root.all.map(w => w.id === urgency.id ? Object.assign({}, w, { is_urgent: urgency.urgent }) : w)
  }

  Process {
    id: stream
    running: true
    command: ["niri", "msg", "-j", "event-stream"]
    stdout: SplitParser { onRead: line => root.handle(line) }
    // niri restarted or the socket dropped: reconnect after a pause
    onExited: reconnect.start()
  }

  Timer {
    id: peekTimer
    interval: Config.osdDuration
    onTriggered: root.peeking = false
  }

  Timer {
    id: reconnect
    interval: 2000
    onTriggered: stream.running = true
  }

  RowLayout {
    id: dots
    // pinned next to the clock, so the dots slide out with the island's edge
    anchors.right: parent.right
    anchors.rightMargin: root.gap
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4 * Config.paddingScale

    // A count model keeps the delegates alive across updates, so the dots animate.
    Repeater {
      model: root.shown.length

      Rectangle {
        required property int index
        readonly property var workspace: root.shown[index]

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: (workspace && workspace.is_active ? 12 : 4) * Config.pillScale
        Layout.preferredHeight: 4 * Config.pillScale
        radius: height / 2
        color: !workspace ? Theme.fg5
             : workspace.is_urgent ? Theme.warning
             : workspace.is_active ? Theme.accent
             : workspace.active_window_id !== null ? Theme.fg4 : Theme.fg5

        Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easeOut } }
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          Accessible.role: Accessible.Button
          Accessible.name: workspace ? "Workspace " + workspace.idx : ""
          // shortcut: focus-workspace takes an index on the focused output, so on a
          // multi-monitor setup a dot of the other output targets this one; upgrade
          // to focus-monitor + focus-workspace if a second output is ever used.
          onClicked: if (workspace) Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(workspace.idx)])
        }
      }
    }
  }
}
