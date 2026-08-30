import Quickshell.Widgets
import QtQuick
import IslandBackend

Rectangle {
    id: mediaCard
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: MprisController.hasPlayer ? 118 : 0
    radius: 16
    color: Theme.bgD
    visible: MprisController.hasPlayer
    clip: true
    border.color: Theme.borderBg3
    border.width: 1

    property int artistFontSize: 10
    property string artistFontColor: Theme.fg4
    property int artistFontWeight: 300

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
        anchors.margins: 16
        spacing: 15

        Row {
            width: parent.width
            height: 48
            spacing: 15

            ClippingRectangle {
                width: 47; height: 47
                radius: 7
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: MprisController.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: MprisController.artUrl !== "" && status !== Image.Error
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(94 * box.dpi, 94 * box.dpi)
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
                width: parent.width - 46 - 90 - 24
                spacing: 4

                Text {
                    width: parent.width
                    text: MprisController.track !== "" ? MprisController.track : "Nothing playing"
                    color: Theme.fgL
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
                spacing: 14

                Text {
                    text: "⏮"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 23
                    color: prevHover.containsMouse ? "white" : Theme.fg3
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { MprisController.prev() }
                    }
                }

                Text {
                    text: MprisController.playing ? "󰏤" : "󰐊"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 23
                    color: playHover.containsMouse ? "white" : Theme.fg2
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: playHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.playPause()
                    }
                }

                Text {
                    text: "⏭"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 23
                    color: nextHover.containsMouse ? "white" : Theme.fg3
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.next()
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width
                height: barHover.containsMouse ? 5 : 3
                radius: 8
                color: Theme.bg5

                Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutExpo } }

                Rectangle {
                    width: parent.width * mediaCard.mprisProgress
                    height: parent.height
                    radius: 5
                    color: barHover.containsMouse ? Theme.fgL : fg
                    Behavior on width { NumberAnimation { duration: 510; easing.type: Easing.Linear } }
                }

                MouseArea {
                    id: barHover
                    anchors.fill: parent
                    hoverEnabled: true
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
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    text: mediaCard.mprisTimeTotal
                    color: Theme.fg5
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
