import QtQuick
import IslandBackend

Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 2

        Row {
            spacing: 5

            Text {
                text: SystemMonitor.vpn ? "󰦝" : "󰩟"
                color: SystemMonitor.vpn ? "#64d667" : "#6496dd"
                font { family: Theme.nerdFontFamily; pixelSize: 11 }
            }

            Text {
                text: SystemMonitor.ip
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
            }
        }

        Text {
            text: SystemMonitor.iface + (SystemMonitor.vpn ? "  VPN" : "")
            color: Theme.fg
            opacity: 0.5
            font { family: Theme.fontFamily; pixelSize: 8 }
        }
    }
}
