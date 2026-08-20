import Quickshell
import Quickshell.Wayland
import IslandBackend
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets

// Fullscreen lock screen. Shown when LockController.locked becomes true.
// Covers the whole output on the overlay layer, grabs exclusive keyboard
// focus and authenticates the password against PAM via the backend.
PanelWindow {
  id: lockScreen
  visible: LockController.locked
  WlrLayershell.layer: WlrLayershell.Overlay
  WlrLayershell.namespace: "ringo-lock"
  anchors { top: true; left: true; right: true; bottom: true }
  implicitWidth: Screen.width
  implicitHeight: Screen.height
  WlrLayershell.keyboardFocus: LockController.locked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  color: "transparent"

  // Backdrop: niri applies the ringo-lock layer-rule background-effect
  // (xray + blur) on this surface; we darken it further on top.
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0.08, 0.08, 0.10, 0.6)

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 6

      // Big clock
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDateTime(clock.date, "hh:mm")
        color: Theme.fgL
        font.family: Theme.fontFamily
        font.pixelSize: 72
        font.weight: Font.Light
        style: Text.Sunken
      }

      // Date
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: 16
      }

      // Password field
      TextField {
        id: passField
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 24
        implicitWidth: 260
        implicitHeight: 44
        placeholderText: "Password"
        echoMode: TextInput.Password
        color: Theme.fg
        placeholderTextColor: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: 16
        horizontalAlignment: TextInput.AlignHCenter
        background: Rectangle {
          radius: 12
          color: Theme.bg2
          border.width: passField.activeFocus ? 1 : 0
          border.color: Theme.accent
        }

        onAccepted: {
          if (passField.text.length === 0) return
          if (LockController.tryUnlock(passField.text)) {
            // success: LockController flips locked=false, panel hides itself
          } else {
            errorText.visible = true
            shakeAnim.restart()
            passField.clear()
          }
        }
      }

      // Error / hint
      Text {
        id: errorText
        Layout.alignment: Qt.AlignHCenter
        visible: false
        text: "Incorrect password"
        color: Theme.deleting
        font.family: Theme.fontFamily
        font.pixelSize: 13
      }

      // Unlock button (mouse users)
      Button {
        id: unlockBtn
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        visible: false // keyboard Enter is primary; keep UI minimal
        text: "Unlock"
        onClicked: passField.accepted()
      }
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // Shake the password field on failure
  SequentialAnimation {
    id: shakeAnim
    property real startX: passField.x
    NumberAnimation { target: passField; property: "x"; to: passField.x + 8; duration: 40 }
    NumberAnimation { target: passField; property: "x"; to: passField.x - 8; duration: 40 }
    NumberAnimation { target: passField; property: "x"; to: passField.x + 8; duration: 40 }
    NumberAnimation { target: passField; property: "x"; to: passField.x; duration: 40 }
  }

  // Focus the field as soon as the lock screen appears
  onVisibleChanged: {
    if (visible) {
      errorText.visible = false
      passField.clear()
      passField.forceActiveFocus()
    }
  }
}