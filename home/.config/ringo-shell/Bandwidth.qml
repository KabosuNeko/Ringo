import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string rx: "..."
    property string tx: "..."

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Process {
        id: bwProc
        command: ["sh", "-c", "awk 'NR>2 {gsub(/:/,\" \"); if($1==\"lo\") next; rx+=$2; tx+=$10} END {printf \"%.1f %.1f\", rx/1048576, tx/1048576}' /proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = this.text.trim().split(/\s+/)
                    const rxMb = parseFloat(parts[0])
                    const txMb = parseFloat(parts[1])
                    function fmt(v) {
                        if (!isFinite(v)) return "..."
                        return v >= 1024 ? (v / 1024).toFixed(1) + " GB" : v.toFixed(1) + " MB"
                    }
                    root.rx = fmt(rxMb)
                    root.tx = fmt(txMb)
                } catch (e) {
                    console.log("bandwidth parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: Config.bandwidthRefreshInterval
        running: box.miniDashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            bwProc.running = false
            bwProc.running = true
        }
    }

    Column {
        id: col
        spacing: 2

        Text {
            text: "↓ " + root.rx
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        }

        Text {
            text: "↑ " + root.tx
            color: Theme.fg
            opacity: 0.6
            font { family: Theme.fontFamily; pixelSize: 10 }
        }
    }
}
