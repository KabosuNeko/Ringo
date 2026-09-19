import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import IslandBackend

PanelWindow {
  id: wifiListWindow

  readonly property real dpi: Config.dpiScale

  property real anchorX: 0
  property real anchorY: 0

  anchors.top: true
  anchors.left: true
  margins.top: anchorY
  margins.left: anchorX

  WlrLayershell.layer: WlrLayershell.Overlay
  WlrLayershell.namespace: "ringo-popup"

  property string passwordPromptSsid: ""
  property bool passwordPromptVisible: false
  property string passwordValue: ""

  function submitPassword() {
    if (passwordPromptSsid.length === 0) return
    WifiController.connectToNetwork(passwordPromptSsid, passwordValue)
    passwordPromptVisible = false
    passwordValue = ""
  }

  function cancelPassword() {
    passwordPromptVisible = false
    passwordValue = ""
  }

  // keyboard focus for password prompt
  WlrLayershell.keyboardFocus: passwordPromptVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

  exclusionMode: ExclusionMode.Ignore
  implicitWidth: 245 * dpi
  implicitHeight: 308 * dpi
  color: "transparent"

  onVisibleChanged: {
    if (!visible) {
      passwordPromptVisible = false
      passwordValue = ""
    } else if (WifiController.enabled) {
      WifiController.refreshNetworks(true)
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.bg
    radius: 26 * dpi

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16 * dpi
      spacing: 13 * dpi

      Text {
        text: "Wi-Fi"
        color: Theme.fg2
        font { family: Theme.fontFamily; pixelSize: 14 * dpi; bold: true }
        Layout.leftMargin: 5 * dpi
      }

      Text {
        visible: WifiController.scanning
        text: "Scanning..."
        color: Theme.fg4
        font { family: Theme.fontFamily; pixelSize: 11 * dpi }
      }

      Text {
        visible: !WifiController.enabled
        text: "Turn on the Wi-Fi to see networks."
        color: Theme.fg4
        font { family: Theme.fontFamily; pixelSize: 11 * dpi }
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: 5 * dpi
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: networkColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: networkColumn
          width: parent.width
          spacing: 4 * dpi

          Repeater {
            model: WifiController.enabled ? WifiController.networks : null

            delegate: Rectangle {
              width: networkColumn.width
              height: 45 * dpi
              radius: 16 * dpi
              color: connected ? Theme.accent : (networkMouse.containsMouse ? Theme.focusBgL : Theme.bg2)
              border.color: connected ? "" : Theme.borderBg2
              border.width: connected ? 0 : 1

              MouseArea {
                id: networkMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !WifiController.busy && WifiController.enabled
                onClicked: {
                  if (connected) {
                    WifiController.disconnectCurrent()
                    return
                  }
                  if (savedConnection || !secure) {
                    WifiController.connectToNetwork(ssid)
                    return
                  }
                  wifiListWindow.passwordPromptSsid = ssid
                  wifiListWindow.passwordPromptVisible = true
                }
              }

              Row {
                anchors.fill: parent
                anchors.margins: 10 * dpi
                anchors.leftMargin: 17 * dpi
                spacing: 20 * dpi

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: secure ? "\uf023" : "\uf09c"
                  font { family: Theme.nerdFontFamily; pixelSize: 12 * dpi }
                  color: connected ? Theme.fgL : Theme.fg4
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 2 * dpi
                  Text {
                    text: displayName || ssid
                    color: connected ? Theme.fgL : Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 11 * dpi; weight: connected ? 500 : 300 }
                  }
                  Text {
                    text: connected ? "Connected" : (signal >= 0 ? signal + "%" : "")
                    color: connected ? Theme.fg2 : Theme.fg4
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: 9 * dpi }
                  }
                }
              }
            }
          }
        }
      }

      Text {
        visible: WifiController.errorMessage.length > 0
        text: WifiController.errorMessage
        color: Theme.deleting
        font { family: Theme.fontFamily; pixelSize: 11 * dpi }
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    Rectangle {
      id: passwordPromptRect
      visible: wifiListWindow.passwordPromptVisible
      anchors.fill: parent
      color: Theme.bg1
      radius: 28 * dpi
      z: 10

      onVisibleChanged: {
        if (visible) {
          passwordField.text = ""
          wifiListWindow.requestActivate()
          focusTimer.restart()
        }
      }

      Timer {
        id: focusTimer
        interval: 100
        onTriggered: {
          wifiListWindow.requestActivate()
          passwordField.forceActiveFocus()
        }
      }

      MouseArea {
        anchors.fill: parent
        // Eat clicks outside to prevent dismissing the list behind
      }

      Column {
        anchors.centerIn: parent
        width: parent.width - 32 * dpi
        spacing: 12 * dpi

        Text {
          width: parent.width
          text: "Password for " + wifiListWindow.passwordPromptSsid
          color: Theme.fg2
          font { family: Theme.fontFamily; pixelSize: 13 * dpi; weight: 600 }
          wrapMode: Text.Wrap
        }

        Rectangle {
          width: parent.width
          height: 38 * dpi
          radius: 8 * dpi
          color: Theme.bg4
          border.color: passwordField.activeFocus ? Theme.accent : Theme.borderBg1
          border.width: passwordField.activeFocus ? 2 : 1
          Behavior on border.color { ColorAnimation { duration: 100 } }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
              wifiListWindow.requestActivate()
              passwordField.forceActiveFocus()
              mouse.accepted = false
            }
          }

          TextInput {
            id: passwordField
            focus: true
            anchors.fill: parent
            leftPadding: 12 * dpi
            rightPadding: 36 * dpi
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 12 * dpi }
            echoMode: eyeBtn.showPassword ? TextInput.Normal : TextInput.Password
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.bg
            clip: true
            onTextChanged: wifiListWindow.passwordValue = text
            Keys.onReturnPressed: wifiListWindow.submitPassword()
            Keys.onEscapePressed: wifiListWindow.cancelPassword()

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12 * dpi
              anchors.verticalCenter: parent.verticalCenter
              text: "Enter password..."
              color: Theme.fg4
              font: passwordField.font
              visible: passwordField.text.length === 0
            }
          }

          Rectangle {
            id: eyeBtn
            property bool showPassword: false
            anchors.right: parent.right
            anchors.rightMargin: 6 * dpi
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * dpi
            height: 26 * dpi
            radius: 6 * dpi
            color: eyeMA.containsMouse ? Theme.bg5 : "transparent"

            Text {
              anchors.centerIn: parent
              text: eyeBtn.showPassword ? "󰈈" : "󰈉"
              color: eyeBtn.showPassword ? Theme.accent : Theme.fg3
              font { family: Theme.nerdFontFamily; pixelSize: 13 * dpi }
            }

            MouseArea {
              id: eyeMA
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: eyeBtn.showPassword = !eyeBtn.showPassword
            }
          }
        }

        Row {
          spacing: 8 * dpi
          Rectangle {
            id: submitBtn
            width: 80 * dpi; height: 32 * dpi; radius: 9 * dpi
            color: submitBtnMA.containsMouse ? Qt.darker(Theme.accent, 1.15) : Theme.accent
            Text { anchors.centerIn: parent; text: "Join"; color: Theme.fgL; font { family: Theme.fontFamily; pixelSize: 12 * dpi } }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: submitBtnMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: wifiListWindow.submitPassword()
            }
          }

          Rectangle {
            width: 80 * dpi; height: 32 * dpi; radius: 9 * dpi
            color: cancelBtnMA.containsMouse ? Theme.focusBg1 : Theme.bg5
            Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg1; font { family: Theme.fontFamily; pixelSize: 12 * dpi } }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: cancelBtnMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: wifiListWindow.cancelPassword()
            }
          }
        }
      }
    }
  }
}
