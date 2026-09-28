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
    function status(): string {
      const where = `${NightLightController.locationExplicit ? "pinned" : "auto"} `
        + `${NightLightController.latitude.toFixed(2)},${NightLightController.longitude.toFixed(2)}`
      return NightLightController.active
        ? `${NightLightController.temperature}K · ${where}`
        : (NightLightController.error !== "" ? "error: " + NightLightController.error : "off")
    }
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
    target: "recordMenu"
    function toggle(): void { const next = !box.recordMenuOpen; root.closeOverlays(); box.recordMenuOpen = next }
    function open(): void { root.closeOverlays(); box.recordMenuOpen = true }
    function hide(): void { box.recordMenuOpen = false }
  }

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barHidden = !root.barHidden }
    function open(): void { root.barHidden = false }
    function hide(): void { root.barHidden = true }
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
    function unlock(): void { LockController.unlock() }
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
    { name: "fcitx5",            needed: false, why: "input method" },
    { name: "canberra-gtk-play", needed: false, why: "sound events" },
    { name: "mpv",               needed: false, why: "alarm sounds" }
  ]

  property bool barHidden: false

  Component.onCompleted: {
    WeatherController.weatherLocation = Config.weatherLocation
    WeatherController.weatherUnits = Config.weatherUnits
    WeatherController.refreshInterval = Config.weatherRefreshInterval
    WeatherController.refresh()
    NightLightController.lowTemperature = Config.nightLightLowTemperature
    NightLightController.highTemperature = Config.nightLightHighTemperature
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
           + " · " + nl.lowTemperature + "K night / " + nl.highTemperature + "K day")
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
    visible: !LockController.locked && !root.barHidden
    readonly property bool overlayActive: box.controlCenter || box.miniDashboard || box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen || box.powerMenuOpen || box.recordMenuOpen || box.keybindViewer
    readonly property bool popupsOpen: typeof ccButtons !== "undefined" && (ccButtons.wifiPanelOpened || ccButtons.btPanelOpened)
    readonly property bool fullKeyboardOverlay: box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen || box.powerMenuOpen || box.recordMenuOpen || box.keybindViewer
    WlrLayershell.layer: overlayActive ? WlrLayershell.Overlay : WlrLayershell.Top
    WlrLayershell.namespace: "ringo-shell"
    WlrLayershell.keyboardFocus: popupsOpen
                                 ? WlrKeyboardFocus.None
                                 : (fullKeyboardOverlay
                                    ? WlrKeyboardFocus.Exclusive
                                    : (box.controlCenter || box.miniDashboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None))
    implicitWidth: Math.ceil(box.width * box.dpi)
    implicitHeight: Math.ceil((box.y + box.height) * box.dpi)

    anchors {
      top: true
    }

    margins.top: Config.pillTopMargin
    exclusiveZone: root.barHidden ? 0 : Config.pillBottomMargin
    color: "transparent"

    mask: Region {
      x: Math.floor(box.x - box.width * (box.dpi - 1) / 2)
      y: Math.floor(box.y)
      width: Math.ceil(box.width * box.dpi)
      height: Math.ceil(box.height * box.dpi)
    }

    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: !LockController.locked ? 1 : 0
      visible: opacity > 0
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

      readonly property bool hasBattery: SystemMonitor.hasBattery
      readonly property bool charging: SystemMonitor.charging
      readonly property string batteryIconColor: SystemMonitor.batteryIconColor
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

      readonly property real barContentOpacity: !box.cliphistOpen && !notificationModule.active && !box.controlCenter && !box.miniDashboard && box.activeOsd === "" && !box.appLauncher && !box.powerMenuOpen && !box.recordMenuOpen && !box.keybindViewer ? 1 : 0

      readonly property real baseWidth: activeOsd !== "" ? 220
                     : notificationModule.active ? 320
                     : controlCenter ? 410
                     : appLauncher ? 420
                     : keybindViewer ? 560
                     : wallpaperSwitcherOpen ? 600
                     : powerMenuOpen ? 400
                     : recordMenuOpen ? 360
                     : miniDashboard ? 410
                      : (cliphistOpen && cliphistPreviewing) ? 400
                      : cliphistOpen ? 460
                        : barRow.implicitWidth + (hovered ? 68 : 58) * Config.paddingScale

      readonly property real baseHeight: activeOsd !== "" ? 40
                  : notificationModule.active ? 52
                  : controlCenter
                      ? (ccColumn.implicitHeight + 24)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                   : cliphistOpen ? 270
                   : miniDashboard ? 160
                   : appLauncher ? 410
                    : keybindViewer ? 400
                    : wallpaperSwitcherOpen ? 308
                    : powerMenuOpen ? 90
                    : recordMenuOpen ? 90
                    : (Math.max(barRow.implicitHeight, centerClock.implicitHeight) * Config.pillScale) + 10

      readonly property real baseRadius: 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight
      radius: baseRadius
      scale: dpi
      transformOrigin: Item.Top

      border.width: 1
      border.color: Theme.pillBorder

      Behavior on radius {
          NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
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

      Behavior on implicitHeight { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
      Behavior on implicitWidth { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }

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
        Behavior on opacity { NumberAnimation { duration: 100 } }

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
              Behavior on color { ColorAnimation { duration: 120 } }
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
              // an idle animation repaints the scene at monitor rate, so it only runs while recording
              running: Recorder.active
              loops: Animation.Infinite
              NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
              NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
            }
          }
        }

        RowLayout {
          visible: FocusTimer.running
          spacing: 4 * Config.paddingScale
          Layout.alignment: Qt.AlignVCenter

          Text {
            text: FocusTimer.mode === "work" ? "\uf252" : "\uf0f4"
            color: Theme.accent
            font { family: Theme.nerdFontFamily; pixelSize: 10 * Config.pillScale }
          }
          Text {
            text: FocusTimer.formattedTime
            color: Theme.accent
            font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 600 }
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

      OsdBar {
          active: box.activeOsd === "volume"
          icon: volumeModule.icon
          iconColor: volumeModule.muted ? volumeModule.mutedFg : Theme.fg
          percent: volumeModule.vol / 100
          muted: volumeModule.muted
          barWidth: volumeModule.mutedFg ? 90 : 110
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
        active: notificationModule.active
                && box.activeOsd === ""
        notif: notificationModule.current
      }

      // cliphist opens on middle click
      OverlaySlot {
        open: box.cliphistOpen
        openHeight: box.implicitHeight - 26
        widthInset: 26
        blocked: notificationModule.active
                 || box.activeOsd !== ""
                 || box.controlCenter

        Cliphist {
          shown: box.cliphistOpen
          anchors.fill: parent
          onCloseRequested: box.cliphistOpen = false
          onPreviewToggled: (active) => box.cliphistPreviewing = active
        }
      }

      // wallpaper switcher opens through IPC
      OverlaySlot {
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
          active: box.wallpaperSwitcherOpen

          sourceComponent: WallpaperSwitcher {
            shown: box.wallpaperSwitcherOpen
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
          active: box.powerMenuOpen

          sourceComponent: PowerMenu {
            shown: box.powerMenuOpen
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

      // record menu opens through IPC (Mod+F11)
      OverlaySlot {
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
          active: box.recordMenuOpen

          sourceComponent: RecordMenu {
            shown: box.recordMenuOpen
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
          shown: box.appLauncher
          initialQuery: box.pendingLauncherQuery
          onCloseRequested: box.appLauncher = false
        }
      }

      // searchable keybind list opens through IPC (Mod+/)
      OverlaySlot {
        open: box.keybindViewer
        openHeight: box.implicitHeight - 40
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
          active: box.keybindViewer

          sourceComponent: KeybindViewer {
            shown: box.keybindViewer
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
        width: box.implicitWidth - 24
        focus: true
        Keys.onEscapePressed: (event) => { box.controlCenter = false; event.accepted = true }
        Connections {
          target: box
          function onControlCenterChanged() {
            if (box.controlCenter) controlCenterPanel.forceActiveFocus()
          }
        }
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active ? 1 : 0
        visible: opacity > 0
        height: ccColumn.implicitHeight

        Behavior on opacity {
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
          id: ccColumn
          width: parent.width
          spacing: 6


          MediaPlayer {
            Layout.fillWidth: true
          }


          CcButtons {
            id: ccButtons
            Layout.fillWidth: true
            controlCenterOpen: box.controlCenter
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
                  Behavior on color { ColorAnimation { duration: 100 } }

                  onTextChanged: volPulse.restart()
                  scale: 1.0
                  SequentialAnimation {
                      id: volPulse
                      NumberAnimation { target: volIcon; property: "scale"; to: 1.15; duration: 60 }
                      NumberAnimation { target: volIcon; property: "scale"; to: 1.0; duration: 100 }
                  }
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
                      NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
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
                  onTextChanged: valPulse.restart()
                  SequentialAnimation {
                    id: valPulse
                    NumberAnimation { target: volVal; property: "scale"; to: 0.9; duration: 60; easing.type: Easing.OutQuad }
                    NumberAnimation { target: volVal; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
                  }
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

                  onTextChanged: blPulse.restart()
                  scale: 1.0
                  SequentialAnimation {
                      id: blPulse
                      NumberAnimation { target: blIcon; property: "scale"; to: 1.15; duration: 60 }
                      NumberAnimation { target: blIcon; property: "scale"; to: 1.0; duration: 100 }
                  }
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
                      NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
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
                  onTextChanged: btPulse.restart()
                  SequentialAnimation {
                      id: btPulse
                      NumberAnimation { target: btVal; property: "scale"; to: 0.9; duration: 60; easing.type: Easing.OutQuad }
                      NumberAnimation { target: btVal; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
                  }
                }
              }
            }
          }


          TrayModule {
            parentWindow: panelWindow
            Layout.fillWidth: true
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
                font.capitalization: Font.AllUppercase
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
                Behavior on color { ColorAnimation { duration: 100 } }
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
                  Behavior on color { ColorAnimation { duration: 100 } }
                  HoverHandler { id: scrollHover }
                }
              }

              delegate: Item {
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
                      Behavior on color { ColorAnimation { duration: 100 } }

                      Text {
                        text: ""
                        color: dismissHover.containsMouse ? Theme.focusFg1 : Theme.fg7
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 150 } }
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
        anchors.centerIn: parent
        width: box.implicitWidth - 28
        focus: true
        Keys.onEscapePressed: (event) => { box.miniDashboard = false; event.accepted = true }
        Binding {
          target: SystemMonitor
          property: "telemetryActive"
          value: box.miniDashboard
        }
        Connections {
          target: box
          function onMiniDashboardChanged() {
            if (box.miniDashboard) miniDashboardPanel.forceActiveFocus()
          }
        }
        height: box.miniDashboard ? box.implicitHeight - 24 : 0
        opacity: box.miniDashboard
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
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
          spacing: 8


          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ClippingRectangle {
              id: avatarClip
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 9
              property string imgPath: Config.displayPicture ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
              color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.cardBg : "transparent"
              border.width: 1
              border.color: Theme.cardBorder
              layer.enabled: true
              layer.smooth: true
              layer.mipmap: true
              layer.textureSize: Qt.size(38, 38)

              Image {
                id: avatarImg
                anchors.fill: parent
                source: avatarClip.imgPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                smooth: true
                mipmap: true
                sourceSize: Qt.size(38, 38)
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
            Layout.preferredHeight: 52
            spacing: 8

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 10
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
            radius: 8
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

  Connections {
    target: FocusTimer
    function onRunningChanged() {
      if (FocusTimer.autoDnd) {
        if (FocusTimer.running && FocusTimer.mode === "work") {
          FocusTimer.dndWasEnabledBeforeFocus = notificationModule.dndEnabled
          notificationModule.dndEnabled = true
        } else if (!FocusTimer.running) {
          if (!FocusTimer.dndWasEnabledBeforeFocus) {
            notificationModule.dndEnabled = false
          }
        }
      }
    }
  }

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
