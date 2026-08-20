import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import IslandBackend

RowLayout {
  id: root

  readonly property real dpi: Config.dpiScale

  property real buttonBorderWidth
  property string buttonBorderColor
  property real buttonWidth
  property real buttonHeight
  property real buttonRadius
  property color buttonBgOff
  property color buttonFgOff

  property bool notificationPopup: false
  property bool controlCenterOpen: false
  property bool wifiPanelOpened: false
  property bool btPanelOpened: false
  property bool hasPlayer: false
  property real playerHeight: 0

  anchors.top: parent.top
  anchors.topMargin: hasPlayer ? playerHeight + 92 : 5
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.leftMargin: 3 * dpi
  anchors.rightMargin: 5 * dpi

  onControlCenterOpenChanged: {
    if (!controlCenterOpen) {
      root.wifiPanelOpened = false
      root.btPanelOpened = false
    } else {
      ppBtn.refresh()
    }
  }

  // wifi
  Rectangle {
    id: wifiBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: WifiController.enabled
            ? (wifiHover.hovered ? Qt.lighter(Theme.surface("#212529", 0.8), 1.2) : Theme.surface("#212529", 0.8))
            : (wifiHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: WifiController.enabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: wifiMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    MarqueeText {
        anchors.centerIn: parent
        spacing: 5 * root.dpi
        icon: "\uf1eb"
        iconColor: WifiController.enabled ? "#4282e9" : root.buttonFgOff
        iconFontFamily: Theme.nerdFontFamily
        iconPixelSize: 12

        text: !WifiController.enabled ? "Off"
            : WifiController.currentSsid.length > 0 ? WifiController.currentSsid
            : (WifiController.statusText.length > 0 ? WifiController.statusText : "Not connected")
        color: WifiController.enabled ? Theme.fg : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
        maxWidth: 50
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

  WifiPanel {
    visible: root.wifiPanelOpened
    anchorX: root.mapToGlobal(root.width, 0).x - (600 * root.dpi) - (30 * root.dpi)
    anchorY: wifiBtn.mapToGlobal(0, 0).y
  }

  onNotificationPopupChanged: {
    if (root.notificationPopup) root.wifiPanelOpened = false; root.btPanelOpened = false
  }

  // silent notifications
  Rectangle {
    id: dndBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: notificationModule.dndEnabled
    ? (dndHover.hovered ? Qt.lighter(Theme.surface("#262626", 0.8), 1.2) : Theme.surface("#262626", 0.8))
    : (dndHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: notificationModule.dndEnabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: dndMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Text {
      text: String.fromCodePoint(0xf1f6)
      color: notificationModule.dndEnabled ? "#fff9eb" : root.buttonFgOff
      anchors.centerIn: parent
      font { family: Theme.nerdFontFamily; pixelSize: 13 }
    }
    HoverHandler { id: dndHover }
    MouseArea {
      id: dndMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: notificationModule.dndEnabled = !notificationModule.dndEnabled
    }
  }

  // power profiles
  Rectangle {
    id: ppBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: ppBtn.currentProfile === "power-saver"
           ? (ppHover.hovered ? Qt.lighter(Theme.surface("#262626", 0.8), 1.2) : Theme.surface("#262626", 0.8))
           : (ppHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: ppBtn.currentProfile === "power-saver" ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: ppMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    property string currentProfile: ""
    readonly property var profiles: ["power-saver", "balanced", "performance"]

    function refresh() {
      ppGetProc.running = false
      ppGetProc.running = true
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: 5 * root.dpi
      Text {
        text: ppBtn.currentProfile === "performance" ? String.fromCodePoint(0xf0241) // nf-md-flash
            : ppBtn.currentProfile === "power-saver" ? String.fromCodePoint(0xf032a) // nf-md-leaf
            : String.fromCodePoint(0xf029a) // nf-md-gauge
        color: ppBtn.currentProfile === "performance" ? "#e9c46a" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
      }
      Text {
        text: ppBtn.currentProfile === "" ? "Pwr" : ppBtn.currentProfile
        color: root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
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

  // bluetooth
  Rectangle {
    id: btBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: BluetoothController.enabled
            ? (btHover.hovered ? Qt.lighter(Theme.surface("#212529", 0.8), 1.2) : Theme.surface("#212529", 0.8))
            : (btHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: BluetoothController.enabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: btMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    RowLayout {
      anchors.centerIn: parent
      spacing: 5 * root.dpi
      Text {
        text: "\uf294"
        color: BluetoothController.enabled ? "#4282e9" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 15 }
      }
      MarqueeText {
        text: !BluetoothController.enabled ? "Off"
            : BluetoothController.currentDeviceName.length > 0 ? BluetoothController.currentDeviceName
            : (BluetoothController.statusText.length > 0 ? BluetoothController.statusText : "Not connected")
        color: BluetoothController.enabled ? Theme.fg : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
        maxWidth: 50
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

  BluetoothPanel {
    visible: root.btPanelOpened
    anchorX: root.mapToGlobal(root.width, 0).x + (29 * root.dpi)
    anchorY: btBtn.mapToGlobal(0, 0).y
  }
}
