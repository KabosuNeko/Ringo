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

  property color buttonBgOn: Theme.focusBg

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

  Rectangle {
    id: wifiBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: WifiController.enabled
            ? (wifiHover.hovered ? Qt.lighter(root.buttonBgOn, 1.2) : root.buttonBgOn)
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
        iconColor: WifiController.enabled ? Theme.accent : root.buttonFgOff
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
    // Open right next to the control center's right edge (same spot the
    // bluetooth panel used to take); clamp to the screen edge so the panel
    // never lands off-screen.
    anchorX: Math.max(8, root.mapToGlobal(root.width, 0).x + (29 * root.dpi))
    anchorY: wifiBtn.mapToGlobal(0, 0).y + (40 * root.dpi)
  }

  onNotificationPopupChanged: {
    if (root.notificationPopup) {
      root.wifiPanelOpened = false
      root.btPanelOpened = false
    }
  }

  Rectangle {
    id: dndBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: notificationModule.dndEnabled
    ? (dndHover.hovered ? Qt.lighter(root.buttonBgOn, 1.2) : root.buttonBgOn)
    : (dndHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: notificationModule.dndEnabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: dndMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Text {
      text: String.fromCodePoint(0xf1f6)
      color: notificationModule.dndEnabled ? Theme.accent : root.buttonFgOff
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

  Rectangle {
    id: ppBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: (ppBtn.currentProfile !== "balanced" && ppBtn.currentProfile !== "")
           ? (ppHover.hovered ? Qt.lighter(root.buttonBgOn, 1.2) : root.buttonBgOn)
           : (ppHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: (ppBtn.currentProfile !== "balanced" && ppBtn.currentProfile !== "") ? 0 : buttonBorderWidth
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
        text: ppBtn.currentProfile === "performance" ? String.fromCodePoint(0xf135) // nf-fa-rocket
            : ppBtn.currentProfile === "power-saver" ? String.fromCodePoint(0xf032a) // nf-md-leaf
            : String.fromCodePoint(0xf029a) // nf-md-gauge
        color: (ppBtn.currentProfile !== "balanced" && ppBtn.currentProfile !== "") ? Theme.accent : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
      }
      Text {
        text: ppBtn.currentProfile === "" ? "Pwr"
            : ppBtn.currentProfile.charAt(0).toUpperCase() + ppBtn.currentProfile.slice(1)
        color: (ppBtn.currentProfile !== "balanced" && ppBtn.currentProfile !== "") ? Theme.fg : root.buttonFgOff
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

  Rectangle {
    id: btBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen
    color: BluetoothController.enabled
            ? (btHover.hovered ? Qt.lighter(root.buttonBgOn, 1.2) : root.buttonBgOn)
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
        color: BluetoothController.enabled ? Theme.accent : root.buttonFgOff
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
    // Mirror of the wifi panel position across the screen center (the bar
    // is centered, so this lands the panel symmetrically on the right
    // side of the bar instead of glued to the screen edge).
    anchorX: Quickshell.screens[0]
             ? Quickshell.screens[0].x + Quickshell.screens[0].width
               - (root.mapToGlobal(root.width, 0).x + (29 * root.dpi))
               - (238 * root.dpi)
             : 0
    anchorY: btBtn.mapToGlobal(0, 0).y + (40 * root.dpi)
  }
}
