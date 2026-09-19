import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: recordMenu
  property bool shown: false
  property int selectedIndex: 0
  signal closeRequested

  anchors.fill: parent
  color: Theme.bgD1
  radius: 22
  visible: opacity > 0
  opacity: shown ? 1 : 0

  readonly property var items: [
    { icon: "󰕾", label: "System", mode: "only-sound" },
    { icon: "󰍬", label: "Mic+System", mode: "micro" },
    { icon: "󰝟", label: "No Sound", mode: "no-sound" }
  ]

  function activate(index: int): void {
    if (index >= 0 && index < items.length) {
      Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/record.sh", items[index].mode])
    }
    recordMenu.closeRequested()
  }

  focus: true
  Keys.onLeftPressed: recordMenu.selectedIndex = (recordMenu.selectedIndex + items.length - 1) % items.length
  Keys.onRightPressed: recordMenu.selectedIndex = (recordMenu.selectedIndex + 1) % items.length
  Keys.onReturnPressed: recordMenu.activate(recordMenu.selectedIndex)
  Keys.onEnterPressed: recordMenu.activate(recordMenu.selectedIndex)
  Keys.onSpacePressed: recordMenu.activate(recordMenu.selectedIndex)
  Keys.onEscapePressed: recordMenu.closeRequested()

  RowLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    Repeater {
      model: recordMenu.items

      delegate: Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 12
        color: (recordMenu.selectedIndex === index || itemHover.containsMouse) ? Theme.bg5 : Theme.bg2
        border.width: recordMenu.selectedIndex === index ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Text {
            text: modelData.icon
            font.family: Theme.nerdFontFamily
            font.pixelSize: 18
            color: (recordMenu.selectedIndex === index || itemHover.containsMouse) ? Theme.fgL : Theme.fg
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
          onEntered: recordMenu.selectedIndex = index
          onClicked: recordMenu.activate(index)
        }
      }
    }
  }
}
