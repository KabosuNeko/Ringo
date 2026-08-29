pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // surface opacity - matches foot alpha (0.8); niri blurs the layer behind
    property real surfaceOpacity: 0.8

    // Accepts a hex string or a color, returns the same color with `alpha`.
    function surface(c: color, alpha: real): color {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    // -- pywal base colors (fallbacks = default gray palette) --
    property string fallbackBg: "#161616"
    property string fallbackFg: "#dadada"
    property string fallbackAccent: "#979797"

    // special.background / special.foreground / colors.color1 from
    // ~/.cache/wal/colors.json; every palette below derives from these so
    // the whole shell follows the wallpaper (live-reload on wal change).
    property string walBg: root.fallbackBg
    property string walFg: root.fallbackFg
    property string walAccent: root.fallbackAccent

    // more darker (descending)
    property color bg: surface(root.walBg, root.surfaceOpacity)
    property color bg1: surface(Qt.lighter(root.walBg, 1.5), root.surfaceOpacity)
    property color bg2: surface(Qt.lighter(root.walBg, 1.59), root.surfaceOpacity)
    property color bg3: surface(Qt.lighter(root.walBg, 1.68), root.surfaceOpacity)
    property color bg4: surface(Qt.lighter(root.walBg, 1.82), root.surfaceOpacity)
    property color bg5: surface(Qt.lighter(root.walBg, 2.27), root.surfaceOpacity)
    property color bg6: surface(Qt.lighter(root.walBg, 2.41), root.surfaceOpacity)
    property color bg7: surface(Qt.lighter(root.walBg, 2.91), root.surfaceOpacity)
    property color bg8: surface(Qt.lighter(root.walBg, 3.14), root.surfaceOpacity)
    property color bg9: surface(Qt.lighter(root.walBg, 3.64), root.surfaceOpacity)

    property color bgD: surface(Qt.darker(root.walBg, 1.1), root.surfaceOpacity)
    property color bgD1: surface(Qt.darker(root.walBg, 1.02), root.surfaceOpacity)

    // more darker (ascending)
    property color fg: root.walFg
    property color fg1: Qt.lighter(root.walFg, 1.06)
    property color fg2: Qt.lighter(root.walFg, 1.02)
    property color fg3: Qt.darker(root.walFg, 1.11)
    property color fg4: Qt.darker(root.walFg, 1.38)
    property color fg5: Qt.darker(root.walFg, 1.83)
    property color fg6: Qt.darker(root.walFg, 2.06)
    property color fg7: Qt.darker(root.walFg, 3.03)
    property color fg8: Qt.darker(root.walFg, 4.45)
    property color fgL: Qt.lighter(root.walFg, 1.07)

    // CC sliders
    property color sliderBg: Qt.darker(root.walFg, 1.08)

    property color fg3D: Qt.darker(root.walFg, 1.31)
    property color fg4D: Qt.darker(root.walFg, 1.11) // d == darker

    property color borderBg: Qt.darker(root.walFg, 2.06)
    property color borderBg1: Qt.darker(root.walFg, 3.03)
    property color borderBg2: Qt.darker(root.walFg, 4.36)
    property color borderBg3: Qt.darker(root.walFg, 5.45)
    property color borderBg4: Qt.darker(root.walFg, 6.06)
    property color borderBgFocus: Qt.darker(root.walFg, 2.56)
    property color borderBgFocus1: Qt.darker(root.walFg, 2.76)

    // focus bg
    property color focusBg: surface(Qt.lighter(root.walBg, 1.82), root.surfaceOpacity)
    property color focusBg1: surface(Qt.lighter(root.walBg, 2.09), root.surfaceOpacity)
    property color focusBgD: surface(Qt.lighter(root.walBg, 1.55), root.surfaceOpacity)
    property color focusBgL: surface(Qt.lighter(root.walBg, 2.41), root.surfaceOpacity) // L == lighter

    property color focusFg: Qt.darker(root.walFg, 1.04)
    property color focusFg1: Qt.darker(root.walFg, 1.16)
    property color focusFg2: Qt.darker(root.walFg, 1.3)

    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily

    // semantic colors stay fixed
    property string warning: "#f9cb41"
    property string deleting: "#e32626"

    // accent follows pywal color1 (live)
    property string accent: root.walAccent

    // Colors from pywal (~/.cache/wal/colors.json); live-reloads on wal change.
    FileView {
        id: walColors
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: {
            reload()
            // applyWal() is NOT called here: reload() loads asynchronously,
            // so text() would still hold the OLD content. Wait for onLoaded
            // below, which fires after the new content is actually in place.
        }
        onLoaded: {
            root.applyWal()
        }
    }

    function applyWal(): void {
        try {
            var text = walColors.text()
            if (text !== "") {
                var data = JSON.parse(text)
                if (data && data.colors) {
                    if (data.special && data.special.background) root.walBg = data.special.background
                    if (data.special && data.special.foreground) root.walFg = data.special.foreground
                    if (data.colors.color1) root.walAccent = data.colors.color1
                    return
                }
            }
        } catch (e) {
            console.log("pywal colors.json parse error:", e)
        }
        root.walBg = root.fallbackBg
        root.walFg = root.fallbackFg
        root.walAccent = root.fallbackAccent
    }

    Component.onCompleted: applyWal()

    property string coverArtGlowShadow: "#80aae6" // hardcored for now

    // Ricelin-inspired surface tokens (compositor-agnostic, niri-safe)
    property color shadow: Qt.rgba(0, 0, 0, 0.55)
    property real shadowOpacity: 0.5
    property color hair: Qt.alpha(root.walFg, 0.13)
    property color hairSoft: Qt.alpha(root.walFg, 0.08)
    property color sheen: Qt.alpha(root.walFg, 0.07)
    property color frameBg: Qt.alpha(root.walFg, 0.055)
    property color frameBorder: Qt.alpha(root.walFg, 0.10)

    property int fontSizeBase: 13
    property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}