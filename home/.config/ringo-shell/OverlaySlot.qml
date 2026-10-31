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

  // true while the exit fade runs; hosts keep their Loader alive on this
  readonly property bool closing: !open && opacity > 0
  property real shownHeight: 0
  property real shownWidth: 0

  onOpenChanged: if (open) captureSize()
  onOpenHeightChanged: if (open) captureSize()

  function captureSize(): void {
    shownHeight = openHeight
    shownWidth = box.baseWidth
  }

  anchors.horizontalCenter: parent.horizontalCenter
  anchors.top: parent.top
  anchors.topMargin: 12
  width: open ? Math.max(0, box.baseWidth - widthInset)
             : (closing ? Math.max(0, shownWidth - widthInset) : 0)
  // freeze the size during the exit so anchored children do not collapse
  height: open ? openHeight : (closing ? shownHeight : 0)
  opacity: open && !blocked ? 1 : 0
  visible: opacity > 0
  enabled: open

  Behavior on opacity {
    NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
  }
}
