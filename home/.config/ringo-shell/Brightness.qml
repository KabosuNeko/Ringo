import Quickshell
import QtQuick
import QtQuick.Layouts
import IslandBackend

RowLayout {
    id: root

    signal brightnessUpdated()

    readonly property int brightness: BrightnessController.brightness
    readonly property int maxBrightness: BrightnessController.maxBrightness
    readonly property string backlightDevice: BrightnessController.device
    readonly property real percent: BrightnessController.percent

    Connections {
        target: BrightnessController
        function onBrightnessChanged() {
            root.brightnessUpdated()
        }
    }

    readonly property string icon: {
        if (percent >= 0.75) return String.fromCodePoint(0xf00e0)
        if (percent >= 0.50) return String.fromCodePoint(0xf00df)
        if (percent >= 0.25) return String.fromCodePoint(0xf00de)
        return String.fromCodePoint(0xf00dd)
    }

    Text {
        text: root.icon
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 10 }
    }

    Text {
        text: Math.round(root.percent * 100) + "%"
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
    }
}
