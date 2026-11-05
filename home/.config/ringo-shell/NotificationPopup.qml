import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root
  property bool active: false
  property var notif: null

  readonly property var actions: {
    if (!notif || !notif.actions) return []
    return notif.actions.filter(a => a && a.text && a.text.length > 0)
  }

  // the host owns the queue, so the popup only asks for the dismissal
  signal dismissRequested()

  anchors.centerIn: parent
  opacity: active ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

  RowLayout {
    anchors.centerIn: parent
    spacing: 10

    Text {
      text: String.fromCodePoint(0xf0f3)
      color: Theme.fg
      font { family: Theme.nerdFontFamily; pixelSize: Theme.fontXl }
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
        font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 700 }
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
        color: Theme.fg4
        font { family: Theme.fontFamily; pixelSize: Theme.fontXs }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        visible: text !== ""
        onLinkActivated: (link) => {
          Qt.openUrlExternally(link)
          root.dismissRequested()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 4
        visible: root.actions.length > 0

        Repeater {
          model: root.actions

          Rectangle {
            implicitHeight: 20
            implicitWidth: actionText.implicitWidth + 12
            radius: Theme.radiusSm
            color: actionHover.containsMouse ? Theme.chipBgHover : Theme.chipBg
            border.width: 1
            border.color: Theme.chipBorder

            Text {
              id: actionText
              anchors.centerIn: parent
              text: modelData.text
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 600 }
            }

            MouseArea {
              id: actionHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                modelData.invoke()
                root.dismissRequested()
              }
            }
          }
        }
      }
    }

    Rectangle {
      Layout.preferredWidth: 22
      Layout.preferredHeight: 22
      Layout.alignment: Qt.AlignVCenter
      radius: height / 2
      color: toastHover.containsMouse ? Theme.focusBgL : "transparent"
      Behavior on color { ColorAnimation { duration: Theme.motionFast } }

      Text {
        // nf-fa-times (U+F00D), needs the nerd font family to render
        text: "\uf00d"
        color: toastHover.containsMouse ? Theme.focusFg1 : Theme.fg5
        anchors.centerIn: parent
        font { family: Theme.nerdFontFamily; pixelSize: Theme.fontSm }
        Behavior on color { ColorAnimation { duration: Theme.motionBase } }
      }

      MouseArea {
        id: toastHover
        Accessible.role: Accessible.Button
        Accessible.name: "Dismiss notification"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dismissRequested()
      }
    }
  }
}
