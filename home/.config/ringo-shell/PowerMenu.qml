import Quickshell
import Quickshell.Io
import IslandBackend
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: powerMenu
  property bool shown: false
  signal closeRequested

  anchors.fill: parent
  color: Theme.bgD1
  radius: 22
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity {
    NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
  }

  focus: true
  Keys.onEscapePressed: powerMenu.closeRequested()

  RowLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    // lock
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: lockHover.containsMouse ? Theme.bg5 : Theme.bg2
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰌾"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: lockHover.containsMouse ? Theme.fgL : Theme.fg
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
        onClicked: {
          LockController.lock()
          powerMenu.closeRequested()
        }
      }
    }

    // sleep
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: sleepHover.containsMouse ? Theme.bg5 : Theme.bg2
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰤄"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: sleepHover.containsMouse ? Theme.fgL : Theme.fg
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
        onClicked: {
          sleepProc.running = false
          sleepProc.running = true
          powerMenu.closeRequested()
        }
      }
      Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
    }

    // reboot
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: rebootHover.containsMouse ? Theme.bg5 : Theme.bg2
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰜉"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: rebootHover.containsMouse ? Theme.fgL : Theme.fg
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
        onClicked: {
          rebootProc.running = false
          rebootProc.running = true
          powerMenu.closeRequested()
        }
      }
      Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
    }

    // shutdown
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: shutdownHover.containsMouse ? Theme.bg5 : Theme.bg2
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰐥"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: shutdownHover.containsMouse ? Theme.fgL : Theme.fg
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
        onClicked: {
          shutdownProc.running = false
          shutdownProc.running = true
          powerMenu.closeRequested()
        }
      }
      Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
    }

    // logout (niri session quit -> back to ly)
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 12
      color: logoutHover.containsMouse ? Theme.bg5 : Theme.bg2
      Behavior on color { ColorAnimation { duration: 120 } }
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
          text: "󰿅"
          font.family: Theme.nerdFontFamily
          font.pixelSize: 18
          color: logoutHover.containsMouse ? Theme.fgL : Theme.fg
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
        onClicked: {
          logoutProc.running = false
          logoutProc.running = true
          powerMenu.closeRequested()
        }
      }
      Process { id: logoutProc; command: ["bash", "-c", "niri msg action quit"]; running: false }
    }
  }
}