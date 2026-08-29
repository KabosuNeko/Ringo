pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    property bool reduceMotion: false
    readonly property real mult: reduceMotion ? 0.4 : 1

    readonly property int fast: Math.round(90 * mult)
    readonly property int standard: Math.round(140 * mult)
    readonly property int morph: Math.round(220 * mult)
    readonly property int glide: Math.round(160 * mult)

    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph: Easing.OutCubic
    readonly property var morphCurve: [0.16, 1, 0.3, 1]
}
