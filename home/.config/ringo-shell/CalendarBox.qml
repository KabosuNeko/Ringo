import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import IslandBackend

PanelWindow {
  id: calendarWindow

  readonly property real dpi: Config.dpiScale
  property real anchorY: 0
  property bool shown: false
  property var datetimeItem: null

  visible: shown && !LockController.locked
  WlrLayershell.layer: WlrLayershell.Overlay
  WlrLayershell.namespace: "ringo-popup"
  exclusionMode: ExclusionMode.Ignore

  anchors.top: true
  margins.top: anchorY

  implicitWidth: 225 * dpi
  implicitHeight: card.implicitHeight
  color: "transparent"

  Rectangle {
    id: card
    anchors.fill: parent
    implicitHeight: daysGrid.y + daysGrid.height + 12 * dpi
    color: Theme.bg
    radius: 18 * dpi

    RowLayout {
      id: calHeader
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 12 * dpi
      anchors.topMargin: 8 * dpi
      height: 25 * dpi
      Item { Layout.fillWidth: true }
      Text {
        text: datetimeItem ? (datetimeItem.monthNames[datetimeItem.viewMonth] + " " + datetimeItem.viewYear) : ""
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 11 * dpi; weight: 600 }
      }
      Item { Layout.fillWidth: true }
    }

    Grid {
      id: dayHeaders
      columns: 7
      anchors.top: calHeader.bottom
      anchors.topMargin: 6 * dpi
      anchors.horizontalCenter: parent.horizontalCenter
      columnSpacing: 4 * dpi
      Repeater {
        model: datetimeItem ? datetimeItem.dayNames : null
        Text {
          width: 25 * dpi; text: modelData; color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 8 * dpi; weight: 600 }
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    Grid {
      id: daysGrid
      columns: 7
      anchors.top: dayHeaders.bottom
      anchors.topMargin: 4 * dpi
      anchors.horizontalCenter: parent.horizontalCenter
      columnSpacing: 4 * dpi; rowSpacing: 2 * dpi
      Repeater {
        model: datetimeItem ? datetimeItem.firstDayOfMonth(datetimeItem.viewYear, datetimeItem.viewMonth) : 0
        Item { width: 26 * dpi; height: 22 * dpi }
      }
      Repeater {
        model: datetimeItem ? datetimeItem.daysInMonth(datetimeItem.viewYear, datetimeItem.viewMonth) : 0
        delegate: Rectangle {
          width: 26 * dpi; height: 22 * dpi; radius: 6 * dpi
          property bool isToday: {
            var today = new Date()
            return datetimeItem
              && index + 1 === today.getDate()
              && datetimeItem.viewMonth === today.getMonth()
              && datetimeItem.viewYear === today.getFullYear()
          }
          color: isToday ? Theme.accent : "transparent"
          Text {
            anchors.centerIn: parent
            text: index + 1
            color: isToday ? Theme.bg : Theme.fg
            font { family: Theme.fontFamily; pixelSize: 9 * dpi; weight: isToday ? 700 : 400 }
          }
        }
      }
    }
  }
}
