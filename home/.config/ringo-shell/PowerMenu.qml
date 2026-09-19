import Quickshell
import IslandBackend
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: powerMenu
  property bool shown: false
  property int selectedIndex: 0
  signal closeRequested

  anchors.fill: parent
  color: Theme.bgD1
  radius: 22
  visible: opacity > 0
  opacity: shown ? 1 : 0

  readonly property var items: [
    { icon: "󰌾", label: "Lock", action: () => LockController.lock() },
    { icon: "󰤄", label: "Sleep", action: () => NiriController.suspend() },
    { icon: "󰜉", label: "Reboot", action: () => NiriController.reboot() },
    { icon: "󰐥", label: "Shutdown", action: () => NiriController.powerOff() },
    { icon: "󰿅", label: "Logout", action: () => NiriController.quit() }
  ]

  function activate(index: int): void {
    if (index >= 0 && index < items.length) {
      items[index].action()
    }
    powerMenu.closeRequested()
  }

  focus: true
  Keys.onLeftPressed: powerMenu.selectedIndex = (powerMenu.selectedIndex + items.length - 1) % items.length
  Keys.onRightPressed: powerMenu.selectedIndex = (powerMenu.selectedIndex + 1) % items.length
  Keys.onReturnPressed: powerMenu.activate(powerMenu.selectedIndex)
  Keys.onEnterPressed: powerMenu.activate(powerMenu.selectedIndex)
  Keys.onSpacePressed: powerMenu.activate(powerMenu.selectedIndex)
  Keys.onEscapePressed: powerMenu.closeRequested()

  RowLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    Repeater {
      model: powerMenu.items

      delegate: Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 12
        color: (powerMenu.selectedIndex === index || itemHover.containsMouse) ? Theme.bg5 : Theme.bg2
        border.width: powerMenu.selectedIndex === index ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Text {
            text: modelData.icon
            font.family: Theme.nerdFontFamily
            font.pixelSize: 18
            color: (powerMenu.selectedIndex === index || itemHover.containsMouse) ? Theme.fgL : Theme.fg
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: modelData.label
            font.pixelSize: 9
            color: Theme.fg3
            Layout.alignment: Qt.AlignHCenter
          }
        }

        MouseArea {
          id: itemHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: powerMenu.selectedIndex = index
          onClicked: powerMenu.activate(index)
        }
      }
    }
  }
}
