import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string rx: "..."
    property string tx: "..."
    property double _prevRx: -1
    property double _prevTx: -1

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function _fmtRate(bps: double): string {
        if (!isFinite(bps) || bps < 0) return "..."
        if (bps < 1024) return Math.round(bps) + " B/s"
        if (bps < 1048576) return (bps / 1024).toFixed(1) + " KB/s"
        return (bps / 1048576).toFixed(1) + " MB/s"
    }

    Process {
        id: bwProc
        command: ["sh", "-c", "awk 'NR>2 {gsub(/:/,\" \"); if($1==\"lo\") next; rx+=$2; tx+=$10} END {printf \"%d %d\", rx, tx}' /proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = this.text.trim().split(/\s+/)
                    const rxBytes = parseFloat(parts[0])
                    const txBytes = parseFloat(parts[1])
                    if (!isFinite(rxBytes) || !isFinite(txBytes)) return
                    if (root._prevRx < 0) {
                        root._prevRx = rxBytes
                        root._prevTx = txBytes
                        root.rx = root._fmtRate(0)
                        root.tx = root._fmtRate(0)
                        return
                    }
                    let dRx = rxBytes - root._prevRx
                    let dTx = txBytes - root._prevTx
                    if (dRx < 0) dRx = 0
                    if (dTx < 0) dTx = 0
                    root._prevRx = rxBytes
                    root._prevTx = txBytes
                    root.rx = root._fmtRate(dRx)
                    root.tx = root._fmtRate(dTx)
                } catch (e) {
                    console.log("bandwidth parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: box.miniDashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            bwProc.running = false
            bwProc.running = true
        }
        onRunningChanged: if (!running) { root._prevRx = -1; root._prevTx = -1 }
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
