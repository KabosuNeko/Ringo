pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  FileView {
    path: Quickshell.env("HOME") + "/.config/ringo-shell/config.jsonc"
    watchChanges: true
    onFileChanged: reload()

    // fallback values
    JsonAdapter {
      id: adapter
      property string displayPicture: Quickshell.env("HOME") + "/.pfp.png"
      property string clockFormat: "hh:mm"
      property int pillTopMargin: 9
      property int pillBottomMargin: 26
      property string textFontFamily: "JetBrainsMono Nerd Font"
      property string nerdFontFamily: "JetBrainsMono Nerd Font Propo"
      property var timerPresets: [1, 5, 10, 15, 30]
      property int mediaPopupDuration: 3000
      property int maxWorkspaces: 5
      property int notificationDisplayTime: 3000
      property int maxNotificationsInStack: 20
      property int bandwidthRefreshInterval: 300000
      property int osdDuration: 800
      property string weatherUnits: "metric"
      property string weatherLocation: "Ho Chi Minh City"
      property int weatherRefreshInterval: 3600000
      property bool avoidDuplicateNotifications: true
      property string defaultTerminal: "foot"
      property real pillScale: 1.0
      property real dpiScale: 1.4
      property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
      property bool wsCloseOnWallpaperSet: true
      property bool wsAnimation: true
    }
  }

  readonly property alias displayPicture: adapter.displayPicture
  readonly property alias clockFormat: adapter.clockFormat
  readonly property alias pillTopMargin: adapter.pillTopMargin
  readonly property alias pillBottomMargin: adapter.pillBottomMargin
  readonly property alias textFontFamily: adapter.textFontFamily
  readonly property alias nerdFontFamily: adapter.nerdFontFamily
  readonly property alias timerPresets: adapter.timerPresets
  readonly property alias mediaPopupDuration: adapter.mediaPopupDuration
  readonly property alias maxWorkspaces: adapter.maxWorkspaces
  readonly property alias notificationDisplayTime: adapter.notificationDisplayTime
  readonly property alias maxNotificationsInStack: adapter.maxNotificationsInStack
  readonly property alias bandwidthRefreshInterval: adapter.bandwidthRefreshInterval
  readonly property alias osdDuration: adapter.osdDuration
  readonly property alias weatherUnits: adapter.weatherUnits
  readonly property alias weatherLocation: adapter.weatherLocation
  readonly property alias weatherRefreshInterval: adapter.weatherRefreshInterval
  readonly property alias avoidDuplicateNotifications: adapter.avoidDuplicateNotifications
  readonly property alias defaultTerminal: adapter.defaultTerminal
  readonly property alias pillScale: adapter.pillScale
  readonly property alias dpiScale: adapter.dpiScale
  readonly property real paddingScale: 1 + (pillScale - 1) * 0.6  // sub linear, keep padding sane
  readonly property alias wallpapersDir: adapter.wallpapersDir
  readonly property alias wsCloseOnWallpaperSet: adapter.wsCloseOnWallpaperSet
  readonly property alias wsAnimation: adapter.wsAnimation
}
