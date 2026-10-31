pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/ringo-shell/config.jsonc"
    watchChanges: true
    atomicWrites: true
    blockLoading: true
    onFileChanged: reload()

    JsonAdapter {
      id: adapter
      property string displayPicture: Quickshell.env("HOME") + "/.pfp.png"
      property string clockFormat: "hh:mm"
      property int pillTopMargin: 9
      property int pillBottomMargin: 26
      property string textFontFamily: "Maple Mono NF"
      property string nerdFontFamily: "Maple Mono NF"
      property int notificationDisplayTime: 3000
      property int maxNotificationsInStack: 20
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
      property int nightLightLowTemperature: 4000
      property int nightLightHighTemperature: 6500
      property real nightLightGamma: 1.0
      // 0 = follow the weather location
      property real nightLightLatitude: 0
      property real nightLightLongitude: 0
      property int slideshowIntervalMinutes: 30
      property int idleDimSeconds: 300
      property int idleLockSeconds: 330
      property int idleScreenOffSeconds: 360
      property int idleSuspendSeconds: 600
    }
  }

  readonly property alias displayPicture: adapter.displayPicture
  readonly property alias clockFormat: adapter.clockFormat
  readonly property alias pillTopMargin: adapter.pillTopMargin
  readonly property alias pillBottomMargin: adapter.pillBottomMargin
  readonly property alias textFontFamily: adapter.textFontFamily
  readonly property alias nerdFontFamily: adapter.nerdFontFamily
  readonly property alias notificationDisplayTime: adapter.notificationDisplayTime
  readonly property alias maxNotificationsInStack: adapter.maxNotificationsInStack
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
  readonly property alias nightLightLowTemperature: adapter.nightLightLowTemperature
  readonly property alias nightLightHighTemperature: adapter.nightLightHighTemperature
  readonly property alias nightLightGamma: adapter.nightLightGamma
  readonly property alias nightLightLatitude: adapter.nightLightLatitude
  readonly property alias nightLightLongitude: adapter.nightLightLongitude
  readonly property alias slideshowIntervalMinutes: adapter.slideshowIntervalMinutes
  readonly property alias idleDimSeconds: adapter.idleDimSeconds
  readonly property alias idleLockSeconds: adapter.idleLockSeconds
  readonly property alias idleScreenOffSeconds: adapter.idleScreenOffSeconds
  readonly property alias idleSuspendSeconds: adapter.idleSuspendSeconds

  // Replace only the listed values so comments, key order and formatting survive.
  // An unloaded file must not fall back to writeAdapter(): that would rewrite
  // the whole config and discard comments.
  function writeConfigKeys(values: var): bool {
    let text = configFile.text()
    if (text.length === 0) return false
    for (const key in values) {
      const value = typeof values[key] === "string"
                  ? JSON.stringify(values[key]) : String(values[key])
      const pattern = new RegExp('("' + key + '"\\s*:\\s*)[^,\\n}]+')
      if (pattern.test(text)) {
        text = text.replace(pattern, "$1" + value)
        continue
      }
      const close = text.lastIndexOf("}")
      if (close < 0) return false
      const head = text.substring(0, close).replace(/\s*$/, "")
      text = head + (head.endsWith("{") ? "" : ",")
           + '\n  "' + key + '": ' + value + '\n' + text.substring(close)
    }
    configFile.setText(text)
    return true
  }

  function setNotificationPolicy(displayTime: int, maxStored: int,
                                 avoidDuplicate: bool, osdDuration: int): void {
    const display = Math.max(1000, Math.min(15000, Math.round(displayTime)))
    const stored = Math.max(1, Math.min(100, Math.round(maxStored)))
    const osd = Math.max(200, Math.min(5000, Math.round(osdDuration)))

    if (!writeConfigKeys({
      notificationDisplayTime: display,
      maxNotificationsInStack: stored,
      avoidDuplicateNotifications: avoidDuplicate,
      osdDuration: osd
    })) return
    adapter.notificationDisplayTime = display
    adapter.maxNotificationsInStack = stored
    adapter.avoidDuplicateNotifications = avoidDuplicate
    adapter.osdDuration = osd
  }

  // Keep dim < lock < screen-off < suspend. Changing an earlier timer pushes
  // the later ones; changing a later one pulls the earlier ones back.
  function setIdleTimer(key: string, seconds: int): void {
    let dim = adapter.idleDimSeconds
    let lock = adapter.idleLockSeconds
    let off = adapter.idleScreenOffSeconds
    let suspend = adapter.idleSuspendSeconds
    const value = Math.round(seconds)

    if (key === "dim") dim = Math.max(30, Math.min(3600, value))
    else if (key === "lock") lock = Math.max(60, Math.min(7200, value))
    else if (key === "off") off = Math.max(90, Math.min(21600, value))
    else if (key === "suspend")
      suspend = value <= 0 ? 0 : Math.max(120, Math.min(86400, value))
    else return

    if (key === "dim") {
      lock = Math.max(lock, dim + 30)
      off = Math.max(off, lock + 30)
      if (suspend > 0) suspend = Math.max(suspend, off + 30)
    } else if (key === "lock") {
      dim = Math.min(dim, lock - 30)
      off = Math.max(off, lock + 30)
      if (suspend > 0) suspend = Math.max(suspend, off + 30)
    } else if (key === "off") {
      lock = Math.min(lock, off - 30)
      dim = Math.min(dim, lock - 30)
      if (suspend > 0) suspend = Math.max(suspend, off + 30)
    } else if (suspend > 0) {
      suspend = Math.max(suspend, off + 30)
    }

    dim = Math.max(30, dim)
    lock = Math.max(dim + 30, lock)
    off = Math.max(lock + 30, off)
    if (suspend > 0) suspend = Math.max(off + 30, suspend)

    if (!writeConfigKeys({
      idleDimSeconds: dim,
      idleLockSeconds: lock,
      idleScreenOffSeconds: off,
      idleSuspendSeconds: suspend
    })) return
    adapter.idleDimSeconds = dim
    adapter.idleLockSeconds = lock
    adapter.idleScreenOffSeconds = off
    adapter.idleSuspendSeconds = suspend
  }

  function setNightLight(low: int, high: int, gamma: real): void {
    const lo = Math.max(2000, Math.min(6500, Math.round(low)))
    const hi = Math.max(lo + 500, Math.min(10000, Math.round(high)))
    const g = Math.max(0.5, Math.min(1.5, gamma))

    if (!writeConfigKeys({
      nightLightLowTemperature: lo,
      nightLightHighTemperature: hi,
      nightLightGamma: g
    })) return
    adapter.nightLightLowTemperature = lo
    adapter.nightLightHighTemperature = hi
    adapter.nightLightGamma = g
  }
}
