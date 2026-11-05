import Quickshell
import Quickshell.Widgets
import IslandBackend
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

  color: Theme.bg
  radius: Theme.radiusXl
  visible: opacity > 0
  opacity: shown ? 1 : 0
  signal closeRequested()

  function fileUrl(path: string): string {
    // a local path is not a URL: '#'/'?' would parse as fragment/query and the file never opens;
    // Qt.resolvedUrl() does not encode, so encode each segment
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  function applyWallpaper(path) {
    wallpaperPopup.selectedWallpaper = fileUrl(path)
    // palette, blurred niri-overview backdrop and the wallpaper process are backend-owned
    WallpaperController.apply(path)
  }

  function activateCurrent() {
    var path = wallpaperModel.get(wallGrid.currentIndex, "filePath")
    if (path) applyWallpaper(path)
    if (Config.wsCloseOnWallpaperSet) closeRequested()
  }

  FolderListModel {
    id: wallpaperModel
    folder: fileUrl(Config.wallpapersDir.replace("~", Quickshell.env("HOME"))) + "/"
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

    Text {
      visible: wallpaperModel.status === FolderListModel.Ready
                && wallpaperModel.count === 0
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.warning
      text: "No wallpapers found in\n" + Config.wallpapersDir
      font { family: Theme.fontFamily; pixelSize: Theme.fontMd }
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
        property string wallUrl: wallpaperPopup.fileUrl(filePath)
        property bool isCurrent: GridView.isCurrentItem
        property bool isSelected: wallpaperPopup.selectedWallpaper === wallUrl

        Component.onCompleted: {
          if (Config.wsAnimation) {
            entryAnim.start()
          }
        }
        opacity: 1

        NumberAnimation {
          id: entryAnim
          target: cell
          property: "opacity"
          from: 0
          to: 1
          duration: Theme.motionFast
          easing.type: Theme.easeOut
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 5
          radius: Theme.radiusLg
          color: Theme.bg4
          border.width: cell.isCurrent ? 1 : 0
          border.color: Theme.borderBg

          ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Theme.radiusMd
            color: "transparent"

            Image {
              id: preview
              anchors.fill: parent
              source: wallUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              // thumbnails need not stay decoded while the switcher is closed
              cache: false
              sourceSize.width: 200
              sourceSize.height: 150
            }

            // the only place an undecodable wallpaper is reported
            Text {
              anchors.centerIn: parent
              visible: preview.status === Image.Error
              text: "\uf071  Unreadable"
              color: Theme.warning
              font { family: Theme.fontFamily; pixelSize: Theme.fontXs }
            }

            Rectangle {
              anchors.fill: parent
              color: mouseArea.containsMouse ? "white" : "transparent"
              opacity: mouseArea.containsMouse ? 0.06 : 0
              Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 32
              opacity: (mouseArea.containsMouse || cell.isCurrent) ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: Theme.motionSlow } }
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
                font { family: Theme.fontFamily; pixelSize: Theme.fontXs }
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
