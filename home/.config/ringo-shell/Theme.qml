pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // surface opacity - matches foot alpha (0.8); niri blurs the layer behind
    property real surfaceOpacity: 0.8

    // accepts a hex string or a color
    function surface(c: color, alpha: real): color {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    property string fallbackBg: "#161616"
    property string fallbackFg: "#dadada"
    property string fallbackAccent: "#979797"

    // wal keys: special.background/foreground, colors.color1 (~/.cache/wal/colors.json)
    property string walBg: root.fallbackBg
    property string walFg: root.fallbackFg
    property string walAccent: root.fallbackAccent

    property color bg: surface(root.walBg, root.surfaceOpacity)
    property color bg1: surface(Qt.lighter(root.walBg, 1.5), root.surfaceOpacity)
    property color bg2: surface(Qt.lighter(root.walBg, 1.59), root.surfaceOpacity)

    property color bg4: surface(Qt.lighter(root.walBg, 1.82), root.surfaceOpacity)
    property color bg5: surface(Qt.lighter(root.walBg, 2.27), root.surfaceOpacity)


    property color bgD: surface(Qt.darker(root.walBg, 1.1), root.surfaceOpacity)
    property color bgD1: surface(Qt.darker(root.walBg, 1.02), root.surfaceOpacity)

    property color fg: root.walFg
    property color fg1: Qt.lighter(root.walFg, 1.06)
    property color fg2: Qt.lighter(root.walFg, 1.02)
    property color fg3: Qt.darker(root.walFg, 1.11)
    property color fg4: Qt.darker(root.walFg, 1.38)
    property color fg5: Qt.darker(root.walFg, 1.83)

    property color fg7: Qt.darker(root.walFg, 3.03)

    property color fgL: Qt.lighter(root.walFg, 1.07)

    property color borderBg: Qt.darker(root.walFg, 2.06)
    property color borderBg1: Qt.darker(root.walFg, 3.03)
    property color borderBg2: Qt.darker(root.walFg, 4.36)

    property color borderBgFocus: Qt.darker(root.walFg, 2.56)

    property color focusBg1: surface(Qt.lighter(root.walBg, 2.09), root.surfaceOpacity)
    property color focusBgL: surface(Qt.lighter(root.walBg, 2.41), root.surfaceOpacity) // L == lighter

    property color focusFg1: Qt.darker(root.walFg, 1.16)


    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily

    // semantic colors stay fixed
    property string warning: "#f9cb41"
    property string deleting: "#e32626"

    // accent follows pywal color1 (live)
    property string accent: root.walAccent

    FileView {
        id: walColors
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: {
            reload()
            // reload() is async: text() here still holds the old content, hence onLoaded below
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



    property color pillBorder: Qt.alpha(root.walFg, 0.08)
    property color cardBg: surface(Qt.lighter(root.walBg, 1.25), root.surfaceOpacity * 0.95)
    property color cardBorder: Qt.alpha(root.walFg, 0.09)
    property color chipBg: Qt.alpha(root.walFg, 0.06)
    property color chipBgHover: Qt.alpha(root.walFg, 0.12)
    property color chipBorder: Qt.alpha(root.walFg, 0.08)
    property color accentSoft: surface(root.walAccent, 0.18)
}