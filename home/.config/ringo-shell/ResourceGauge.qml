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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰍛"
                color: Theme.accent
                font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
                text: "CPU"
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
                Layout.preferredWidth: 26
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.bgD
                border.width: 1
                border.color: Theme.cardBorder

                Rectangle {
                    width: parent.width * (root.cpuPercent / 100)
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                }
            }

            Text {
                text: root.cpuPercent + "%"
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰘚"
                color: Theme.accent
                font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
                text: "RAM"
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
                Layout.preferredWidth: 26
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.bgD
                border.width: 1
                border.color: Theme.cardBorder

                Rectangle {
                    width: parent.width * (root.ramPercent / 100)
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                }
            }

            Text {
                text: root.ramPercent + "%"
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
