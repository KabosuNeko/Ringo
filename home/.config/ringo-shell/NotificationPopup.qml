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
      Layout.preferredWidth: 23 * Config.dpiScale
      Layout.preferredHeight: 23 * Config.dpiScale
      fillMode: Image.PreserveAspectCrop
      source: {
        // only the app icon: a 16:9 attachment cropped to a tiny square renders as a black box
        if (root.notif && root.notif.appIcon) {
          if (root.notif.appIcon.startsWith("/")) return "file://" + root.notif.appIcon
          // iconPath(icon, true) returns "" when the icon is missing from the theme
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
