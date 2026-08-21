import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  spacing: 4 * Config.paddingScale

  property var parentWindow: null

  Repeater {
    model: SystemTray.items

    delegate: Item {
      required property var modelData
      width: 12 * Config.pillScale
      height: 12 * Config.pillScale

      IconImage {
        anchors.fill: parent
        source: modelData.icon
        sourceSize: Qt.size(24, 24)
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            modelData.activate()
          } else if (modelData.hasMenu) {
            const pos = root.mapToGlobal(mouse.x, mouse.y)
            modelData.display(root.parentWindow, pos.x, pos.y)
          }
        }
      }
    }
  }
}
