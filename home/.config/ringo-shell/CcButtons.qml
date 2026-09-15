import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import IslandBackend

Item {
  id: root

  readonly property real dpi: Config.dpiScale

  property bool notificationPopup: false
  property bool controlCenterOpen: false
  property bool wifiPanelOpened: false
  property bool btPanelOpened: false
  property bool hasPlayer: false
  property real playerHeight: 0

  implicitHeight: bentoGrid.implicitHeight

  onControlCenterOpenChanged: {
    if (!controlCenterOpen) {
      root.wifiPanelOpened = false
      root.btPanelOpened = false
    } else {
      ppBtn.refresh()
    }
  }

  onNotificationPopupChanged: {
    if (root.notificationPopup) {
      root.wifiPanelOpened = false
      root.btPanelOpened = false
    }
  }

  GridLayout {
    id: bentoGrid
    anchors.fill: parent
    columns: 2
    rowSpacing: 6
    columnSpacing: 6

    Rectangle {
      id: wifiBtn
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 12
      color: WifiController.enabled
              ? (wifiHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (wifiHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: WifiController.enabled ? Theme.accent : Theme.cardBorder
      scale: wifiMouse.pressed ? 0.96 : (wifiHover.hovered ? 1.01 : 1.0)
      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }
      Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 8
          color: WifiController.enabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "\uf1eb"
            color: WifiController.enabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: 13 }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Wi-Fi"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: !WifiController.enabled ? "Disabled"
                : WifiController.currentSsid.length > 0 ? WifiController.currentSsid
                : (WifiController.statusText.length > 0 ? WifiController.statusText : "Disconnected")
            color: WifiController.enabled ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      HoverHandler { id: wifiHover }
      MouseArea {
        id: wifiMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            root.wifiPanelOpened = !root.wifiPanelOpened
            if (root.wifiPanelOpened && WifiController.enabled) WifiController.refreshNetworks(true)
            return
          }
          WifiController.setEnabled(!WifiController.enabled)
        }
      }
    }

    Rectangle {
      id: btBtn
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 12
      color: BluetoothController.enabled
              ? (btHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (btHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: BluetoothController.enabled ? Theme.accent : Theme.cardBorder
      scale: btMouse.pressed ? 0.96 : (btHover.hovered ? 1.01 : 1.0)
      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }
      Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 8
          color: BluetoothController.enabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "\uf294"
            color: BluetoothController.enabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: 13 }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Bluetooth"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: !BluetoothController.enabled ? "Disabled"
                : BluetoothController.currentDeviceName.length > 0 ? BluetoothController.currentDeviceName
                : (BluetoothController.statusText.length > 0 ? BluetoothController.statusText : "Disconnected")
            color: BluetoothController.enabled ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      HoverHandler { id: btHover }
      MouseArea {
        id: btMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            root.btPanelOpened = !root.btPanelOpened
            if (root.btPanelOpened && BluetoothController.enabled) BluetoothController.refreshDevices(true)
            return
          }
          BluetoothController.setEnabled(!BluetoothController.enabled)
        }
      }
    }

    Rectangle {
      id: ppBtn
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 12
      property string currentProfile: ""
      readonly property bool isCustomProfile: ppBtn.currentProfile !== "balanced" && ppBtn.currentProfile !== ""
      readonly property var profiles: ["power-saver", "balanced", "performance"]

      color: isCustomProfile
             ? (ppHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
             : (ppHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: isCustomProfile ? Theme.accent : Theme.cardBorder
      scale: ppMouse.pressed ? 0.96 : (ppHover.hovered ? 1.01 : 1.0)
      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }
      Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

      function refresh() {
        ppGetProc.running = false
        ppGetProc.running = true
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 8
          color: isCustomProfile ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: ppBtn.currentProfile === "performance" ? String.fromCodePoint(0xf135)
                : ppBtn.currentProfile === "power-saver" ? String.fromCodePoint(0xf032a)
                : String.fromCodePoint(0xf029a)
            color: isCustomProfile ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: 13 }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Performance"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: ppBtn.currentProfile === "" ? "Balanced"
                : ppBtn.currentProfile.charAt(0).toUpperCase() + ppBtn.currentProfile.slice(1)
            color: isCustomProfile ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      HoverHandler { id: ppHover }
      MouseArea {
        id: ppMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          const idx = ppBtn.profiles.indexOf(ppBtn.currentProfile)
          const next = ppBtn.profiles[(idx + 1) % ppBtn.profiles.length]
          ppSetProc.command = ["powerprofilesctl", "set", next]
          ppSetProc.running = false
          ppSetProc.running = true
        }
      }

      Process {
        id: ppGetProc
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector {
          onStreamFinished: ppBtn.currentProfile = text.trim()
        }
      }

      Process {
        id: ppSetProc
        command: ["powerprofilesctl", "set", "balanced"]
        running: false
        stdout: StdioCollector {
          onStreamFinished: ppBtn.refresh()
        }
      }
    }

    Rectangle {
      id: dndBtn
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 12
      color: notificationModule.dndEnabled
              ? (dndHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (dndHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: notificationModule.dndEnabled ? Theme.accent : Theme.cardBorder
      scale: dndMouse.pressed ? 0.96 : (dndHover.hovered ? 1.01 : 1.0)
      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }
      Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 8
          color: notificationModule.dndEnabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xf1f6)
            color: notificationModule.dndEnabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: 13 }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Quiet Mode"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: notificationModule.dndEnabled ? "Active" : "Off"
            color: notificationModule.dndEnabled ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      HoverHandler { id: dndHover }
      MouseArea {
        id: dndMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notificationModule.dndEnabled = !notificationModule.dndEnabled
      }
    }
  }

  WifiPanel {
    visible: root.wifiPanelOpened
    anchorX: Math.max(8, root.mapToGlobal(root.width, 0).x + (20 * root.dpi))
    anchorY: wifiBtn.mapToGlobal(0, 0).y + (46 * root.dpi)
  }

  BluetoothPanel {
    visible: root.btPanelOpened
    anchorX: Quickshell.screens[0]
             ? Quickshell.screens[0].x + Quickshell.screens[0].width
               - (root.mapToGlobal(root.width, 0).x + (20 * root.dpi))
               - (238 * root.dpi)
             : 0
    anchorY: btBtn.mapToGlobal(0, 0).y + (46 * root.dpi)
  }
}
