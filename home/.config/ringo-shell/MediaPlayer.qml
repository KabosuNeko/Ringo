import Quickshell.Widgets
import QtQuick
import IslandBackend

Rectangle {
    id: mediaCard
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: MprisController.hasPlayer ? 118 : 0
    radius: 14
    color: Theme.cardBg
    visible: MprisController.hasPlayer
    clip: true
    border.color: Theme.cardBorder
    border.width: 1

    property int artistFontSize: 10
    property string artistFontColor: Theme.fg4
    property int artistFontWeight: 400

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

     Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Row {
            width: parent.width
            height: 48
            spacing: 12

            ClippingRectangle {
                width: 48; height: 48
                radius: 10
                color: Theme.bg4
                anchors.verticalCenter: parent.verticalCenter
                border.width: 1
                border.color: Theme.pillBorder
                clip: true

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: MprisController.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: MprisController.artUrl !== "" && status !== Image.Error
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(96 * Config.dpiScale, 96 * Config.dpiScale)
                }

                Text {
                    anchors.centerIn: parent
                    visible: MprisController.artUrl === "" || artImg.status === Image.Error || artImg.status === Image.Null
                    text: "\uf001"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 18
                    color: Theme.fg4
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48 - 96 - 16
                spacing: 3

                Text {
                    width: parent.width
                    text: MprisController.track !== "" ? MprisController.track : "Nothing playing"
                    color: Theme.fg
                    font.pixelSize: 12
                    font.weight: 600
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: MprisController.artist
                    color: artistFontColor
                    font.pixelSize: artistFontSize
                    font.weight: artistFontWeight
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: "⏮"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 16
                    color: prevHover.hovered ? Theme.fg : Theme.fg4
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: prevHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { MprisController.prev() }
                    }
                }

                Rectangle {
                    width: 30; height: 30
                    radius: 15
                    color: playHover.hovered ? Theme.accentSoft : Theme.chipBg
                    border.width: 1
                    border.color: playHover.hovered ? Theme.accent : Theme.chipBorder
                    anchors.verticalCenter: parent.verticalCenter
                    scale: playMouse.pressed ? 0.92 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: MprisController.playing ? "󰏤" : "󰐊"
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 14
                        color: playHover.hovered ? Theme.accent : Theme.fg
                        Behavior on color { ColorAnimation { duration: 120 } }
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
                    font.pixelSize: 16
                    color: nextHover.hovered ? Theme.fg : Theme.fg4
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: nextHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { MprisController.next() }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6

            Rectangle {
                width: parent.width
                height: barMouse.containsMouse ? 5 : 3
                radius: 3
                color: Theme.bg4

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width * mediaCard.mprisProgress
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 510; easing.type: Easing.Linear } }
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

            Item {
                width: parent.width
                height: 10

                Text {
                    anchors.left: parent.left
                    text: mediaCard.mprisTimePlayed
                    color: Theme.fg5
                    font.pixelSize: 9
                    font.weight: 500
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    text: mediaCard.mprisTimeTotal
                    color: Theme.fg5
                    font.pixelSize: 9
                    font.weight: 500
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
