import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root
  property var parentWindow: null
  readonly property int itemCount: SystemTray.items.values ? SystemTray.items.values.length : 0
  property string hoveredTitle: ""

  signal settingsRequested(string page)

  // Always visible: the settings gear lives in this row, and this module is only
  // instantiated inside the control center column.
  visible: true
  height: 36
  radius: Theme.radiusLg
  color: Theme.cardBg
  border.width: 1
  border.color: Theme.cardBorder
  clip: true

  Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easeOut } }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 8
    spacing: 8

    RowLayout {
      spacing: 6
      Layout.maximumWidth: 160

      Text {
        text: "󱊖"
        color: root.hoveredTitle !== "" ? Theme.accent : Theme.fg4
        font { family: Theme.nerdFontFamily; pixelSize: Theme.fontMd }
        Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      }

      Text {
        text: root.hoveredTitle !== "" ? root.hoveredTitle
            : (root.itemCount > 0 ? ("Apps (" + root.itemCount + ")") : "Apps")
        color: root.hoveredTitle !== "" ? Theme.fg : Theme.fg4
        font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: root.hoveredTitle !== "" ? 600 : 500 }
        elide: Text.ElideRight
        Layout.fillWidth: true
        Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      }
    }

    Item { Layout.fillWidth: true }

    RowLayout {
      spacing: 4

      Repeater {
        model: SystemTray.items

        delegate: Rectangle {
          required property var modelData
          Layout.preferredWidth: 26
          Layout.preferredHeight: 26
          radius: Theme.radiusSm
          color: tileHover.containsMouse ? Theme.bg5 : "transparent"
          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          IconImage {
            id: trayIconImage
            anchors.centerIn: parent
            width: 16
            height: 16
            source: modelData.icon
            visible: status !== Image.Error
          }

          Text {
            anchors.centerIn: parent
            visible: trayIconImage.status === Image.Error || !modelData.icon
            text: "󰍜"
            color: Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
          }

          MouseArea {
            id: tileHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
              root.hoveredTitle = modelData.tooltipTitle || modelData.title || modelData.id || ""
            }
            onExited: {
              root.hoveredTitle = ""
            }

            onClicked: (mouse) => {
              if (mouse.button === Qt.LeftButton) {
                modelData.activate()
              } else if (modelData.hasMenu) {
                const pos = mapToGlobal(mouse.x, mouse.y)
                modelData.display(root.parentWindow, pos.x, pos.y)
              }
            }
          }
        }
      }
    }

    Rectangle {
      id: settingsBtn
      Layout.preferredWidth: 26
      Layout.preferredHeight: 26
      radius: Theme.radiusSm
      color: settingsHover.hovered ? Theme.chipBgHover : "transparent"
      Behavior on color { ColorAnimation { duration: Theme.motionFast } }

      Text {
        anchors.centerIn: parent
        text: "\uf013"
        color: settingsHover.hovered ? Theme.accent : Theme.fg4
        font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
      }

      HoverHandler { id: settingsHover }

      MouseArea {
        Accessible.role: Accessible.Button
        Accessible.name: "Open settings"
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.settingsRequested("main")
      }
    }
  }
}
