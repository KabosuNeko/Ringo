import QtQuick
import IslandBackend

Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 2

        Text {
            text: "↓ " + SystemMonitor.rxRate
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        }

        Text {
            text: "↑ " + SystemMonitor.txRate
            color: Theme.fg
            opacity: 0.6
            font { family: Theme.fontFamily; pixelSize: 10 }
        }
    }
}
