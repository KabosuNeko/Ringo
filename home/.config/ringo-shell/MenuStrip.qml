import QtQuick
import QtQuick.Layouts

Rectangle {
  id: strip

  property bool shown: false
  property var items: []
  property int selectedIndex: 0
  signal closeRequested

  anchors.fill: parent
  color: Theme.bg
  radius: Theme.radiusPanel
  visible: opacity > 0
  opacity: shown ? 1 : 0

  function activate(index: int): void {
    if (index >= 0 && index < items.length) {
      items[index].action()
    }
    strip.closeRequested()
  }

  focus: true
  Keys.onLeftPressed: strip.selectedIndex = (strip.selectedIndex + items.length - 1) % items.length
  Keys.onRightPressed: strip.selectedIndex = (strip.selectedIndex + 1) % items.length
  Keys.onReturnPressed: strip.activate(strip.selectedIndex)
  Keys.onEnterPressed: strip.activate(strip.selectedIndex)
  Keys.onSpacePressed: strip.activate(strip.selectedIndex)
  Keys.onEscapePressed: strip.closeRequested()

  RowLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    Repeater {
      model: strip.items

      delegate: Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.radiusLg
        color: (strip.selectedIndex === index || itemHover.containsMouse) ? Theme.bg5 : Theme.bg2
        border.width: strip.selectedIndex === index ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.motionBase } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Text {
            text: modelData.icon
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.fontXxl
            color: (strip.selectedIndex === index || itemHover.containsMouse) ? Theme.fg : Theme.fg
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: modelData.label
            font.pixelSize: Theme.fontXs
            color: Theme.fg3
            Layout.alignment: Qt.AlignHCenter
          }
        }

        MouseArea {
          id: itemHover
          Accessible.role: Accessible.Button
          Accessible.name: modelData.label
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: strip.selectedIndex = index
          onClicked: strip.activate(index)
        }
      }
    }
  }
}
