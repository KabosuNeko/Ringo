import QtQuick
import QtQuick.Layouts
import IslandBackend

Rectangle {
    id: root

    // Percentages tick every second; a fixed slot stops the pill resizing.
    TextMetrics {
        id: pctMetrics
        font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
        text: "100%"
    }

    readonly property int cpuPercent: SystemMonitor.cpuPercent
    readonly property int ramPercent: SystemMonitor.ramPercent

    radius: 4
    color: Theme.cardBg
    border.width: 1
    border.color: Theme.cardBorder

    // shell.qml pins this card to 52 px; user and uptime live in the dashboard header
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            // the card is wider than this row's content, and a ColumnLayout does
            // not stretch a nested layout across it: without this the CPU/RAM
            // block hugs the left edge while the network card's spans its card
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 16
                    radius: 2
                    color: Theme.chipBg

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * (root.cpuPercent / 100)
                        radius: 2
                        color: Theme.accent
                        Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easeOut } }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "CPU"
                    color: Theme.fg
                    font {
                        family: Theme.fontFamily
                        pixelSize: 8
                        weight: 600
                        letterSpacing: 0.5
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.cpuPercent + "%"
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    Layout.preferredWidth: pctMetrics.width
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 16
                    radius: 2
                    color: Theme.chipBg

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * (root.ramPercent / 100)
                        radius: 2
                        color: Theme.warning
                        Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easeOut } }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "RAM"
                    color: Theme.fg
                    font {
                        family: Theme.fontFamily
                        pixelSize: 8
                        weight: 600
                        letterSpacing: 0.5
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.ramPercent + "%"
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    Layout.preferredWidth: pctMetrics.width
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
