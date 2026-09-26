import QtQuick

// Shared skeleton for the bar's centred overlay slots.
//
// Every overlay (cliphist, wallpaper switcher, power menu, record menu, app
// launcher) used to repeat the same six lines: centre in the bar, inset width,
// collapse the height to 0 while closed, fade with the chained occlusion
// guard, hide at opacity 0 and share one 120 ms OutCubic fade. Only the
// payload, the inset and the open height ever differed, so they live here.
//
// `box` is the bar's inner item; this component is only instantiated from
// shell.qml, so it resolves through the same context chain Battery.qml uses.
Item {
  id: slot

  // Whether this overlay wants to be on screen.
  property bool open: false
  // Set when a higher priority surface (osd, toast, control center, another
  // overlay that wins the slot) is showing and must take precedence.
  property bool blocked: false
  // Height while open; the slot collapses to 0 while closed.
  property real openHeight: 0
  // Horizontal inset from the bar's content width.
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
