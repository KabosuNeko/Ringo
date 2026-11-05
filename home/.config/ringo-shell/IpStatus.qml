import QtQuick
import QtQuick.Layouts
import IslandBackend

Item {
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        spacing: 1

        RowLayout {
            spacing: 5

            Text {
                text: SystemMonitor.vpn ? "󰦝" : "󰩟"
                color: SystemMonitor.vpn ? Theme.success : Theme.accent
                font { family: Theme.nerdFontFamily; pixelSize: Theme.fontSm }
            }

            Text {
                text: SystemMonitor.ip
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 600 }
            }
        }

        Text {
            text: SystemMonitor.iface + (SystemMonitor.vpn ? " · VPN" : "")
            color: Theme.fg5
            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
            Layout.leftMargin: 16
        }
    }
}
