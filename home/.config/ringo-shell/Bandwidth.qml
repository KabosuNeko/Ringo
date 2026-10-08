import QtQuick
import QtQuick.Layouts
import IslandBackend

Item {
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        spacing: 1

        // Rates tick every second; a fixed slot keeps the pill from resizing with
        // them. JetBrains Mono means the widest sample bounds every value.
        TextMetrics {
            id: rateMetrics
            font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
            text: "999.9 MB/s"
        }

        RowLayout {
            spacing: 3
            Text {
                text: "↓"
                color: Theme.accent
                font { family: Theme.fontFamily; pixelSize: 9; weight: 700 }
            }
            Text {
                text: SystemMonitor.rxRate
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                Layout.preferredWidth: rateMetrics.width
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            spacing: 3
            Text {
                text: "↑"
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 700 }
            }
            Text {
                text: SystemMonitor.txRate
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                Layout.preferredWidth: rateMetrics.width
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
