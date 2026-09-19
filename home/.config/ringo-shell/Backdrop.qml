import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: backdropWindow

    WlrLayershell.layer: WlrLayershell.Background
    WlrLayershell.namespace: "ringo-backdrop"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true; bottom: true }
    implicitWidth: Screen.width
    implicitHeight: Screen.height
    color: "transparent"

    function reloadImage() {
        backdropImg.source = "file://" + Quickshell.env("HOME") + "/.cache/wal/wallpaper_blurred.jpg?t=" + Date.now()
    }

    IpcHandler {
        target: "backdrop"
        function reload(): void {
            backdropWindow.reloadImage()
        }
    }

    FileView {
        id: blurWatcher
        path: Quickshell.env("HOME") + "/.cache/wal/wallpaper_blurred.jpg"
        watchChanges: true
        onFileChanged: {
            delayReloadTimer.restart()
        }
    }

    Timer {
        id: delayReloadTimer
        interval: 150
        repeat: false
        onTriggered: {
            backdropWindow.reloadImage()
        }
    }

    Image {
        id: backdropImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        source: "file://" + Quickshell.env("HOME") + "/.cache/wal/wallpaper_blurred.jpg"
    }

    // Subtle dark overlay to give high contrast for floating workspaces in overview
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
    }
}
