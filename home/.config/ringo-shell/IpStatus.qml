import QtQuick
import QtQuick.Layouts
import IslandBackend

Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        spacing: 1

        RowLayout {
            spacing: 5

            Text {
                text: SystemMonitor.vpn ? "󰦝" : "󰩟"
                color: SystemMonitor.vpn ? "#64d667" : Theme.accent
                font { family: Theme.nerdFontFamily; pixelSize: 11 }
            }

            Text {
                text: SystemMonitor.ip
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
            }
        }

        Text {
            text: SystemMonitor.iface + (SystemMonitor.vpn ? " · VPN" : "")
            color: Theme.fg5
            font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
            Layout.leftMargin: 16
        }
    }
}
