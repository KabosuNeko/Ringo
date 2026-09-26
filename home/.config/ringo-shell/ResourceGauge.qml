import QtQuick
import QtQuick.Layouts
import IslandBackend

Rectangle {
    id: root

    readonly property int cpuPercent: SystemMonitor.cpuPercent
    readonly property int ramPercent: SystemMonitor.ramPercent

    radius: 10
    color: Theme.cardBg
    border.width: 1
    border.color: Theme.cardBorder

    // The shell pins this card to 52 px (shell.qml telemetry row), which leaves
    // 32 px of content after the 10 px paddings: the two gauges sit side by side
    // in one 16 px row. The user and uptime live in the dashboard header, so
    // this card does not repeat them.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
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
                        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "cpu"
                    color: Theme.fg
                    font {
                        family: Theme.fontFamily
                        pixelSize: 8
                        weight: 600
                        capitalization: Font.AllUppercase
                        letterSpacing: 0.5
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.cpuPercent + "%"
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
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
                        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "ram"
                    color: Theme.fg
                    font {
                        family: Theme.fontFamily
                        pixelSize: 8
                        weight: 600
                        capitalization: Font.AllUppercase
                        letterSpacing: 0.5
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.ramPercent + "%"
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                }
            }
        }
    }
}
