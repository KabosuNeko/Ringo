import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

Rectangle {
  id: wallpaperPopup
  property bool shown: false
  property string selectedWallpaper: ""
  property int focusIndex: 0
  property real pos: 0
  readonly property real s: Config.pillScale

  // Ricelin-style slots: coverflow widths/heights, x offsets, brightness/saturation
  readonly property var slotW: [196, 126, 104, 88, 74]
  readonly property var slotH: [110, 71, 59, 50, 42]
  readonly property var slotCX: [0, 143, 244, 326, 393]
  readonly property var slotBright: [1, 0.56, 0.42, 0.30, 0.22]
  readonly property var slotSat: [1, 0.65, 0.55, 0.45, 0.40]

  anchors.fill: parent
  color: Theme.bgD1
  radius: 18
  clip: true
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
  signal closeRequested()
  focus: shown

  onShownChanged: {
    if (shown) {
      wallpaperModel.status === FolderListModel.Ready ? centerOnCurrent() : focusIndex = 0
      pos = focusIndex
      Qt.callLater(function(){ wallpaperPopup.forceActiveFocus() })
      hintShown = false
      hintDwell.restart()
    }
  }

  function slotLerp(arr, ao) {
    if (ao >= 4) return arr[4]
    var i = Math.floor(ao)
    var f = ao - i
    return arr[i] + (arr[i+1] - arr[i]) * f
  }
  function offsetX(off) {
    var ao = Math.abs(off)
    var cx = ao <= 4 ? slotLerp(slotCX, ao) : slotCX[4] + (ao - 4) * 60
    return (off < 0 ? -cx : cx) * s
  }
  function move(delta) {
    var cnt = wallpaperModel.count
    if (cnt === 0) return
    focusIndex = Math.max(0, Math.min(cnt - 1, focusIndex + delta))
  }
  function centerOnCurrent() {
    // if no current tracking, just keep 0
    focusIndex = 0
    pos = 0
  }
  function applyWallpaper(path) {
    wallpaperPopup.selectedWallpaper = "file://" + path
    Quickshell.execDetached(["sh", "-c", "pkill swaybg 2>/dev/null; swaybg -i '" + path + "' -m fill &"])
    Quickshell.execDetached(["wal", "-i", path, "-q", "-n", "-e"])
    Quickshell.execDetached(["sh", "-c", "sleep 0.5 && pkill -USR1 foot 2>/dev/null || true"])
  }
  function activate() {
    var path = wallpaperModel.get(focusIndex, "filePath")
    if (path) applyWallpaper(path)
    if (Config.wsCloseOnWallpaperSet) closeRequested()
  }

  property bool hintShown: false
  Timer { id: hintDwell; interval: 600; onTriggered: wallpaperPopup.hintShown = true }
  onFocusIndexChanged: { hintShown = false; hintDwell.restart(); previewArmed = false; previewArm.restart() }

  property bool previewArmed: true
  Timer { id: previewArm; interval: 300; onTriggered: wallpaperPopup.previewArmed = true }

  Keys.onLeftPressed: move(-1)
  Keys.onRightPressed: move(1)
  Keys.onUpPressed: move(-1)
  Keys.onDownPressed: move(1)
  Keys.onEscapePressed: closeRequested()
  Keys.onReturnPressed: activate()
  Keys.onEnterPressed: activate()

  FolderListModel {
    id: wallpaperModel
    folder: "file://" + Config.wallpapersDir.replace("~", Quickshell.env("HOME")) + "/"
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.webm"]
    showDirs: false
    caseSensitive: false
    sortField: FolderListModel.Name
    onStatusChanged: if (status === FolderListModel.Ready && wallpaperPopup.shown) { centerOnCurrent(); wallpaperPopup.forceActiveFocus() }
  }

  // smooth chase of pos -> focusIndex (Ricelin FrameAnimation exponential)
  FrameAnimation {
    running: wallpaperPopup.shown && wallpaperPopup.pos !== wallpaperPopup.focusIndex
    onTriggered: {
      var k = 1 - Math.exp(-frameTime / 0.07)
      var next = wallpaperPopup.pos + (wallpaperPopup.focusIndex - wallpaperPopup.pos) * k
      wallpaperPopup.pos = Math.abs(next - wallpaperPopup.focusIndex) < 0.001 ? wallpaperPopup.focusIndex : next
    }
  }

  // header: folder path + count
  Item {
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 14 * wallpaperPopup.s
    height: 18 * wallpaperPopup.s
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Config.wallpapersDir
      elide: Text.ElideMiddle
      width: parent.width - countText.width - 12*wallpaperPopup.s
      color: Theme.fg3
      font.family: Theme.fontFamily
      font.pixelSize: 9 * wallpaperPopup.s
    }
    Text {
      id: countText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: wallpaperModel.count > 0 ? (wallpaperPopup.focusIndex+1) + " / " + wallpaperModel.count : ""
      color: Theme.fg5
      font.family: Theme.fontFamily
      font.pixelSize: 9 * wallpaperPopup.s
    }
  }

  // empty state
  Text {
    anchors.centerIn: parent
    visible: wallpaperModel.status === FolderListModel.Ready && wallpaperModel.count === 0
    text: "No wallpapers in\n" + Config.wallpapersDir
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Theme.warning
    font.family: Theme.fontFamily
    font.pixelSize: 11 * wallpaperPopup.s
  }

  // coverflow strip
  Item {
    id: strip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 8 * wallpaperPopup.s
    anchors.bottom: hint.top
    anchors.bottomMargin: 8 * wallpaperPopup.s
    clip: true

    Repeater {
      model: wallpaperModel
      delegate: Item {
        id: tile
        required property int index
        readonly property string filePath: wallpaperModel.get(index, "filePath") !== undefined ? wallpaperModel.get(index, "filePath") : ""
        readonly property string fileName: wallpaperModel.get(index, "fileName") !== undefined ? wallpaperModel.get(index, "fileName") : ""
        readonly property string wallUrl: "file://" + filePath
        readonly property real off: index - wallpaperPopup.pos
        readonly property real ao: Math.abs(off)
        readonly property bool focused: index === wallpaperPopup.focusIndex
        readonly property real bright: wallpaperPopup.slotLerp(wallpaperPopup.slotBright, ao)
        readonly property real sat: wallpaperPopup.slotLerp(wallpaperPopup.slotSat, ao)
        readonly property real corner: (8 + 2 * Math.max(0, 1 - ao)) * wallpaperPopup.s
        readonly property real edgeFade: {
          var soft = 70 * wallpaperPopup.s
          var gap = Math.min(x, strip.width - (x + width))
          return Math.max(0, Math.min(1, gap / soft))
        }

        width: wallpaperPopup.slotLerp(wallpaperPopup.slotW, ao) * wallpaperPopup.s
        height: wallpaperPopup.slotLerp(wallpaperPopup.slotH, ao) * wallpaperPopup.s
        x: strip.width/2 + wallpaperPopup.offsetX(off) - width/2
        y: (strip.height - height)/2
        z: 10 - ao
        visible: ao <= 5
        opacity: edgeFade * (ao <= 4 ? 1 : Math.max(0, 5 - ao))

        ClippingRectangle {
          id: card
          anchors.fill: parent
          radius: tile.corner
          color: Theme.bg4
          // simple saturation/brightness via overlay instead of MultiEffect
          Image {
            id: thumb
            anchors.fill: parent
            source: tile.ao <= 6 ? tile.wallUrl : ""
            sourceSize.width: 512
            sourceSize.height: 300
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
          }
          Rectangle {
            anchors.fill: parent
            color: Theme.bg4
            visible: thumb.status === Image.Error
          }
          // brightness dim for non-focused
          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0,0,0,1)
            opacity: 1 - tile.bright
          }
          // hover brighten
          Rectangle {
            anchors.fill: parent
            color: "white"
            opacity: hoverHandler.hovered ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: 115 } }
          }
          // filename bar on focused/hover
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 22 * wallpaperPopup.s
            visible: tile.focused || hoverHandler.hovered
            gradient: Gradient {
              GradientStop { position: 0.0; color: "#00000000" }
              GradientStop { position: 1.0; color: "#cc000000" }
            }
            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: 6 * wallpaperPopup.s
              text: tile.fileName
              color: "white"
              elide: Text.ElideMiddle
              font.family: Theme.fontFamily
              font.pixelSize: 8 * wallpaperPopup.s
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: tile.corner
          color: "transparent"
          border.width: tile.focused ? 2 : 1
          border.color: tile.focused ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
          Behavior on border.color { ColorAnimation { duration: Motion.fast } }
          Behavior on border.width { NumberAnimation { duration: Motion.fast } }
        }

        HoverHandler { id: hoverHandler }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!tile.focused) wallpaperPopup.focusIndex = tile.index
            else wallpaperPopup.activate()
          }
        }
      }
    }

    // wheel to navigate
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      z: 20
      property real acc: 0
      onWheel: (event) => {
        acc += event.angleDelta.y / 120
        var notches = Math.trunc(acc)
        if (notches !== 0) { wallpaperPopup.move(-notches); acc -= notches }
        event.accepted = true
      }
    }
  }

  // hint legend (Ricelin-style)
  Item {
    id: hint
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 10 * wallpaperPopup.s
    width: hintRow.width
    height: hintRow.height
    opacity: (wallpaperPopup.hintShown && wallpaperModel.count > 0) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.standard } }
    Row {
      id: hintRow
      spacing: 12 * wallpaperPopup.s
      Row {
        spacing: 5 * wallpaperPopup.s
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: keyTap.implicitWidth + 10 * wallpaperPopup.s
          height: keyTap.implicitHeight + 5 * wallpaperPopup.s
          radius: 5 * wallpaperPopup.s
          color: Theme.bg3
          border.width: 1; border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
          Text { id: keyTap; anchors.centerIn: parent; text: "← →"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 8 * wallpaperPopup.s; font.weight: Font.DemiBold }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "chọn"; color: Theme.fg3; font.family: Theme.fontFamily; font.pixelSize: 9 * wallpaperPopup.s }
      }
      Row {
        spacing: 5 * wallpaperPopup.s
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: keyEnter.implicitWidth + 10 * wallpaperPopup.s
          height: keyEnter.implicitHeight + 5 * wallpaperPopup.s
          radius: 5 * wallpaperPopup.s
          color: Theme.bg3
          border.width: 1; border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
          Text { id: keyEnter; anchors.centerIn: parent; text: "↵"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 8 * wallpaperPopup.s; font.weight: Font.DemiBold }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "đặt"; color: Theme.fg3; font.family: Theme.fontFamily; font.pixelSize: 9 * wallpaperPopup.s }
      }
      Row {
        spacing: 5 * wallpaperPopup.s
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: keyEsc.implicitWidth + 10 * wallpaperPopup.s
          height: keyEsc.implicitHeight + 5 * wallpaperPopup.s
          radius: 5 * wallpaperPopup.s
          color: Theme.bg3
          border.width: 1; border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
          Text { id: keyEsc; anchors.centerIn: parent; text: "esc"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 8 * wallpaperPopup.s; font.weight: Font.DemiBold }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "đóng"; color: Theme.fg3; font.family: Theme.fontFamily; font.pixelSize: 9 * wallpaperPopup.s }
      }
    }
  }
}
