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
            }
        }
    }
}
