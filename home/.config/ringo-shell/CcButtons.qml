import QtQuick
import QtQuick.Layouts
import Quickshell
import IslandBackend

Item {
  id: root

  readonly property real dpi: Config.dpiScale

  property bool controlCenterOpen: false
  readonly property bool airplaneMode: !WifiController.enabled && !BluetoothController.enabled

  signal settingsRequested(string page)

  function setAirplaneMode(on: bool): void {
    WifiController.setEnabled(!on)
    BluetoothController.setEnabled(!on)
  }

  function toggleAirplaneMode(): void {
    setAirplaneMode(!airplaneMode)
  }

  implicitHeight: bentoGrid.implicitHeight

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
      radius: Theme.radiusLg
      color: WifiController.enabled
              ? (wifiHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (wifiHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: WifiController.enabled ? Theme.accent : Theme.cardBorder
      Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: Theme.radiusMd
          color: WifiController.enabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: Theme.motionBase } }

          Text {
            anchors.centerIn: parent
            text: "\uf1eb"
            color: WifiController.enabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Wi-fi"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 600 }
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: !WifiController.enabled ? "Disabled"
                : WifiController.currentSsid.length > 0 ? WifiController.currentSsid
                : (WifiController.statusText.length > 0 ? WifiController.statusText : "Disconnected")
            color: WifiController.enabled ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
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
        // Right-click now opens the Wi-fi page inside the Settings menu.
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            root.settingsRequested("wifi")
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
      radius: Theme.radiusLg
      color: BluetoothController.enabled
              ? (btHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (btHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: BluetoothController.enabled ? Theme.accent : Theme.cardBorder
      Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: Theme.radiusMd
          color: BluetoothController.enabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: Theme.motionBase } }

          Text {
            anchors.centerIn: parent
            text: "\uf294"
            color: BluetoothController.enabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Bluetooth"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 600 }
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: !BluetoothController.enabled ? "Disabled"
                : BluetoothController.currentDeviceName.length > 0 ? BluetoothController.currentDeviceName
                : (BluetoothController.statusText.length > 0 ? BluetoothController.statusText : "Disconnected")
            color: BluetoothController.enabled ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
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
        // Right-click now opens the Bluetooth page inside the Settings menu.
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            root.settingsRequested("bluetooth")
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
      radius: Theme.radiusLg
      readonly property string currentProfile: PowerProfileController.activeProfile
      readonly property bool isCustomProfile: currentProfile !== "balanced" && currentProfile !== ""

      color: isCustomProfile
             ? (ppHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
             : (ppHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: isCustomProfile ? Theme.accent : Theme.cardBorder
      Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: Theme.radiusMd
          color: ppBtn.isCustomProfile ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: Theme.motionBase } }

          Text {
            anchors.centerIn: parent
            text: ppBtn.currentProfile === "performance" ? String.fromCodePoint(0xf135)
                : ppBtn.currentProfile === "power-saver" ? String.fromCodePoint(0xf032a)
                : String.fromCodePoint(0xf029a)
            color: ppBtn.isCustomProfile ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Performance"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 600 }
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: ppBtn.currentProfile === "" ? "Balanced"
                : ppBtn.currentProfile.charAt(0).toUpperCase() + ppBtn.currentProfile.slice(1)
            color: ppBtn.isCustomProfile ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
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
        onClicked: PowerProfileController.cycleNext()
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: Theme.radiusLg
      color: notificationModule.dndEnabled
              ? (dndHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (dndHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: notificationModule.dndEnabled ? Theme.accent : Theme.cardBorder
      Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: Theme.radiusMd
          color: notificationModule.dndEnabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: Theme.motionBase } }

          Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xf1f6)
            color: notificationModule.dndEnabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Quiet mode"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 600 }
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: notificationModule.dndEnabled ? "Active" : "Off"
            color: notificationModule.dndEnabled ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
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
        onClicked: Notifier.dndEnabled = !Notifier.dndEnabled
      }
    }

    Rectangle {
      id: airplaneBtn
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: Theme.radiusLg
      color: root.airplaneMode
              ? (airplaneHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (airplaneHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: root.airplaneMode ? Theme.accent : Theme.cardBorder
      Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: Theme.radiusMd
          color: root.airplaneMode ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: Theme.motionBase } }

          Text {
            anchors.centerIn: parent
            text: "\uf072"
            color: root.airplaneMode ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Airplane mode"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 600 }
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: root.airplaneMode ? "Wi-Fi + Bluetooth off" : "Wireless radios on"
            color: root.airplaneMode ? Theme.fg : Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      HoverHandler { id: airplaneHover }
      MouseArea {
        id: airplaneMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleAirplaneMode()
      }
    }

    Rectangle {
      id: nightLightBtn
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: Theme.radiusLg
      color: NightLightController.enabled
              ? (nightLightHover.hovered ? Qt.lighter(Theme.accentSoft, 1.15) : Theme.accentSoft)
              : (nightLightHover.hovered ? Theme.chipBgHover : Theme.cardBg)
      border.width: 1
      border.color: NightLightController.enabled ? Theme.accent : Theme.cardBorder
      Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: Theme.radiusMd
          color: NightLightController.enabled ? Theme.accent : Theme.chipBg
          Behavior on color { ColorAnimation { duration: Theme.motionBase } }

          Text {
            anchors.centerIn: parent
            text: NightLightController.enabled ? "\uf186" : "\uf185"
            color: NightLightController.enabled ? Theme.bg : Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "Night light"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 600 }
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            text: !NightLightController.enabled ? "Disabled"
                : NightLightController.active ? NightLightController.temperature + "K"
                : NightLightController.error.length > 0 ? "Unavailable" : "Starting"
            color: Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      HoverHandler { id: nightLightHover }
      MouseArea {
        id: nightLightMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: NightLightController.enabled = !NightLightController.enabled
      }
    }
  }
}
