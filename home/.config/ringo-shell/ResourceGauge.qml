import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property int cpuPercent: 0
    property int ramPercent: 0
    property string ramDetail: "-- / -- GB"
    property real prevTotal: 0
    property real prevIdle: 0
    property bool active: true

    radius: 10
    color: Theme.cardBg
    border.width: 1
    border.color: Theme.cardBorder

    Process {
        id: statProc
        command: ["awk", "/cpu /{print $2+$3+$4+$5+$6+$7+$8, $5} /MemTotal/{t=$2} /MemAvailable/{a=$2} END{u=t-a; printf \"%.0f %.1f %.1f\\n\", (u/t)*100, u/1048576, t/1048576}", "/proc/stat", "/proc/meminfo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                if (lines.length >= 2) {
                    let cpuParts = lines[0].trim().split(" ")
                    if (cpuParts.length >= 2) {
                        let total = parseFloat(cpuParts[0]) || 0
                        let idle = parseFloat(cpuParts[1]) || 0
                        if (root.prevTotal > 0 && total > root.prevTotal) {
                            let dTotal = total - root.prevTotal
                            let dIdle = idle - root.prevIdle
                            let usage = Math.round(100 * (1.0 - (dIdle / dTotal)))
                            root.cpuPercent = Math.max(0, Math.min(100, usage))
                        }
                        root.prevTotal = total
                        root.prevIdle = idle
                    }

                    let ramParts = lines[1].trim().split(" ")
                    if (ramParts.length >= 3) {
                        root.ramPercent = Math.max(0, Math.min(100, parseInt(ramParts[0]) || 0))
                        root.ramDetail = ramParts[1] + "/" + ramParts[2] + "G"
                    }
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 1500
        running: root.active && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statProc.running = false
            statProc.running = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // CPU Bar
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

        // RAM Bar
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
