import QtQuick

// box is shell.qml's inner bar item, resolved through the context chain
Item {
  id: slot

  property bool open: false
  // a higher-priority surface (osd, toast, control center) claimed the slot
  property bool blocked: false
  property real openHeight: 0
  property real widthInset: 28

  default property alias payload: slot.data

  anchors.centerIn: parent
  width: box.implicitWidth - widthInset
  height: open ? openHeight : 0
  opacity: open && !blocked ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
  }
}
