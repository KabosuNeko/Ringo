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
  anchors.fill: parent

  onShownChanged: {
    if (shown && wallpaperModel.status === FolderListModel.Ready) {
      wallGrid.currentIndex = 0
      wallGrid.forceActiveFocus()
    }
  }

  color: Theme.bgD1
  radius: 18
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
  signal closeRequested()

  function applyWallpaper(path) {
    wallpaperPopup.selectedWallpaper = "file://" + path
    // Use swaybg instead of awww (no transitions, but works)
    Quickshell.execDetached(["sh", "-c", "pkill swaybg 2>/dev/null; swaybg -i '" + path + "' -m fill &"])
    // wal regenerates ~/.cache/wal/ (colors.json, colors-foot-dark.ini, gtk-colors, ...)
    Quickshell.execDetached(["wal", "-i", path, "-q", "-n", "-e"])
    // Reload foot so it picks up the new colors-foot-dark.ini
    Quickshell.execDetached(["sh", "-c", "sleep 0.5 && pkill -USR1 foot 2>/dev/null || true"])
  }

  function activateCurrent() {
    var path = wallpaperModel.get(wallGrid.currentIndex, "filePath")
    if (path) applyWallpaper(path)
    if (Config.wsCloseOnWallpaperSet) closeRequested()
  }

  FolderListModel {
    id: wallpaperModel
    folder: "file://" + Config.wallpapersDir.replace("~", Quickshell.env("HOME")) + "/"
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    showDirs: false
    caseSensitive: false
    sortField: FolderListModel.Name

    onStatusChanged: {
      if (status === FolderListModel.Ready && wallpaperPopup.shown) {
        wallGrid.currentIndex = 0
        wallGrid.forceActiveFocus()
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 15

    // fallback: no wallpapers found
    Text {
      visible: wallpaperModel.status === FolderListModel.Ready
                && wallpaperModel.count === 0
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.warning
      text: "No wallpapers found in\n" + Config.wallpapersDir
      font { family: Theme.fontFamily; pixelSize: 12 }
    }

    GridView {
      id: wallGrid
      visible: wallpaperModel.count > 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      cellWidth: width / 3
      cellHeight: 105
      clip: true
      model: wallpaperModel
      boundsBehavior: Flickable.StopAtBounds
      focus: true
      keyNavigationEnabled: true
      keyNavigationWraps: true

      Keys.onEscapePressed: wallpaperPopup.closeRequested()
      Keys.onReturnPressed: wallpaperPopup.activateCurrent()
      Keys.onEnterPressed: wallpaperPopup.activateCurrent()

      delegate: Item {
        id: cell
        width: wallGrid.cellWidth
        height: wallGrid.cellHeight
        property string wallUrl: "file://" + filePath
        property bool isCurrent: GridView.isCurrentItem
        property bool isSelected: wallpaperPopup.selectedWallpaper === wallUrl

        Component.onCompleted: {
          if (Config.wsAnimation) {
            entryAnim.start()
          }
        }
        property int columns: 3
        property real rowIdx: Math.floor(index / columns)
        property real colIdx: index % columns
        property real totalRows: Math.ceil(wallGrid.count / columns)
        property real centerRow: (totalRows - 1) / 2
        property real centerCol: (columns - 1) / 2
        property real distFromCenter: Math.sqrt(Math.pow(rowIdx - centerRow, 2) + Math.pow(colIdx - centerCol, 2))

        opacity: 1
        scale: 1.0
        transformOrigin: Item.Center

        SequentialAnimation {
          id: entryAnim
          PauseAnimation { duration: cell.distFromCenter * 50 }
          ParallelAnimation {
            NumberAnimation { target: cell; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutExpo }
            NumberAnimation { target: cell; property: "scale"; from: 0.4; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
          }
        }

        Rectangle {
          id: thumbFrame
          anchors.fill: parent
          anchors.margins: 5
          radius: 10
          color: Theme.bg4
          scale: (mouseArea.containsMouse || cell.isCurrent) ? 1.03 : 1.0
          Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutExpo } }
          border.width: cell.isCurrent ? 1 : 0
          border.color: Theme.borderBg

          ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: "transparent"

            Image {
              anchors.fill: parent
              source: wallUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              sourceSize.width: 200
              sourceSize.height: 150
              onStatusChanged: {
                if (status === Image.Error) console.log("FAILED:", wallUrl)
              }
            }

            Rectangle {
              anchors.fill: parent
              color: mouseArea.containsMouse ? "white" : "transparent"
              opacity: mouseArea.containsMouse ? 0.06 : 0
              Behavior on opacity { NumberAnimation { duration: 115 } }
            }

            // filename shadowed bar
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 32
              opacity: (mouseArea.containsMouse || cell.isCurrent) ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 250 } }
              gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#cc000000" }
              }

              Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: fileBaseName
                color: "white"
                elide: Text.ElideMiddle
                font { family: Theme.fontFamily; pixelSize: 9 }
              }
            }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            wallGrid.currentIndex = index
            wallpaperPopup.applyWallpaper(filePath)
            if (Config.wsCloseOnWallpaperSet) closeRequested()
          }
        }
      }
    }
  }
}
