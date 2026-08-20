pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // surface opacity - matches foot alpha (0.8); niri blurs the layer behind
    property real surfaceOpacity: 0.8

    function surface(hex: string, alpha: real): color {
        return Qt.rgba(
            parseInt(hex.substring(1, 3), 16) / 255,
            parseInt(hex.substring(3, 5), 16) / 255,
            parseInt(hex.substring(5, 7), 16) / 255,
            alpha)
    }

    // more darker (descending)
    property color bg: surface("#161616", root.surfaceOpacity)
    property color bg1: surface("#212121", root.surfaceOpacity)
    property color bg2: surface("#232323", root.surfaceOpacity)
    property color bg3: surface("#252525", root.surfaceOpacity)
    property color bg4: surface("#282828", root.surfaceOpacity)
    property color bg5: surface("#323232", root.surfaceOpacity)
    property color bg6: surface("#353535", root.surfaceOpacity)
    property color bg7: surface("#404040", root.surfaceOpacity)
    property color bg8: surface("#454545", root.surfaceOpacity)
    property color bg9: surface("#505050", root.surfaceOpacity)

    property color bgD: surface("#141414", root.surfaceOpacity)
    property color bgD1: surface("#191919", root.surfaceOpacity)

    // more darker (ascending)
    property string fg: "#dadada"
    property string fg1: "#e7e7e7"
    property string fg2: "#dfdfdf"
    property string fg3: "#c4c4c4"
    property string fg4: "#9e9e9e"
    property string fg5: "#777777"
    property string fg6: "#6a6a6a"
    property string fg7: "#484848"
    property string fg8: "#313131"
    property string fgL: "#e9e9e9"

    // CC sliders
    property string sliderBg: "#c9c9c9"

    property string fg3D: "#a7a7a7"
    property string fg4D: "#c5c4c4" // d == darker

    property string borderBg: "#6a6a6a"
    property string borderBg1: "#484848"
    property string borderBg2: "#323232"
    property string borderBg3: "#282828"
    property string borderBg4: "#242424"
    property string borderBgFocus: "#555555"
    property string borderBgFocus1: "#4f4f4f"

    // focus bg
    property color focusBg: surface("#282828", root.surfaceOpacity)
    property color focusBg1: surface("#2e2e2e", root.surfaceOpacity)
    property color focusBgD: surface("#222222", root.surfaceOpacity)
    property color focusBgL: surface("#353535", root.surfaceOpacity) // L == lighter

    property string focusFg: "#d1d1d1"
    property string focusFg1: "#bcbcbc"
    property string focusFg2: "#a8a8a8"

    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily

    property string warning: "#f9cb41"
    property string deleting: "#e32626"

    property string fallbackAccent: "#979797"
    property string accent: "#979797"

    // Accent color from pywal (~/.cache/wal/colors.json), falls back to default
    FileView {
        id: walColors
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: {
            reload()
            root.reloadAccent()
        }
    }

    function reloadAccent(): void {
        try {
            var text = walColors.text()
            if (text !== "") {
                var data = JSON.parse(text)
                if (data && data.colors && data.colors.color1) {
                    root.accent = data.colors.color1
                    return
                }
            }
        } catch (e) {
            console.log("pywal colors.json parse error:", e)
        }
        root.accent = root.fallbackAccent
    }

    Component.onCompleted: reloadAccent()

    property string coverArtGlowShadow: "#80aae6" // hardcored for now

    property int fontSizeBase: 13
    property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}
