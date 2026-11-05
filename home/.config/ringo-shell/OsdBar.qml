import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string iconColor: ""
    property bool active: false
    property string icon: ""
    property real percent: 0 // 0.0 - 1.0
    property string valueText: "" // e.g. "muted" or "72%" or "charging"
    property color fg: Theme.fg
    property color mutedFg: fg
    property bool muted: false
    property int spacing: 10

    property int barWidth: 110
    property real barHeight: 8
    property int barRadius: 4

    anchors.centerIn: parent
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

    RowLayout {
        anchors.centerIn: parent
        spacing: root.spacing

        Text {
            id: valIcon
            text: root.icon
            color: root.iconColor !== "" ? root.iconColor : root.fg
            font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
            opacity: 1.0
        }

        Rectangle {
            Layout.preferredWidth: root.barWidth; Layout.preferredHeight: root.barHeight
            radius: root.barRadius
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder
            visible: root.barWidth > 0

            Rectangle {
                width: parent.width * root.percent
                height: parent.height
                radius: root.barRadius
                color: Theme.accent
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.motionFast
                        easing.type: Theme.easeOut
                    }
                }
            }
        }

        Text {
          id: valText
          text: root.valueText
          color: root.muted ? root.mutedFg : root.fg
          font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 600 }
          opacity: 1.0
      }
    }
}
