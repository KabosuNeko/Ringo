//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import IslandBackend
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Services.Notifications

ShellRoot {
  id: root


  function closeOverlays(): void {
    box.controlCenter = false
    box.miniDashboard = false
    box.cliphistOpen = false
    box.appLauncher = false
    box.wallpaperSwitcherOpen = false
    box.powerMenuOpen = false
    box.recordMenuOpen = false
    box.keybindViewer = false
    box.settingsOpen = false
  }

  IpcHandler {
    target: "cliphist"
    function toggle(): void { const next = !box.cliphistOpen; root.closeOverlays(); box.cliphistOpen = next }
    function open(): void { root.closeOverlays(); box.cliphistOpen = true }
    function hide(): void { box.cliphistOpen = false }
    function wipe(): void {
      CliphistModel.clearAll()
      Notifier.post("Clipboard", "Clipboard cleared", "edit-clear", "Ringo", 1, 2000)
    }
  }

  IpcHandler {
    target: "controlCenter"
    function toggle(): void { const next = !box.controlCenter; root.closeOverlays(); box.controlCenter = next }
    function open(): void { root.closeOverlays(); box.controlCenter = true }
    function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
    target: "miniDashboard"
    function toggle(): void { const next = !box.miniDashboard; root.closeOverlays(); box.miniDashboard = next }
    function open(): void { root.closeOverlays(); box.miniDashboard = true }
    function hide(): void { box.miniDashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { const next = !box.appLauncher; root.closeOverlays(); box.appLauncher = next }
    function open(): void { root.closeOverlays(); box.appLauncher = true }
    function hide(): void { box.appLauncher = false }
    function search(text: string): void {
      root.closeOverlays()
      box.pendingLauncherQuery = text
      box.appLauncher = true
      if (appLauncherPanel) {
        appLauncherPanel.setSearchText(text)
      }
    }
    function launch(): void {
      if (appLauncherPanel) {
        appLauncherPanel.launchSelected()
      }
    }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { const next = !box.wallpaperSwitcherOpen; root.closeOverlays(); box.wallpaperSwitcherOpen = next }
    function open(): void { root.closeOverlays(); box.wallpaperSwitcherOpen = true }
    function hide(): void { box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "wallpaper"
    function set(path: string): void { WallpaperController.apply(path) }
    function reload(): void { WallpaperController.reload() }
    function setMode(mode: string): void {
      WallpaperController.mode = mode
      WallpaperController.reload()
    }
    function next(): void { WallpaperController.nextSlide() }
    function slideshow(state: string): void {
      if (state === "toggle")
        WallpaperController.slideshowEnabled = !WallpaperController.slideshowEnabled
      else
        WallpaperController.slideshowEnabled = (state === "on" || state === "true" || state === "1")
    }
    function interval(minutes: int): void { WallpaperController.slideshowIntervalMinutes = minutes }
    function status(): string {
      return `${WallpaperController.mode} ${WallpaperController.path}`
        + (WallpaperController.slideshowEnabled ? ` · slideshow ${WallpaperController.slideshowIntervalMinutes}m` : "")
    }
  }

  IpcHandler {
    target: "nightLight"
    function toggle(): void { NightLightController.enabled = !NightLightController.enabled }
    function on(): void { NightLightController.enabled = true }
    function off(): void { NightLightController.enabled = false }
    function force(mode: string): void { NightLightController.force = mode }
    function low(kelvin: int): void {
      Config.setNightLight(kelvin, Config.nightLightHighTemperature, Config.nightLightGamma)
    }
    function high(kelvin: int): void {
      Config.setNightLight(Config.nightLightLowTemperature, kelvin, Config.nightLightGamma)
    }
    function gamma(value: real): void {
      Config.setNightLight(Config.nightLightLowTemperature, Config.nightLightHighTemperature, value)
    }
    function status(): string {
      const where = `${NightLightController.locationExplicit ? "pinned" : "auto"} `
        + `${NightLightController.latitude.toFixed(2)},${NightLightController.longitude.toFixed(2)}`
      return NightLightController.active
        ? `${NightLightController.temperature}K · ${where}`
        : (NightLightController.error !== "" ? "error: " + NightLightController.error : "off")
    }
  }

  IpcHandler {
    target: "quietMode"
    function toggle(): void { Notifier.dndEnabled = !Notifier.dndEnabled }
    function on(): void { Notifier.dndEnabled = true }
    function off(): void { Notifier.dndEnabled = false }
    function status(): string { return Notifier.dndEnabled ? "on" : "off" }
  }

  IpcHandler {
    target: "airplaneMode"
    function toggle(): void { ccButtons.toggleAirplaneMode() }
    function on(): void { ccButtons.setAirplaneMode(true) }
    function off(): void { ccButtons.setAirplaneMode(false) }
    function status(): string { return ccButtons.airplaneMode ? "on" : "off" }
  }

  IpcHandler {
    target: "keybinds"
    function toggle(): void { const next = !box.keybindViewer; root.closeOverlays(); box.keybindViewer = next }
    function open(): void { root.closeOverlays(); box.keybindViewer = true }
    function hide(): void { box.keybindViewer = false }
    function search(query: string): void {
      root.closeOverlays()
      box.keybindViewer = true
      if (keybindViewerLoader.item) keybindViewerLoader.item.setSearchText(query)
    }
  }

  // Health report: engines, palette, state, external tools.
  IpcHandler {
    target: "doctor"
    function check(): string { return root.doctorReport() }
  }

  // Scripts bound to keybinds post through here instead of spawning notify-send.
  IpcHandler {
    target: "notify"
    function post(summary: string, body: string, icon: string, urgency: int): void {
      Notifier.post(summary, body, icon, "Ringo", urgency)
    }
  }

  IpcHandler {
    target: "powerMenu"
    function toggle(): void { const next = !box.powerMenuOpen; root.closeOverlays(); box.powerMenuOpen = next }
    function open(): void { root.closeOverlays(); box.powerMenuOpen = true }
    function hide(): void { box.powerMenuOpen = false }
  }

  IpcHandler {
    target: "settings"
    function toggle(): void { const next = !box.settingsOpen; box.settingsPage = "main"; root.closeOverlays(); box.settingsOpen = next }
    function open(): void { box.settingsPage = "main"; root.closeOverlays(); box.settingsOpen = true }
    function hide(): void { box.settingsOpen = false }
    function page(name: string): void { root.closeOverlays(); box.settingsPage = name; box.settingsOpen = true }
  }

  IpcHandler {
    target: "recordMenu"
    function toggle(): void { const next = !box.recordMenuOpen; root.closeOverlays(); box.recordMenuOpen = next }
    function open(): void { root.closeOverlays(); box.recordMenuOpen = true }
    function hide(): void { box.recordMenuOpen = false }
  }

  IpcHandler {
    target: "calendar"
    function toggle(): void { calendarPopup.shown = !calendarPopup.shown; weatherPopup.shown = false }
    function open(): void { calendarPopup.shown = true; weatherPopup.shown = false }
    function hide(): void { calendarPopup.shown = false }
  }

  IpcHandler {
    target: "weather"
    function toggle(): void { weatherPopup.shown = !weatherPopup.shown; calendarPopup.shown = false }
    function open(): void { weatherPopup.shown = true; calendarPopup.shown = false }
    function hide(): void { weatherPopup.shown = false }
  }

  IpcHandler {
    target: "lock"
    // No unlock() here: only LockScreen.qml's PAM path may dismiss the lock.
    function lock(): void { LockController.lock() }
  }

  IpcHandler {
    target: "media"
    function playPause(): void { MprisController.playPause() }
    function next(): void { MprisController.next() }
    function prev(): void { MprisController.prev() }
    function stop(): void { MprisController.stop() }
  }

  IpcHandler {
    target: "brightness"
    function up(): void { BrightnessController.step(2) }
    function down(): void { BrightnessController.step(-2) }
    function step(delta: real): void { BrightnessController.step(delta) }
  }

  // 0.5 let the wallpaper show through and broke pywal's bg/fg contrast
  property real barSurfaceOpacity: 0.85


  // needed: false means the feature that uses the tool degrades gracefully
  readonly property var doctorToolChecks: [
    { name: "niri",              needed: true,  why: "compositor" },
    { name: "qs",                needed: true,  why: "shell runtime" },
    { name: "wal",               needed: true,  why: "palette generation" },
    { name: "cliphist",          needed: true,  why: "clipboard history" },
    { name: "wl-copy",           needed: true,  why: "clipboard writes" },
    { name: "wl-paste",          needed: true,  why: "clipboard watcher" },
    { name: "foot",              needed: false, why: "default terminal" },
    { name: "wl-screenrec",      needed: false, why: "screen recording" },
    { name: "fd",                needed: false, why: "launcher file search" },
    { name: "nmcli",             needed: false, why: "Ethernet/VPN controls" },
    { name: "fcitx5",            needed: false, why: "input method" },
    { name: "canberra-gtk-play", needed: false, why: "sound events" }
  ]

  // The diagnostics verdict outlives the panel: the Settings Loader is destroyed
  // on close, so the row reads it from the host instead of itself.
  property string diagnosticVerdict: ""

  Component.onCompleted: {
    WeatherController.weatherLocation = Config.weatherLocation
    WeatherController.weatherUnits = Config.weatherUnits
    WeatherController.refreshInterval = Config.weatherRefreshInterval
    WeatherController.refresh()
    NightLightController.lowTemperature = Config.nightLightLowTemperature
    NightLightController.highTemperature = Config.nightLightHighTemperature
    NightLightController.gamma = Config.nightLightGamma
    WallpaperController.slideshowDir = Config.wallpapersDir
    WallpaperController.slideshowIntervalMinutes = Config.slideshowIntervalMinutes
    applyNightLightLocation()
    WallpaperController.start()
    NightLightController.start()
  }

  // pinned location from config.jsonc, else the weather widget's city
function doctorReport(): string {
  const out = []
  out.push(Tools.version())

  const wall = WallpaperController
  out.push("")
  out.push("[wallpaper] " + wall.mode + " · " + (wall.path.length > 0 ? wall.path : "(no image)"))
  out.push("  engine: " + (wall.ready ? "ready" : wall.busy ? "starting" : "stopped")
           + (wall.slideshowEnabled ? " · slideshow every " + wall.slideshowIntervalMinutes + "m" : ""))
  if (wall.error.length > 0) out.push("  error: " + wall.error)

  const nl = NightLightController
  out.push("")
  out.push("[night light] " + (nl.enabled ? "enabled" : "disabled")
           + (nl.force !== "off" ? " · forced " + nl.force : ""))
  out.push("  wlsunset: " + (nl.active ? "active, " + nl.temperature + "K"
                                     : nl.error.length > 0 ? "unavailable" : "stopped"))
  out.push("  location: " + (nl.locationExplicit ? "pinned" : "auto") + " "
           + nl.latitude.toFixed(2) + "," + nl.longitude.toFixed(2)
           + " · " + nl.lowTemperature + "K night / " + nl.highTemperature + "K day"
           + " · gamma " + nl.gamma.toFixed(2))
  if (nl.error.length > 0) out.push("  error: " + nl.error)

  const wal = Quickshell.env("HOME") + "/.cache/wal/colors.json"
  const state = Quickshell.env("HOME") + "/.local/state/quickshell/ringo-shell/state.json"
  out.push("")
  out.push("[files]")
  out.push("  palette: " + (Tools.fileExists(wal) ? "ok" : "missing") + "  " + wal)
  out.push("  state:   " + (Tools.fileExists(state) ? "ok" : "absent") + "  " + state)

  const missingRequired = []
  const missingOptional = []
  for (const tool of doctorToolChecks) {
    if (Tools.have(tool.name)) continue
    if (tool.needed) missingRequired.push(tool.name + " (" + tool.why + ")")
    else missingOptional.push(tool.name + " (" + tool.why + ")")
  }
  out.push("")
  out.push("[tools] " + doctorToolChecks.length + " checked")
  out.push("  missing required: " + (missingRequired.length > 0 ? missingRequired.join(", ") : "none"))
  out.push("  missing optional: " + (missingOptional.length > 0 ? missingOptional.join(", ") : "none"))

  const problems = []
  if (missingRequired.length > 0) problems.push(missingRequired.length + " required tool(s) missing")
  if (wall.error.length > 0) problems.push("wallpaper: " + wall.error)
  if (nl.enabled && !nl.active && nl.error === "")
    problems.push("night light: enabled but wlsunset is not running")
  else if (nl.enabled && nl.error.length > 0) problems.push("night light: " + nl.error)
  const stale = Tools.backendStale()
  if (stale.length > 0) problems.push(stale)
  out.push("")
  out.push(problems.length === 0 ? "verdict: ok" : "verdict: " + problems.join(" | "))
  return out.join("\n")
  }


  function applyNightLightLocation(): void {
    if (Config.nightLightLatitude !== 0 || Config.nightLightLongitude !== 0) {
      NightLightController.latitude = Config.nightLightLatitude
      NightLightController.longitude = Config.nightLightLongitude
      return
    }
    NightLightController.clearLocationOverride()
    if (WeatherController.latitude !== 0 || WeatherController.longitude !== 0)
      NightLightController.setAutoLocation(WeatherController.latitude, WeatherController.longitude)
  }

  Connections {
    target: WeatherController
    function onCoordinatesChanged() { root.applyNightLightLocation() }
  }

  Connections {
    target: Config
    function onWeatherLocationChanged() { WeatherController.weatherLocation = Config.weatherLocation; WeatherController.refresh() }
    function onWeatherUnitsChanged() { WeatherController.weatherUnits = Config.weatherUnits; WeatherController.refresh() }
    function onWeatherRefreshIntervalChanged() { WeatherController.refreshInterval = Config.weatherRefreshInterval }
    function onNightLightLowTemperatureChanged() { NightLightController.lowTemperature = Config.nightLightLowTemperature }
    function onNightLightHighTemperatureChanged() { NightLightController.highTemperature = Config.nightLightHighTemperature }
    function onNightLightGammaChanged() { NightLightController.gamma = Config.nightLightGamma }
    function onNightLightLatitudeChanged() { root.applyNightLightLocation() }
    function onNightLightLongitudeChanged() { root.applyNightLightLocation() }
    function onSlideshowIntervalMinutesChanged() { WallpaperController.slideshowIntervalMinutes = Config.slideshowIntervalMinutes }
    function onWallpapersDirChanged() { WallpaperController.slideshowDir = Config.wallpapersDir }
  }

  // refresh timer only runs while the weather UI is on screen
  readonly property bool weatherUiVisible: weatherPopup.shown || box.miniDashboard
  // playback timer stays off while the control center is closed
  Binding {
    target: MprisController
    property: "active"
    value: box.controlCenter
  }

  Binding {
    target: WeatherController
    property: "active"
    value: root.weatherUiVisible
  }
  // Opening the weather UI fetches immediately so it never shows stale data.
  onWeatherUiVisibleChanged: {
    if (weatherUiVisible) WeatherController.refresh()
  }


  readonly property int notifMaxHeight: 97

  PanelWindow {
    id: panelWindow
    visible: !LockController.locked
    readonly property bool overlayActive: box.controlCenter || box.miniDashboard || box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen || box.powerMenuOpen || box.recordMenuOpen || box.keybindViewer || box.settingsOpen
    readonly property bool fullKeyboardOverlay: box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen || box.powerMenuOpen || box.recordMenuOpen || box.keybindViewer || box.settingsOpen
    WlrLayershell.layer: overlayActive ? WlrLayershell.Overlay : WlrLayershell.Top
    WlrLayershell.namespace: "ringo-shell"
    WlrLayershell.keyboardFocus: fullKeyboardOverlay
                                 ? WlrKeyboardFocus.Exclusive
                                 : (box.controlCenter || box.miniDashboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
    // one fixed surface: the island morphs inside it, so Wayland never resizes
    readonly property real surfaceWidth: 640
    readonly property real surfaceHeight: 640
    implicitWidth: Math.ceil(surfaceWidth * box.dpi)
    implicitHeight: Math.ceil((box.y + surfaceHeight) * box.dpi)

    anchors {
      top: true
    }

    margins.top: Config.pillTopMargin
    exclusiveZone: Config.pillBottomMargin
    color: "transparent"

    mask: Region {
      x: box.popoverActive ? 0 : Math.floor(box.x - box.width * (box.dpi - 1) / 2)
      y: box.popoverActive ? 0 : Math.floor(box.y)
      width: box.popoverActive
             ? Math.ceil(panelWindow.surfaceWidth * box.dpi)
             : Math.ceil(box.width * box.dpi)
      height: box.popoverActive
              ? Math.ceil(panelWindow.surfaceHeight * box.dpi)
              : Math.ceil(box.height * box.dpi)
    }

    // click outside a popover closes it
    MouseArea {
      anchors.fill: parent
      visible: box.popoverActive
      enabled: box.popoverActive
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: {
        root.closeOverlays()
        box.activeOsd = ""
      }
    }

    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: !LockController.locked ? 1 : 0
      visible: opacity > 0
      // the island clips its growing content, like a Dynamic Island
      clip: true
      focus: true

      Keys.onEscapePressed: (event) => {
        root.closeOverlays()
        box.activeOsd = ""
        event.accepted = true
      }

      property bool appLauncher: false
      property bool keybindViewer: false
      property string pendingLauncherQuery: ""
      HoverHandler { id: boxHoverHandler; onHoveredChanged: box.hovered = hovered }
      property bool hovered: false
      property bool miniDashboard: false
      property bool controlCenter: false
      property bool cliphistOpen: false
      property bool wallpaperSwitcherOpen: false
      property bool powerMenuOpen: false
      property bool recordMenuOpen: false
      property bool settingsOpen: false
      property string settingsPage: "main"

      readonly property bool hasBattery: SystemMonitor.hasBattery
      readonly property bool charging: SystemMonitor.charging
      readonly property string batteryIconColor: !SystemMonitor.hasBattery
        || SystemMonitor.charging
        || SystemMonitor.batteryPercentage >= 40
        ? Theme.batteryGood
        : SystemMonitor.batteryPercentage >= 20 ? Theme.batteryWarn : Theme.batteryCritical
      readonly property int batteryLevel: SystemMonitor.batteryPercentage
      readonly property string batteryIcon: SystemMonitor.batteryIcon

      onChargingChanged: {
        if (!box.controlCenter) box.activeOsd = "battery"
        osdHideTimer.interval = Config.osdDuration
        osdHideTimer.restart()
      }

      property int sliderHeight: 6
      property int sliderRadius: 3
      property string sliderColor: Theme.accent
      // extra clickable area above/below the thin slider bars, scales with sliderHeight
      property int sliderHitSlop: 12

      property string activeOsd: "" // volume, brightness, battery

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }

      // 1080p is the reference: 1440p is 1.33x, a 4K logical desktop 2x, smaller stays 1x
      readonly property real dpi: Config.dpiScale * Math.max(1, (panelWindow.screen ? panelWindow.screen.height : 1080) / 1080)

      property bool cliphistPreviewing: false

      readonly property bool slotOpenActive: cliphistOpen || appLauncher
          || wallpaperSwitcherOpen || powerMenuOpen || recordMenuOpen
          || keybindViewer || settingsOpen
      readonly property bool slotOverlayActive: slotOpenActive
          || cliphistSlot.closing || appLauncherSlot.closing
          || wallpaperSlot.closing || powerSlot.closing
          || recordSlot.closing || keybindSlot.closing || settingsSlot.closing
      readonly property bool popoverClosing: (!controlCenter && controlCenterPanel.opacity > 0)
          || (!miniDashboard && miniDashboardPanel.opacity > 0)
      readonly property bool popoverActive: slotOverlayActive || controlCenter || miniDashboard || popoverClosing

      readonly property real barContentOpacity: !popoverActive && !notificationModule.active && !box.controlCenter && !box.miniDashboard && box.activeOsd === "" ? 1 : 0

      readonly property real barWidth: activeOsd !== "" ? 220
                     : notificationModule.active ? 320
                     : barRow.implicitWidth + (hovered && !popoverActive ? 68 : 58) * Config.paddingScale

      readonly property real barHeight: activeOsd !== "" ? 40
                  : notificationModule.active ? (notificationModule.currentHasActions ? 78 : 52)
                  : (Math.max(barRow.implicitHeight, centerClock.implicitHeight) * Config.pillScale) + 10

      readonly property real baseWidth: activeOsd !== "" ? 220
                     : notificationModule.active ? 320
                     : controlCenter ? 410
                     : appLauncher ? 420
                     : keybindViewer ? 560
                     : wallpaperSwitcherOpen ? 600
                     : settingsOpen ? 460
                     : powerMenuOpen ? 400
                     : recordMenuOpen ? 360
                     : miniDashboard ? 460
                      : (cliphistOpen && cliphistPreviewing) ? 400
                      : cliphistOpen ? 460
                        : barWidth

      readonly property real baseHeight: activeOsd !== "" ? 40
                  : notificationModule.active ? (notificationModule.currentHasActions ? 78 : 52)
                  : controlCenter
                      ? (ccColumn.implicitHeight + 24)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                   : cliphistOpen ? 270
                   : miniDashboard ? 176
                   : appLauncher ? 410
                    : keybindViewer ? 400
                    : wallpaperSwitcherOpen ? 308
                    : settingsOpen ? 584
                    : powerMenuOpen ? 90
                    : recordMenuOpen ? 90
                    : barHeight

      readonly property real baseRadius: 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight
      radius: baseRadius
      scale: dpi
      transformOrigin: Item.Top

      border.width: 1
      border.color: Theme.pillBorder

      // crisp, not springy: the pill resizes on the same clock as everything else
      Behavior on radius {
          NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easeOut }
      }

      color: controlCenter
             ? Qt.rgba(Theme.bgD1.r, Theme.bgD1.g, Theme.bgD1.b, root.barSurfaceOpacity)
             : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.barSurfaceOpacity)

      onMiniDashboardChanged: {
          if (!box.miniDashboard) {
              calendarPopup.shown = false
              weatherPopup.shown = false
          }
      }

      Behavior on implicitHeight {
        enabled: !(notificationModule.active || box.activeOsd !== "")
        NumberAnimation {
          duration: box.popoverActive ? Theme.motionOverlay : Theme.motionResize
          easing.type: Theme.easeOut
        }
      }
      Behavior on implicitWidth {
        enabled: !(notificationModule.active || box.activeOsd !== "")
        NumberAnimation {
          duration: box.popoverActive ? Theme.motionOverlay : Theme.motionResize
          easing.type: Theme.easeOut
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: box.hovered = true
        onExited: box.hovered = false

        onClicked: (mouse) => {

          if (box.controlCenter) {
            if (mouse.button === Qt.LeftButton)
                box.controlCenter = false
            return
          }

          if (box.cliphistOpen) {
            if (mouse.button === Qt.MiddleButton) {
              box.cliphistOpen = false
            }
            return
          }

          if (box.miniDashboard) {
            if (mouse.button === Qt.RightButton) {
              box.miniDashboard = false
            }
            return
          }

          if (box.powerMenuOpen) {
            if (mouse.button === Qt.LeftButton) box.powerMenuOpen = false
            return
          }
          if (box.settingsOpen) {
            if (mouse.button === Qt.LeftButton) box.settingsOpen = false
            return
          }
          if (box.recordMenuOpen) {
            if (mouse.button === Qt.LeftButton) box.recordMenuOpen = false
            return
          }
          if (box.wallpaperSwitcherOpen) {
            if (mouse.button === Qt.LeftButton) box.wallpaperSwitcherOpen = false
            return
          }
          if (box.appLauncher) {
            box.appLauncher = false
            return
          }
          if (box.keybindViewer) {
            if (mouse.button === Qt.LeftButton) box.keybindViewer = false
            return
          }

          if (mouse.button === Qt.LeftButton) {
            box.controlCenter = !box.controlCenter
            box.appLauncher = false
          }

          if (mouse.button === Qt.MiddleButton) {
            box.appLauncher = false
            box.cliphistOpen = !box.cliphistOpen
          }

          if (mouse.button === Qt.RightButton) {
              box.appLauncher = false
              box.miniDashboard = !box.miniDashboard
          }
        }
      }

      Brightness {
          id: brightnessModule
          visible: false
          onBrightnessUpdated: {
              if (!box.controlCenter) box.activeOsd = "brightness"
              osdHideTimer.interval = Config.osdDuration
              osdHideTimer.restart()
          }
      }


      // battery, volume and brightness modules stay instantiated (invisible) since they drive the OSDs
      RowLayout {
        id: barRow
        anchors.centerIn: parent
        spacing: 9 * Config.paddingScale
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity {
          enabled: !box.popoverActive
          OpacityAnimator { duration: Theme.motionFast }
        }

        Clock {
          id: centerClock
          fontSize: 11.5 * Config.pillScale
          Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
          Layout.preferredWidth: 4
          Layout.preferredHeight: 4
          radius: 2
          color: Theme.accent
          Layout.alignment: Qt.AlignVCenter
        }

        Text {
          text: Qt.formatDateTime(clock.date, "ddd MMM d")
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
          Layout.alignment: Qt.AlignVCenter
        }

        WeatherIndicator {
          id: barWeatherIndicator
          weatherFg: Theme.fg4
          showUnit: false
          Layout.alignment: Qt.AlignVCenter
          onToggleWeather: weatherPopup.shown = !weatherPopup.shown
        }

        Item {
          Layout.preferredWidth: bellRow.implicitWidth
          Layout.preferredHeight: bellRow.implicitHeight
          Layout.alignment: Qt.AlignVCenter

          RowLayout {
            id: bellRow
            anchors.fill: parent
            spacing: 3 * Config.paddingScale

            Text {
              text: "\uf0f3"
              color: bellHover.hovered ? Theme.accent : Theme.fg4
              font { family: Theme.nerdFontFamily; pixelSize: 10 * Config.pillScale }
              Behavior on color { ColorAnimation { duration: Theme.motionBase } }
            }

            Text {
              visible: notificationModule.notifications.length > 0
              text: notificationModule.notifications.length
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 9 * Config.pillScale; weight: 600 }
            }
          }

          HoverHandler { id: bellHover }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: box.controlCenter = !box.controlCenter
          }
        }

        Item {
          visible: Recorder.active
          Layout.preferredWidth: 7
          Layout.preferredHeight: 12
          Layout.alignment: Qt.AlignVCenter

          Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -0.5
            width: 7
            height: 7
            radius: 4
            color: "#ff453a"

            SequentialAnimation on opacity {
              running: Recorder.active
              loops: Animation.Infinite
              OpacityAnimator { to: 0.35; duration: Theme.motionBlink; easing.type: Theme.easeInOut }
              OpacityAnimator { to: 1.0; duration: Theme.motionBlink; easing.type: Theme.easeInOut }
            }
          }
        }

      }

      // hidden, but they still report volume/battery changes for the OSDs
      Item {
        visible: false
        anchors.fill: parent

        Battery {
          id: batMod
        }

        Volume {
          id: volumeModule
          onVolumeChanged: {
            if (!box.controlCenter) box.activeOsd = "volume"
            osdHideTimer.interval = Config.osdDuration
            osdHideTimer.restart()
          }
        }
      }

      // No surface of its own: the pairing agent is a singleton whose constructor
      // registers it on the system bus, and the Settings panel only exists while
      // it is open, so something always-instantiated has to reference it. This
      // item is also where a request that arrives with Settings closed lands.
      Item {
        id: btPairingHost

        width: 0
        height: 0

        readonly property bool requestActive: BluetoothPairingAgent.requestActive

        // A pending request has no UI anywhere but the Bluetooth page.
        function openForRequest(): void {
          root.closeOverlays()
          box.settingsPage = "bluetooth"
          box.settingsOpen = true
        }

        onRequestActiveChanged: {
          if (requestActive) openForRequest()
        }
      }

      OsdBar {
          active: box.activeOsd === "volume"
          icon: volumeModule.icon
          iconColor: volumeModule.muted ? volumeModule.mutedFg : Theme.fg
          percent: volumeModule.vol / 100
          muted: volumeModule.muted
          barWidth: volumeModule.muted ? 90 : 110
          valueText: volumeModule.muted ? "muted" : volumeModule.vol + "%"
      }

      OsdBar {
          active: box.activeOsd === "brightness"
          icon: brightnessModule.icon
          percent: brightnessModule.percent
          valueText: Math.round(brightnessModule.percent * 100) + "%"
          barWidth: 100
      }

      OsdBar {
        active: box.activeOsd === "battery"
        icon: box.batteryIcon
        iconColor: box.batteryIconColor
        valueText: box.charging ? "Charging" : "Charging stopped"
        barWidth: 0
        spacing: 5 // gap between battery icon and text
      }

      NotificationPopup {
        id: toastPopup
        active: notificationModule.active
                && box.activeOsd === ""
        notif: notificationModule.current
        onDismissRequested: {
          // dismiss() drops the entry from the stack and the queue; advance()
          // retires the toast it was showing (and picks up the next queued one)
          notificationModule.dismiss(notificationModule.current)
          notificationModule.advance()
        }
      }

      // cliphist opens on middle click
      OverlaySlot {
        id: cliphistSlot
        open: box.cliphistOpen
        openHeight: box.baseHeight - 26
        widthInset: 26
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter

        Cliphist {
          shown: box.cliphistOpen || cliphistSlot.closing
          anchors.fill: parent
          onCloseRequested: box.cliphistOpen = false
          onPreviewToggled: (active) => box.cliphistPreviewing = active
        }
      }

      // wallpaper switcher opens through IPC
      OverlaySlot {
        id: wallpaperSlot
        open: box.wallpaperSwitcherOpen
        openHeight: 280
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter
                 || box.miniDashboard
                 || box.cliphistOpen
                 || box.appLauncher

        Loader {
          id: wallpaperLoader
          anchors.fill: parent
          active: box.wallpaperSwitcherOpen || wallpaperSlot.closing

          sourceComponent: WallpaperSwitcher {
            shown: box.wallpaperSwitcherOpen || wallpaperSlot.closing
            onCloseRequested: box.wallpaperSwitcherOpen = false
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onWallpaperSwitcherOpenChanged() {
            if (box.wallpaperSwitcherOpen && wallpaperLoader.item)
              wallpaperLoader.item.forceActiveFocus()
          }
        }
      }

      // power menu opens through IPC
      OverlaySlot {
        id: powerSlot
        open: box.powerMenuOpen
        openHeight: 70
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter
                 || box.miniDashboard
                 || box.cliphistOpen
                 || box.appLauncher
                 || box.wallpaperSwitcherOpen

        Loader {
          id: powerMenuLoader
          anchors.fill: parent
          active: box.powerMenuOpen || powerSlot.closing

          sourceComponent: PowerMenu {
            shown: box.powerMenuOpen || powerSlot.closing
            onCloseRequested: box.powerMenuOpen = false
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onPowerMenuOpenChanged() {
            if (box.powerMenuOpen && powerMenuLoader.item)
              powerMenuLoader.item.forceActiveFocus()
          }
        }
      }

      // settings overlay opens through IPC or the control center gear
      OverlaySlot {
        id: settingsSlot
        open: box.settingsOpen
        openHeight: 560
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter
                 || box.miniDashboard
                 || box.cliphistOpen
                 || box.appLauncher
                 || box.wallpaperSwitcherOpen
                 || box.powerMenuOpen
                 || box.recordMenuOpen
                 || box.keybindViewer

        Loader {
          id: settingsLoader
          anchors.fill: parent
          active: box.settingsOpen || settingsSlot.closing

          sourceComponent: SettingsPanel {
            shown: box.settingsOpen || settingsSlot.closing
            page: box.settingsPage
            diagnosticVerdict: root.diagnosticVerdict
            onCloseRequested: box.settingsOpen = false
            onPageRequested: (name) => box.settingsPage = name

            onOpenWallpaperSwitcher: {
              root.closeOverlays()
              box.wallpaperSwitcherOpen = true
            }
            onOpenKeybinds: {
              root.closeOverlays()
              box.keybindViewer = true
            }
            onOpenClipboard: {
              root.closeOverlays()
              box.cliphistOpen = true
            }
            onDiagnosticsRequested: {
              const report = root.doctorReport()
              root.diagnosticVerdict = report.split("\n").pop()
              Notifier.post("Diagnostics", report, "stethoscope", "Ringo", 0)
            }
            onOpenConfigFile: {
              const term = Config.defaultTerminal
              if (!term || term.length === 0) return
              // the overlay holds an exclusive keyboard grab, so it has to go
              // before the editor can take keys
              root.closeOverlays()
              Quickshell.execDetached(["sh", "-c",
                "command -v " + term + " >/dev/null 2>&1 || exit 0; "
                + "ed=\"${EDITOR:-}\"; case \"$ed\" in ''|true|:) ed=nvim ;; esac; "
                + "command -v \"${ed%% *}\" >/dev/null 2>&1 || ed=nvim; "
                + "command -v \"${ed%% *}\" >/dev/null 2>&1 || exit 0; "
                + "exec " + term + " -e $ed \"$HOME/.config/ringo-shell/config.jsonc\""])
            }
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onSettingsOpenChanged() {
            if (box.settingsOpen && settingsLoader.item)
              settingsLoader.item.forceActiveFocus()
          }
        }
      }

      // record menu opens through IPC (Mod+F11)
      OverlaySlot {
        id: recordSlot
        open: box.recordMenuOpen
        openHeight: 70
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter
                 || box.miniDashboard
                 || box.cliphistOpen
                 || box.appLauncher
                 || box.wallpaperSwitcherOpen
                 || box.powerMenuOpen

        Loader {
          id: recordMenuLoader
          anchors.fill: parent
          active: box.recordMenuOpen || recordSlot.closing

          sourceComponent: RecordMenu {
            shown: box.recordMenuOpen || recordSlot.closing
            onCloseRequested: box.recordMenuOpen = false
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onRecordMenuOpenChanged() {
            if (box.recordMenuOpen && recordMenuLoader.item)
              recordMenuLoader.item.forceActiveFocus()
          }
        }
      }

      // app launcher opens through IPC
      OverlaySlot {
        id: appLauncherSlot
        open: box.appLauncher
        openHeight: 386
        widthInset: 24
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter
                 || box.miniDashboard
                 || box.cliphistOpen

        AppLauncher {
          id: appLauncherPanel
          anchors.fill: parent
          shown: box.appLauncher || appLauncherSlot.closing
          initialQuery: box.pendingLauncherQuery
          onCloseRequested: box.appLauncher = false
        }
      }

      // searchable keybind list opens through IPC (Mod+/)
      OverlaySlot {
        id: keybindSlot
        open: box.keybindViewer
        openHeight: box.baseHeight - 40
        widthInset: 24
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter
                 || box.miniDashboard
                 || box.cliphistOpen
                 || box.appLauncher

        Loader {
          id: keybindViewerLoader
          anchors.fill: parent
          active: box.keybindViewer || keybindSlot.closing

          sourceComponent: KeybindViewer {
            shown: box.keybindViewer || keybindSlot.closing
            onCloseRequested: box.keybindViewer = false
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onKeybindViewerChanged() {
            if (box.keybindViewer && keybindViewerLoader.item)
              keybindViewerLoader.item.forceActiveFocus()
          }
        }
      }

      // control center opens on left click
      Item {
        id: controlCenterPanel
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: box.baseWidth - 24
        focus: true
        property bool contentShown: false
        Timer {
          id: controlContentTimer
          interval: 60
          onTriggered: controlCenterPanel.contentShown = true
        }
        Keys.onEscapePressed: (event) => { box.controlCenter = false; event.accepted = true }
        Connections {
          target: box
          function onControlCenterChanged() {
            if (box.controlCenter) {
              controlCenterPanel.forceActiveFocus()
              controlCenterPanel.contentShown = false
              controlContentTimer.restart()
            } else {
              controlContentTimer.stop()
              controlCenterPanel.contentShown = false
            }
          }
        }
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active ? 1 : 0
        visible: opacity > 0
        height: ccColumn.implicitHeight

        Behavior on opacity {
          NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
        }

        Rectangle {
          anchors.fill: parent
          radius: 22
          color: Theme.bgD1
          border.width: 1
          border.color: Theme.pillBorder
        }

        ColumnLayout {
          id: ccColumn
          width: parent.width
          spacing: 6
          opacity: controlCenterPanel.contentShown ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 180; easing.type: Theme.easeOut } }


          MediaPlayer {
            Layout.fillWidth: true
          }


          CcButtons {
            id: ccButtons
            Layout.fillWidth: true
            controlCenterOpen: box.controlCenter
            onSettingsRequested: (page) => { root.closeOverlays(); box.settingsPage = page; box.settingsOpen = true }
          }


          Rectangle {
            Layout.fillWidth: true
            implicitHeight: sliderCol.implicitHeight + 16
            radius: 12
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder

            ColumnLayout {
              id: sliderCol
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              anchors.topMargin: 8
              anchors.bottomMargin: 8
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                  id: volIcon
                  text: volumeModule.icon
                  color: volumeModule.muted ? "#fd2222" : Theme.fg
                  font.family: Theme.nerdFontFamily
                  font.pixelSize: 13
                  Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: box.sliderHeight
                  radius: box.sliderRadius
                  color: Theme.bgD
                  border.width: 1
                  border.color: Theme.cardBorder

                  Rectangle {
                    width: parent.width * (volumeModule.vol / 100)
                    height: parent.height
                    radius: box.sliderRadius
                    color: box.sliderColor
                    Behavior on width {
                      enabled: !volMouse.pressed
                      NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
                    }
                  }

                  MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    anchors.topMargin: -box.sliderHitSlop
                    anchors.bottomMargin: -box.sliderHitSlop
                    onClicked: (mouse) => {
                      volumeModule.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                    }
                    onPositionChanged: (mouse) => {
                      if (pressed)
                        volumeModule.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                    }
                  }
                }

                Text {
                  id: volVal
                  text: volumeModule.muted ? "muted" : volumeModule.vol + "%"
                  color: Theme.fg
                  font.family: Theme.fontFamily
                  font.pixelSize: 10
                  font.weight: 600
                  Layout.minimumWidth: 35
                  horizontalAlignment: Text.AlignRight
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                  id: blIcon
                  text: brightnessModule.icon
                  color: Theme.fg
                  font.family: Theme.nerdFontFamily
                  font.pixelSize: 13
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: box.sliderHeight
                  radius: box.sliderRadius
                  color: Theme.bgD
                  border.width: 1
                  border.color: Theme.cardBorder

                  Rectangle {
                    width: parent.width * brightnessModule.percent
                    height: parent.height
                    radius: box.sliderRadius
                    color: box.sliderColor
                    Behavior on width {
                      enabled: !blMouse.pressed
                      NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
                    }
                  }

                  MouseArea {
                    id: blMouse
                    anchors.fill: parent
                    anchors.topMargin: -box.sliderHitSlop
                    anchors.bottomMargin: -box.sliderHitSlop
                    onClicked: (mouse) => {
                      let pct = Math.max(0.01, Math.min(1.0, mouse.x / width))
                      BrightnessController.setPercent(pct)
                    }
                    onPositionChanged: (mouse) => {
                      if (pressed) {
                        let pct = Math.max(0.01, Math.min(1.0, mouse.x / width))
                        BrightnessController.setPercent(pct)
                      }
                    }
                  }
                }

                Text {
                  id: btVal
                  text: Math.round(brightnessModule.percent * 100) + "%"
                  color: Theme.fg
                  font.family: Theme.fontFamily
                  font.pixelSize: 10
                  font.weight: 600
                  Layout.minimumWidth: 35
                  horizontalAlignment: Text.AlignRight
                }
              }
            }
          }


          TrayModule {
            parentWindow: panelWindow
            Layout.fillWidth: true
            onSettingsRequested: (page) => { root.closeOverlays(); box.settingsPage = page; box.settingsOpen = true }
          }

          Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder
            clip: true
            visible: notificationModule.notifications.length > 0 && box.controlCenter
            readonly property real notifContentH: notifList.contentHeight > 0 ? notifList.contentHeight : (notificationModule.notifications.length * 48)
            implicitHeight: visible ? (headerBar.height + Math.min(notifContentH, notifMaxHeight) + 4) : 0

            Rectangle {
              id: headerBar
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: 24
              color: "transparent"

              Text {
                text: "Notifications (" + notificationModule.notifications.length + ")"
                color: Theme.fg2
                font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    font.letterSpacing: 0.5
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
              }

              Rectangle {
                width: 54
                height: 16
                radius: 8
                color: clearAllHover.containsMouse ? Theme.focusBgL : Theme.bg1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: "Clear all"
                  color: clearAllHover.containsMouse ? Theme.focusFg1 : Theme.fg3
                  font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: clearAllHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: notificationModule.clearAll()
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.cardBorder
              }
            }

            ListView {
              id: notifList
              anchors.top: headerBar.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.topMargin: 2
              anchors.leftMargin: 4
              anchors.rightMargin: 4
              anchors.bottomMargin: 2
              height: Math.min(contentHeight > 0 ? contentHeight : (notificationModule.notifications.length * 48), notifMaxHeight)
              spacing: 4
              model: notificationModule.notificationsReversed
              clip: true
              interactive: contentHeight > height
              flickDeceleration: 3000
              maximumFlickVelocity: 2500
              boundsBehavior: Flickable.StopAtBounds

              cacheBuffer: 200
              reuseItems: true

              ScrollBar.vertical: ScrollBar {
                id: notifScrollBar
                policy: ScrollBar.AlwaysOff
                visible: notifList.contentHeight > notifList.height
                width: 6
                anchors.rightMargin: 4
                z: 20
                contentItem: Rectangle {
                  implicitWidth: 6
                  radius: 3
                  color: notifScrollBar.pressed ? "#888"
                       : scrollHover.hovered ? "#6f6f6f"
                       : "#3a3a3a"
                  Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                  HoverHandler { id: scrollHover }
                }
              }

              delegate: Item {
                readonly property var entry: modelData
                width: ListView.view.width
                height: contentColumn.implicitHeight + 7

                Text {
                  text: String.fromCodePoint(0xf0f3)
                  color: Theme.fg
                  font { family: Theme.nerdFontFamily; pixelSize: 16 }
                  visible: notifIcon.status !== Image.Ready
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.topMargin: 10
                  anchors.leftMargin: 12
                }

                Image {
                  id: notifIcon
                  width: 22
                  height: 22
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  source: {
                    if (modelData.appIcon) {
                      if (modelData.appIcon.startsWith("/")) return "file://" + modelData.appIcon
                      return Quickshell.iconPath(modelData.appIcon, true)
                    }
                    return ""
                  }
                  enabled: true
                  smooth: true
                  sourceSize: Qt.size(64, 64)
                  visible: status === Image.Ready
                  onStatusChanged: if (status === Image.Error) visible = false
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.topMargin: 10
                  anchors.leftMargin: 12
                }

                ColumnLayout {
                  id: contentColumn
                  anchors.fill: parent
                  anchors.leftMargin: 44
                  anchors.rightMargin: 3
                  anchors.bottomMargin: 16
                  spacing: 1

                  Item {
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    visible: !bodyText.visible
                  }

                  RowLayout {
                    Layout.fillWidth: true

                    Text {
                      text: modelData.summary
                      textFormat: Text.PlainText
                      color: Theme.fg
                      font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: modelData.receivedTime ? Qt.formatTime(modelData.receivedTime, "hh:mm") : ""
                      color: Theme.fg5
                      font { family: Theme.fontFamily; pixelSize: 8 }
                      Layout.bottomMargin: 5
                    }

                    Rectangle {
                      Layout.preferredWidth: 22
                      Layout.preferredHeight: 22
                      radius: 99
                      color: dismissHover.containsMouse ? Theme.focusBgL : "transparent"
                      Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                      Text {
                        // nf-fa-times (U+F00D): a private-use glyph, so it needs the
                        // nerd font family or it renders as nothing next to the icon
                        text: "\uf00d"
                        color: dismissHover.containsMouse ? Theme.focusFg1 : Theme.fg5
                        anchors.centerIn: parent
                        font { family: Theme.nerdFontFamily; pixelSize: 11 }
                        Behavior on color { ColorAnimation { duration: Theme.motionBase } }
                      }

                      MouseArea {
                        id: dismissHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationModule.dismiss(modelData._id)
                      }
                    }
                  }

                  Text {
                    id: bodyText
                    text: modelData.body ? modelData.body.replace(
                      /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
                      '<a href="$2">$1</a>'
                    ) : ""
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    visible: text !== ""
                    onLinkActivated: (link) => {
                      Qt.openUrlExternally(link)
                      notificationModule.dismiss(modelData._id)
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 4
                    visible: notificationModule.actionList(modelData.notif).length > 0

                    Repeater {
                      model: notificationModule.actionList(modelData.notif)

                      Rectangle {
                        implicitHeight: 20
                        implicitWidth: actionText.implicitWidth + 12
                        radius: 6
                        color: actionHover.containsMouse ? Theme.chipBgHover : Theme.chipBg
                        border.width: 1
                        border.color: Theme.chipBorder

                        Text {
                          id: actionText
                          anchors.centerIn: parent
                          text: modelData.text
                          color: Theme.fg
                          font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
                        }

                        MouseArea {
                          id: actionHover
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            modelData.invoke()
                            notificationModule.dismiss(entry._id)
                          }
                        }
                      }
                    }
                  }

                  Item {
                    Layout.fillHeight: true
                    Layout.bottomMargin: 6
                    visible: !bodyText.visible
                  }
                }

                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  height: 1
                  color: Theme.cardBorder
                  visible: index < notificationModule.notifications.length - 1
                }
              }
            }
          }
        }
      }

      // mini dashboard opens on right click
      Item {
        id: miniDashboardPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        width: box.baseWidth - 8
        focus: true
        property bool contentShown: false
        Timer {
          id: miniContentTimer
          interval: 60
          onTriggered: miniDashboardPanel.contentShown = true
        }
        Keys.onEscapePressed: (event) => { box.miniDashboard = false; event.accepted = true }
        Binding {
          target: SystemMonitor
          property: "telemetryActive"
          value: box.miniDashboard
        }
        Connections {
          target: box
          function onMiniDashboardChanged() {
            if (box.miniDashboard) {
              miniDashboardPanel.forceActiveFocus()
              miniDashboardPanel.contentShown = false
              miniContentTimer.restart()
            } else {
              miniContentTimer.stop()
              miniDashboardPanel.contentShown = false
            }
          }
        }
        height: box.miniDashboard ? box.baseHeight - 16 : 0
        opacity: box.miniDashboard
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
        }

        Rectangle {
          anchors.fill: parent
          radius: 22
          color: Theme.bgD1
          border.width: 1
          border.color: Theme.pillBorder
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
              box.miniDashboard = !box.miniDashboard
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          anchors.topMargin: 4
          anchors.bottomMargin: 4
          spacing: 8
          opacity: miniDashboardPanel.contentShown ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 180; easing.type: Theme.easeOut } }


          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ClippingRectangle {
              id: avatarClip
              Layout.preferredWidth: 34
              Layout.preferredHeight: 34
              radius: 9
              property string imgPath: Config.displayPicture ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
              color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.cardBg : "transparent"
              border.width: 1
              border.color: Theme.cardBorder

              Image {
                id: avatarImg
                anchors.fill: parent
                source: avatarClip.imgPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                smooth: true
                mipmap: true
                sourceSize: Qt.size(34, 34)
              }
            }

            ColumnLayout {
              spacing: 3
              Layout.alignment: Qt.AlignVCenter

              RowLayout {
                spacing: 6
                Text {
                  text: SystemMonitor.username
                  color: Theme.fg
                  font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                }

                Rectangle {
                  radius: 5
                  color: Theme.chipBg
                  border.width: 1
                  border.color: Theme.chipBorder
                  implicitHeight: 16
                  implicitWidth: hostText.implicitWidth + 8
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    id: hostText
                    anchors.centerIn: parent
                    text: "@" + SystemMonitor.hostname
                    color: Theme.accent
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                  }
                }
              }

              RowLayout {
                spacing: 4
                Text {
                  text: "\uf017"
                  color: Theme.fg5
                  font { family: Theme.nerdFontFamily; pixelSize: 9 }
                }
                Text {
                  text: "up " + SystemMonitor.uptime
                  color: Theme.fg4
                  font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
                }
              }
            }

            Item { Layout.fillWidth: true }

            Battery {
              fontSize: 10
              Layout.alignment: Qt.AlignVCenter
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 64
            spacing: 8

            Rectangle {
              // IP + interface + the two rate rows need ~185px; the gauge card
              // takes whatever is left over.
              Layout.preferredWidth: 240
              Layout.fillHeight: true
              radius: 4
              color: Theme.cardBg
              border.width: 1
              border.color: Theme.cardBorder

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                IpStatus {
                  Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Bandwidth {
                  Layout.alignment: Qt.AlignVCenter
                }
              }
            }

            ResourceGauge {
              Layout.fillWidth: true
              Layout.fillHeight: true
            }
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 4
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 8

              Datetime {
                id: datetimeItem
                dateFg: Theme.fg3
                Layout.alignment: Qt.AlignVCenter
              }

              Item { Layout.fillWidth: true }

              WeatherIndicator {
                id: weatherIndicatorItem
                Layout.alignment: Qt.AlignVCenter
              }
            }
          }
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }

    }

  CalendarBox {
    id: calendarPopup
    datetimeItem: datetimeItem
    anchorY: Config.pillTopMargin + Math.round(box.height * box.dpi) + 5 * Config.dpiScale
  }

  WeatherPopup {
    id: weatherPopup
    anchorY: Config.pillTopMargin + Math.round(box.height * box.dpi) + 5 * Config.dpiScale
  }

  Connections {
    target: datetimeItem
    function onToggleCalendar() {
      calendarPopup.shown = !calendarPopup.shown
      weatherPopup.shown = false
    }
  }

  Connections {
    target: weatherIndicatorItem
    function onToggleWeather() {
      weatherPopup.shown = !weatherPopup.shown
      calendarPopup.shown = false
    }
  }

  NotificationServer {
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    persistenceSupported: true
    onNotification: notif => {
      notif.tracked = true
      notificationModule.enqueue(notif)
    }
  }

  NotificationModule { id: notificationModule; visible: false }

  IdleMonitor {
    timeout: 300
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) BrightnessController.dim()
      else BrightnessController.restore()
    }
  }

  IdleMonitor {
    timeout: 330
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) LockController.lock()
    }
  }

  IdleMonitor {
    timeout: 360
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) {
        NiriController.powerOffMonitors()
      } else {
        NiriController.powerOnMonitors()
        BrightnessController.restore()
      }
    }
  }

  IdleMonitor {
    timeout: 600
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) NiriController.suspend()
    }
  }

  Backdrop {
    id: backdrop
  }

  // explicit reload: a swap that lands mid-watch would otherwise be missed
  Connections {
    target: WallpaperController
    function onBackdropChanged(): void { backdrop.reloadImage() }
  }

  LockScreen {}

}
