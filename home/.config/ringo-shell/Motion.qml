pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    // Mirrors Ricelin's Motion but simplified for niri (no Flags.reduceMotion yet).
    // Keep durations sub-linear so pillScale doesn't blow up timings.
    property bool reduceMotion: false
    readonly property real mult: reduceMotion ? 0.4 : 1

    readonly property int fast: Math.round(150 * mult)
    readonly property int standard: Math.round(225 * mult)
    readonly property int morph: Math.round(400 * mult)
    readonly property int glide: Math.round(260 * mult)

    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph: Easing.BezierSpline
    // liquid morph cubic-bezier(0.16,1,0.3,1) front-loaded chase + long settle
    readonly property var morphCurve: [0.16, 1, 0.3, 1]
}
