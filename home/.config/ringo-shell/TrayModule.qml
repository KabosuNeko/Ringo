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

  visible: itemCount > 0
  height: itemCount > 0 ? 38 : 0
  radius: 12
  color: Theme.bgD
  border.width: 1
  border.color: Theme.borderBg3
  clip: true

  Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 8
    spacing: 8

    // Header badge with dynamic app tooltip
    RowLayout {
      spacing: 6
      Layout.maximumWidth: 160

      Text {
        text: "󱊖"
        color: root.hoveredTitle !== "" ? Theme.accent : Theme.fg4
        font { family: Theme.nerdFontFamily; pixelSize: 12 }
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      Text {
        text: root.hoveredTitle !== "" ? root.hoveredTitle : ("Apps (" + root.itemCount + ")")
        color: root.hoveredTitle !== "" ? Theme.fgL : Theme.fg4
        font { family: Theme.fontFamily; pixelSize: 9; weight: root.hoveredTitle !== "" ? 600 : 500 }
        elide: Text.ElideRight
        Layout.fillWidth: true
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }

    Item { Layout.fillWidth: true }

    // Tray icons dock
    RowLayout {
      spacing: 4

      Repeater {
        model: SystemTray.items

        delegate: Rectangle {
          id: trayTile
          required property var modelData
          Layout.preferredWidth: 26
          Layout.preferredHeight: 26
          radius: 7
          color: tileHover.containsMouse ? Theme.bg5 : "transparent"
          Behavior on color { ColorAnimation { duration: 100 } }

          IconImage {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: modelData.icon
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
  }
}



