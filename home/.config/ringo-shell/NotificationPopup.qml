import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root
  property bool active: false
  property var notif: null

  anchors.centerIn: parent
  opacity: active ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: 150 } }

  RowLayout {
    anchors.centerIn: parent
    spacing: 10

    Text {
      text: String.fromCodePoint(0xf0f3)
      color: Theme.fg
      font { family: Theme.nerdFontFamily; pixelSize: 15 }
      visible: notifIcon.status !== Image.Ready
    }

    Image {
      id: notifIcon
      width: 23 * box.dpi
      height: 23 * box.dpi
      fillMode: Image.PreserveAspectCrop
      source: {
        // Only show the app icon. Attached images (e.g. screenshots) are
        // hidden: a dark 16:9 image cropped to a tiny square renders as a
        // broken-looking black box instead of a useful preview.
        if (root.notif && root.notif.appIcon) {
          if (root.notif.appIcon.startsWith("/")) return "file://" + root.notif.appIcon
          // iconPath(icon, true) returns "" if the icon is missing from the
          // theme, so we never see the black/purple "missing texture" block.
          return Quickshell.iconPath(root.notif.appIcon, true)
        }
        return ""
      }
      // cap decode size so big icons don't burn VRAM at thumbnail size
      sourceSize: Qt.size(64, 64)
      visible: status === Image.Ready
      onStatusChanged: if (status === Image.Error) visible = false
    }

    ColumnLayout {
      spacing: 3
      Text {
        text: root.notif ? root.notif.summary : ""
        textFormat: Text.PlainText
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10; weight: 700 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
      }

      Text {
        text: root.notif ? root.notif.body.replace(
          /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
          '<a href="$2">$1</a>'
        ) : ""
        textFormat: Text.StyledText
        linkColor: Theme.accent
        color: "#9b9b9b"
        font { family: Theme.fontFamily; pixelSize: 9 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        visible: text !== ""
      }
    }
  }
}
