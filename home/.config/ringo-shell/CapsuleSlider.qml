import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property real value: 0.0 // 0.0 to 1.0
    property string valueText: ""
    property bool muted: false
    property color accentColor: Theme.accent

    signal sliderMoved(real newValue)

    implicitHeight: 32
    radius: 10
    color: Theme.cardBg
    border.width: 1
    border.color: sliderMouse.containsMouse ? Theme.chipBorder : Theme.cardBorder
    scale: sliderMouse.pressed ? 0.98 : 1.0
    clip: true

    Behavior on border.color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Rectangle {
        id: fillTrack
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Math.max(0, Math.min(parent.width, parent.width * root.value))
        radius: parent.radius
        color: root.muted ? Theme.chipBg : Theme.accentSoft

        Behavior on width {
            SpringAnimation {
                spring: 16.0
                damping: 1.8
                epsilon: 0.25
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            id: iconText
            text: root.icon
            color: root.muted ? "#fd3232" : (fillTrack.width > 30 ? Theme.accent : Theme.fg)
            font { family: Theme.nerdFontFamily; pixelSize: 13 }
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            text: root.title
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.valueText
            color: root.muted ? "#fd3232" : Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: sliderMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            let pct = Math.max(0.0, Math.min(1.0, mouse.x / width))
            root.sliderMoved(pct)
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                let pct = Math.max(0.0, Math.min(1.0, mouse.x / width))
                root.sliderMoved(pct)
            }
        }
    }
}
