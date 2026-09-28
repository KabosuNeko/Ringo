import QtQuick
import QtQuick.Layouts

Rectangle {
  id: strip

  property bool shown: false
  property var items: []
  property int selectedIndex: 0
  signal closeRequested

  anchors.fill: parent
  color: Theme.bgD1
  radius: 22
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
        radius: 12
        color: (strip.selectedIndex === index || itemHover.containsMouse) ? Theme.bg5 : Theme.bg2
        border.width: strip.selectedIndex === index ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Text {
            text: modelData.icon
            font.family: Theme.nerdFontFamily
            font.pixelSize: 18
            color: (strip.selectedIndex === index || itemHover.containsMouse) ? Theme.fgL : Theme.fg
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: modelData.label
            font.pixelSize: 9
            color: Theme.fg3
            Layout.alignment: Qt.AlignHCenter
          }
        }

        MouseArea {
          id: itemHover
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
