pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // Plain QML values instead of JsonAdapter: the file is JSONC and the strict
  // JSON parser would discard every value as soon as a comment was added.
  QtObject {
    id: values

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

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/ringo-shell/config.jsonc"
    watchChanges: true
    atomicWrites: true
    blockLoading: true
    // onLoaded fires once and can precede the text; textChanged covers the
    // initial read and every reload. Our own setText() also emits it, so skip
    // that one and let onSaved finish the write.
    onFileChanged: configFile.reload()
    onTextChanged: if (!root.configWriting) root.finishLoad()
    onLoaded: root.finishLoad()
    onSaved: root.finishLoad()
    onSaveFailed: error => {
      root.configWriting = false
      root.pendingValues = root.mergeValues(root.writingValues, root.pendingValues)
      root.writingValues = ({})
      root.configError = "Could not save config: " + error
      console.warn(root.configError)
    }
  }

  // Writes are serialized: a second row edit made while the first save is in
  // flight is merged into the next write instead of reading stale file text.
  property var pendingValues: ({})
  property var writingValues: ({})
  property bool configWriting: false
  property string configError: ""

  readonly property alias displayPicture: values.displayPicture
  readonly property alias clockFormat: values.clockFormat
  readonly property alias pillTopMargin: values.pillTopMargin
  readonly property alias pillBottomMargin: values.pillBottomMargin
  readonly property alias textFontFamily: values.textFontFamily
  readonly property alias nerdFontFamily: values.nerdFontFamily
  readonly property alias notificationDisplayTime: values.notificationDisplayTime
  readonly property alias maxNotificationsInStack: values.maxNotificationsInStack
  readonly property alias osdDuration: values.osdDuration
  readonly property alias weatherUnits: values.weatherUnits
  readonly property alias weatherLocation: values.weatherLocation
  readonly property alias weatherRefreshInterval: values.weatherRefreshInterval
  readonly property alias avoidDuplicateNotifications: values.avoidDuplicateNotifications
  readonly property alias defaultTerminal: values.defaultTerminal
  readonly property alias pillScale: values.pillScale
  readonly property alias dpiScale: values.dpiScale
  readonly property real paddingScale: 1 + (pillScale - 1) * 0.6  // sub linear, keep padding sane
  readonly property alias wallpapersDir: values.wallpapersDir
  readonly property alias wsCloseOnWallpaperSet: values.wsCloseOnWallpaperSet
  readonly property alias wsAnimation: values.wsAnimation
  readonly property alias nightLightLowTemperature: values.nightLightLowTemperature
  readonly property alias nightLightHighTemperature: values.nightLightHighTemperature
  readonly property alias nightLightGamma: values.nightLightGamma
  readonly property alias nightLightLatitude: values.nightLightLatitude
  readonly property alias nightLightLongitude: values.nightLightLongitude
  readonly property alias slideshowIntervalMinutes: values.slideshowIntervalMinutes
  readonly property alias idleDimSeconds: values.idleDimSeconds
  readonly property alias idleLockSeconds: values.idleLockSeconds
  readonly property alias idleScreenOffSeconds: values.idleScreenOffSeconds
  readonly property alias idleSuspendSeconds: values.idleSuspendSeconds

  function mergeValues(first: var, second: var): var {
    const out = {}
    for (const key in first) out[key] = first[key]
    for (const key in second) out[key] = second[key]
    return out
  }

  function applyConfigValue(key: string, value: var): void {
    switch (key) {
    case "displayPicture":
      if (typeof value === "string") values.displayPicture = value
      break
    case "clockFormat":
      if (typeof value === "string") values.clockFormat = value
      break
    case "pillTopMargin":
      if (typeof value === "number") values.pillTopMargin = Math.round(value)
      break
    case "pillBottomMargin":
      if (typeof value === "number") values.pillBottomMargin = Math.round(value)
      break
    case "textFontFamily":
      if (typeof value === "string") values.textFontFamily = value
      break
    case "nerdFontFamily":
      if (typeof value === "string") values.nerdFontFamily = value
      break
    case "notificationDisplayTime":
      if (typeof value === "number") values.notificationDisplayTime = Math.round(value)
      break
    case "maxNotificationsInStack":
      if (typeof value === "number") values.maxNotificationsInStack = Math.round(value)
      break
    case "osdDuration":
      if (typeof value === "number") values.osdDuration = Math.round(value)
      break
    case "weatherUnits":
      if (typeof value === "string") values.weatherUnits = value
      break
    case "weatherLocation":
      if (typeof value === "string") values.weatherLocation = value
      break
    case "weatherRefreshInterval":
      if (typeof value === "number") values.weatherRefreshInterval = Math.round(value)
      break
    case "avoidDuplicateNotifications":
      if (typeof value === "boolean") values.avoidDuplicateNotifications = value
      break
    case "defaultTerminal":
      if (typeof value === "string") values.defaultTerminal = value
      break
    case "pillScale":
      if (typeof value === "number" && isFinite(value)) values.pillScale = value
      break
    case "dpiScale":
      if (typeof value === "number" && isFinite(value)) values.dpiScale = value
      break
    case "wallpapersDir":
      if (typeof value === "string") values.wallpapersDir = value
      break
    case "wsCloseOnWallpaperSet":
      if (typeof value === "boolean") values.wsCloseOnWallpaperSet = value
      break
    case "wsAnimation":
      if (typeof value === "boolean") values.wsAnimation = value
      break
    case "nightLightLowTemperature":
      if (typeof value === "number") values.nightLightLowTemperature = Math.round(value)
      break
    case "nightLightHighTemperature":
      if (typeof value === "number") values.nightLightHighTemperature = Math.round(value)
      break
    case "nightLightGamma":
      if (typeof value === "number" && isFinite(value)) values.nightLightGamma = value
      break
    case "nightLightLatitude":
      if (typeof value === "number" && isFinite(value)) values.nightLightLatitude = value
      break
    case "nightLightLongitude":
      if (typeof value === "number" && isFinite(value)) values.nightLightLongitude = value
      break
    case "slideshowIntervalMinutes":
      if (typeof value === "number") values.slideshowIntervalMinutes = Math.round(value)
      break
    case "idleDimSeconds":
      if (typeof value === "number") values.idleDimSeconds = Math.round(value)
      break
    case "idleLockSeconds":
      if (typeof value === "number") values.idleLockSeconds = Math.round(value)
      break
    case "idleScreenOffSeconds":
      if (typeof value === "number") values.idleScreenOffSeconds = Math.round(value)
      break
    case "idleSuspendSeconds":
      if (typeof value === "number") values.idleSuspendSeconds = Math.round(value)
      break
    }
  }

  // Remove // and /* */ comments without touching string contents.
  function stripComments(text: string): string {
    let out = ""
    let inString = false
    let escaped = false
    let i = 0
    while (i < text.length) {
      const c = text.charAt(i)
      const next = text.charAt(i + 1)
      if (inString) {
        out += c
        if (escaped) escaped = false
        else if (c === "\\") escaped = true
        else if (c === "\"") inString = false
        i++
        continue
      }
      if (c === "\"") {
        inString = true
        out += c
        i++
        continue
      }
      if (c === "/" && next === "/") {
        i += 2
        while (i < text.length && text.charAt(i) !== "\n") i++
        continue
      }
      if (c === "/" && next === "*") {
        i += 2
        while (i < text.length
               && !(text.charAt(i) === "*" && text.charAt(i + 1) === "/")) i++
        i += 2
        continue
      }
      out += c
      i++
    }
    return out
  }

  // JSONC also permits a trailing comma; remove only commas outside strings
  // that are followed by a closing brace or bracket.
  function stripTrailingCommas(text: string): string {
    let out = ""
    let inString = false
    let escaped = false
    for (let i = 0; i < text.length; i++) {
      const c = text.charAt(i)
      if (inString) {
        out += c
        if (escaped) escaped = false
        else if (c === "\\") escaped = true
        else if (c === "\"") inString = false
        continue
      }
      if (c === "\"") {
        inString = true
        out += c
        continue
      }
      if (c === ",") {
        let j = i + 1
        while (j < text.length && /\s/.test(text.charAt(j))) j++
        if (text.charAt(j) === "}" || text.charAt(j) === "]") continue
      }
      out += c
    }
    return out
  }

  function finishLoad(): void {
    loadConfig()
    root.configWriting = false
    root.writingValues = ({})
    root.configError = ""
    if (Object.keys(root.pendingValues).length > 0)
      flushConfig()
  }

  function loadConfig(): void {
    const raw = configFile.text()
    if (raw.length === 0) return
    let data
    try {
      data = JSON.parse(stripTrailingCommas(stripComments(raw)))
    } catch (error) {
      console.warn("ringo-shell: config.jsonc parse failed:", error)
      return
    }
    if (data === null || typeof data !== "object" || Array.isArray(data)) return
    for (const key in data) applyConfigValue(key, data[key])
  }

  function flushConfig(): bool {
    if (root.configWriting) return true
    const text = configFile.text()
    if (text.length === 0) return false
    const changes = root.pendingValues
    if (Object.keys(changes).length === 0) return true
    root.pendingValues = ({})
    root.writingValues = changes

    let next = text
    for (const key in changes) {
      const serialized = typeof changes[key] === "string"
                       ? JSON.stringify(changes[key]) : String(changes[key])
      // Only a key that starts a line (never one inside a comment); a string
      // value may hold commas. Every duplicate is rewritten: JSON.parse keeps the last.
      const pattern = new RegExp('^(\\s*"' + key + '"\\s*:\\s*)("(?:[^"\\\\\\n]|\\\\.)*"|[^,\\n}]+)', "gm")
      if (pattern.test(next)) {
        pattern.lastIndex = 0
        next = next.replace(pattern, (match, head) => head + serialized)
        continue
      }
      const close = next.lastIndexOf("}")
      if (close < 0) {
        root.pendingValues = root.mergeValues(changes, root.pendingValues)
        root.writingValues = ({})
        return false
      }
      const head = next.substring(0, close).replace(/\s*$/, "")
      next = head + (head.endsWith("{") ? "" : ",")
           + '\n  "' + key + '": ' + serialized + '\n' + next.substring(close)
    }
    root.configWriting = true
    configFile.setText(next)
    return true
  }

  function writeConfigKeys(changes: var): bool {
    root.pendingValues = root.mergeValues(root.pendingValues, changes)
    if (root.configWriting) return true
    return root.flushConfig()
  }

  function setNotificationPolicy(displayTime: int, maxStored: int,
                                 avoidDuplicate: bool, osdDuration: int): void {
    const display = Math.max(1000, Math.min(15000, Math.round(displayTime)))
    const stored = Math.max(1, Math.min(100, Math.round(maxStored)))
    const osd = Math.max(200, Math.min(5000, Math.round(osdDuration)))

    writeConfigKeys({
      notificationDisplayTime: display,
      maxNotificationsInStack: stored,
      avoidDuplicateNotifications: avoidDuplicate,
      osdDuration: osd
    })
    values.notificationDisplayTime = display
    values.maxNotificationsInStack = stored
    values.avoidDuplicateNotifications = avoidDuplicate
    values.osdDuration = osd
  }

  // Keep dim < lock < screen-off < suspend. Changing an earlier timer pushes
  // the later ones; changing a later one pulls the earlier ones back.
  function setIdleTimer(key: string, seconds: int): void {
    let dim = values.idleDimSeconds
    let lock = values.idleLockSeconds
    let off = values.idleScreenOffSeconds
    let suspend = values.idleSuspendSeconds
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

    writeConfigKeys({
      idleDimSeconds: dim,
      idleLockSeconds: lock,
      idleScreenOffSeconds: off,
      idleSuspendSeconds: suspend
    })
    values.idleDimSeconds = dim
    values.idleLockSeconds = lock
    values.idleScreenOffSeconds = off
    values.idleSuspendSeconds = suspend
  }

  function setNightLight(low: int, high: int, gamma: real): void {
    const lo = Math.max(2000, Math.min(6500, Math.round(low)))
    const hi = Math.max(lo + 500, Math.min(10000, Math.round(high)))
    const g = Math.max(0.5, Math.min(1.5, gamma))

    writeConfigKeys({
      nightLightLowTemperature: lo,
      nightLightHighTemperature: hi,
      nightLightGamma: g
    })
    values.nightLightLowTemperature = lo
    values.nightLightHighTemperature = hi
    values.nightLightGamma = g
  }
}
