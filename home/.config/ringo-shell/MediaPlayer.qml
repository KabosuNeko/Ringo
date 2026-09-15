import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import IslandBackend

Rectangle {
    id: mediaCard
    Layout.fillWidth: true
    implicitHeight: MprisController.hasPlayer ? 116 : 0
    radius: 14
    color: Theme.cardBg
    visible: MprisController.hasPlayer
    clip: true
    border.color: Theme.cardBorder
    border.width: 1

    property real mprisProgress: MprisController.progress
    property string mprisTimePlayed: formatMprisTime(MprisController.polledPosition)
    property string mprisTimeTotal: formatMprisTime(MprisController.polledLength)

    function formatMprisTime(val) {
        let n = Number(val)
        if (isNaN(n) || n <= 0) return "0:00"
        let m = Math.floor(n / 60)
        let s = Math.floor(n % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 4
                    height: parent.height + 4
                    radius: 14
                    color: Theme.accentSoft
                    opacity: 0.6
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Theme.bgD
                    border.width: 1
                    border.color: Theme.cardBorder
                    clip: true

                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: MprisController.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: MprisController.artUrl !== "" && status !== Image.Error
                        asynchronous: true
                        cache: true
                        sourceSize: Qt.size(108 * Config.dpiScale, 108 * Config.dpiScale)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: MprisController.artUrl === "" || artImg.status === Image.Error || artImg.status === Image.Null
                        text: "\uf001"
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 20
                        color: Theme.accent
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: MprisController.track !== "" ? MprisController.track : "Nothing playing"
                        color: Theme.fg
                        font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        radius: 4
                        color: Theme.chipBg
                        implicitHeight: 16
                        implicitWidth: tagText.implicitWidth + 8
                        visible: MprisController.playing

                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: "PLAYING"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: 8; weight: 700 }
                        }
                    }
                }

                Text {
                    text: MprisController.artist !== "" ? MprisController.artist : "Unknown Artist"
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "⏮"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 15
                    color: prevHover.hovered ? Theme.fg : Theme.fg5
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: prevHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.prev()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Theme.accent
                    scale: playMouse.pressed ? 0.92 : (playHover.hovered ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: MprisController.playing ? "󰏤" : "󰐊"
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 15
                        color: Theme.bg
                    }

                    HoverHandler { id: playHover }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.playPause()
                    }
                }

                Text {
                    text: "⏭"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 15
                    color: nextHover.hovered ? Theme.fg : Theme.fg5
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: nextHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.next()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: barMouse.containsMouse ? 6 : 4
                radius: 3
                color: Theme.bgD
                border.width: 1
                border.color: Theme.cardBorder

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width * mediaCard.mprisProgress
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.Linear } }
                }

                MouseArea {
                    id: barMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        let len = MprisController.polledLength
                        if (len <= 0) return
                        let ratio = mouse.x / width
                        MprisController.seek(ratio * len)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: mediaCard.mprisTimePlayed
                    color: Theme.fg5
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: mediaCard.mprisTimeTotal
                    color: Theme.fg5
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                }
            }
        }
    }
}
