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
  Behavior on opacity {
    NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
  }

  function activate(index: int): void {
    switch (index) {
      case 0:
        LockController.lock()
        break
      case 1:
        NiriController.suspend()
        break
      case 2:
        NiriController.reboot()
        break
      case 3:
        NiriController.powerOff()
        break
      case 4:
        NiriController.quit()
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
    }
  }
}
