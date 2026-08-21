import Quickshell
import Quickshell.Io
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
  Behavior on opacity {
    NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
  }

  function activate(index: int): void {
    switch (index) {
      case 0:
        LockController.lock()
        break
      case 1:
        sleepProc.startDetached()
        break
      case 2:
        rebootProc.startDetached()
        break
      case 3:
        shutdownProc.startDetached()
        break
      case 4:
        logoutProc.startDetached()
        break
    }
    powerMenu.closeRequested()
  }

  focus: true
  Keys.onLeftPressed: powerMenu.selectedIndex = (powerMenu.selectedIndex + 4) % 5
  Keys.onRightPressed: powerMenu.selectedIndex = (powerMenu.selectedIndex + 1) % 5
  Keys.onReturnPressed: powerMenu.activate(powerMenu.selectedIndex)
  Keys.onEnterPressed: powerMenu.activate(powerMenu.selectedIndex)
  Keys.onSpacePressed: powerMenu.activate(powerMenu.selectedIndex)
  Keys.onEscapePressed: powerMenu.closeRequested()

  RowLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (powerMenu.selectedIndex === 0 || lockHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: powerMenu.selectedIndex === 0 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰌾"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (powerMenu.selectedIndex === 0 || lockHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Lock"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: lockHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: powerMenu.selectedIndex = 0
        onClicked: powerMenu.activate(0)
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (powerMenu.selectedIndex === 1 || sleepHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: powerMenu.selectedIndex === 1 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰤄"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (powerMenu.selectedIndex === 1 || sleepHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Sleep"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: sleepHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: powerMenu.selectedIndex = 1
        onClicked: powerMenu.activate(1)
      }
      Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (powerMenu.selectedIndex === 2 || rebootHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: powerMenu.selectedIndex === 2 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰜉"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (powerMenu.selectedIndex === 2 || rebootHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Reboot"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: rebootHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: powerMenu.selectedIndex = 2
        onClicked: powerMenu.activate(2)
      }
      Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (powerMenu.selectedIndex === 3 || shutdownHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: powerMenu.selectedIndex === 3 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰐥"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (powerMenu.selectedIndex === 3 || shutdownHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Shutdown"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: shutdownHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: powerMenu.selectedIndex = 3
        onClicked: powerMenu.activate(3)
      }
      Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
    }

    // logout (niri session quit -> back to ly)
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: (powerMenu.selectedIndex === 4 || logoutHover.containsMouse) ? Theme.bg5 : Theme.bg2
      border.width: powerMenu.selectedIndex === 4 ? 2 : 0
      border.color: Theme.accent
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰿅"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: (powerMenu.selectedIndex === 4 || logoutHover.containsMouse) ? Theme.fgL : Theme.fg
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "Logout"
          font.pixelSize: 9
          color: Theme.fg3
          Layout.alignment: Qt.AlignHCenter
        }
      }
      MouseArea {
        id: logoutHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: powerMenu.selectedIndex = 4
        onClicked: powerMenu.activate(4)
      }
      Process { id: logoutProc; command: ["bash", "-c", "niri msg action quit"]; running: false }
    }
  }
}
