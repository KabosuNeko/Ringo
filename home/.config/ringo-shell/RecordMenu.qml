import Quickshell
import Quickshell.Io
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
  Behavior on opacity {
    NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
  }

  function activate(index: int): void {
    switch (index) {
      case 0:
        onlySoundProc.startDetached()
        break
      case 1:
        microProc.startDetached()
        break
      case 2:
        noSoundProc.startDetached()
        break
    }
    recordMenu.closeRequested()
  }

  focus: true
  Keys.onLeftPressed: recordMenu.selectedIndex = (recordMenu.selectedIndex + 2) % 3
  Keys.onRightPressed: recordMenu.selectedIndex = (recordMenu.selectedIndex + 1) % 3
  Keys.onReturnPressed: recordMenu.activate(recordMenu.selectedIndex)
  Keys.onEnterPressed: recordMenu.activate(recordMenu.selectedIndex)
  Keys.onSpacePressed: recordMenu.activate(recordMenu.selectedIndex)
  Keys.onEscapePressed: recordMenu.closeRequested()

  RowLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (recordMenu.selectedIndex === 0 || onlyHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: recordMenu.selectedIndex === 0 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰕾"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (recordMenu.selectedIndex === 0 || onlyHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "System"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: onlyHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: recordMenu.selectedIndex = 0
        onClicked: recordMenu.activate(0)
      }
      Process { id: onlySoundProc; command: ["bash", "-c", "$HOME/.local/bin/record.sh only-sound"]; running: false }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (recordMenu.selectedIndex === 1 || microHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: recordMenu.selectedIndex === 1 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰍬"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (recordMenu.selectedIndex === 1 || microHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Mic+System"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: microHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: recordMenu.selectedIndex = 1
        onClicked: recordMenu.activate(1)
      }
      Process { id: microProc; command: ["bash", "-c", "$HOME/.local/bin/record.sh micro"]; running: false }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (recordMenu.selectedIndex === 2 || noSoundHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: recordMenu.selectedIndex === 2 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰝟"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (recordMenu.selectedIndex === 2 || noSoundHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "No Sound"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: noSoundHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: recordMenu.selectedIndex = 2
        onClicked: recordMenu.activate(2)
      }
      Process { id: noSoundProc; command: ["bash", "-c", "$HOME/.local/bin/record.sh no-sound"]; running: false }
    }
  }
}
