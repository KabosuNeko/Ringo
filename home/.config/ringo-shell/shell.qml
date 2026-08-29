//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import IslandBackend
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Notifications

ShellRoot {
  id: root

  Keys.onEscapePressed: {
      box.controlCenter = false
      box.miniDashboard = false
      box.cliphistOpen = false
      box.appLauncher = false
      box.wallpaperSwitcherOpen = false
      box.powerMenuOpen = false
      box.activeOsd = ""
  }

  IpcHandler {
      target: "cliphist"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
      function show(): void { box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
      function hide(): void { box.miniDashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = !box.appLauncher; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = true; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = !box.wallpaperSwitcherOpen; box.powerMenuOpen = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = true; box.powerMenuOpen = false }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
  }

  IpcHandler {
    target: "powerMenu"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = !box.powerMenuOpen }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = true }
    function hide(): void { box.powerMenuOpen = false }
  }

  property string bg: Theme.bg
  property real barSurfaceOpacity: 0.5
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48
  property int buttonSize: 20
  property string buttonBg: Theme.bg6
  property string buttonHoverBg: Theme.focusFg1
  property int buttonHoverSpeed: 120
  property int buttonctlRadius: 6

  property bool notifFullscreenMode: false
  property bool fullscreenActive: false

  // Fullscreen state: initial snapshot + event-driven refresh. A persistent
  // `niri msg event-stream` listener re-queries windows only when something
  // relevant changes, instead of forking `niri msg windows` every second.
  Process {
    id: fullscreenPoll
    running: true
    command: ["niri", "msg", "--json", "windows"]
    stdout: StdioCollector {
      onStreamFinished: parseWindows(text)
    }
  }

  Process {
    id: fullscreenEvents
    running: true
    command: ["niri", "msg", "--json", "event-stream"]
    stdout: SplitParser {
      onRead: data => {
        try {
          var ev = JSON.parse(data)
          if (!ev) return
          // niri event-stream lines are { "<EventName>": {...} }
          for (var key in ev) {
            if (key === "WindowOpened" || key === "WindowClosed"
                || key === "WindowChanged" || key === "FocusChanged") {
              fullscreenPoll.running = false
              fullscreenPoll.running = true
              return
            }
          }
        } catch (e) {
          // ignore keepalive/partial lines
        }
      }
    }
  }

  function parseWindows(text: string): void {
    try {
      var data = JSON.parse(text)
      var found = false
      for (var i = 0; i < data.length; i++) {
        if (data[i].is_focused && data[i].is_fullscreen) {
          found = true
          break
        }
      }
      root.fullscreenActive = found
    } catch (e) {
      console.log("niri windows parse error:", e)
    }
  }

  property int osdInWidth: 120
  property real osdInHeight: 3.7
  property int osdBarRadius: 2
  property int osdSpeed: 60 // how fast bar fill/unfill
  property int osdWidth: 220
  property int osdHeight: 40

  readonly property int notifMaxHeight: 97

  PanelWindow {
    id: panelWindow
    visible: !LockController.locked
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.namespace: "ringo-shell"
    WlrLayershell.keyboardFocus: (box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen || box.powerMenuOpen || box.controlCenter || box.miniDashboard) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Height follows the actual content: pill box + any open popup below it.
    // (Fixed 885px tall windows would cover most of the screen on niri.)
    implicitWidth: Math.max(
      Math.ceil(box.width * box.dpi),
      calendarPopup.shown ? Math.ceil(calendarPopup.width) : 0,
      weatherPopupLoader.item && weatherPopupLoader.item.shown
        ? Math.ceil(weatherPopupLoader.item.width) : 0
    )
    implicitHeight: Math.max(
      box.y + box.height * box.dpi,
      calendarPopup.shown ? calendarPopup.y + calendarPopup.height : 0,
      weatherPopupLoader.item && weatherPopupLoader.item.shown
        ? weatherPopupLoader.item.y + weatherPopupLoader.item.height : 0
    )
    onScreenChanged: { }

    anchors {
      top: true
    }

    // fixed gap of the active window for the top bar
    margins.top: Config.pillTopMargin
    exclusiveZone: Config.pillBottomMargin
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      Region {
        intersection: Intersection.Combine
        x: Math.floor(box.x - box.width * (box.dpi - 1) / 2); y: Math.floor(box.y)
        width: Math.ceil(box.width * box.dpi); height: Math.ceil(box.height * box.dpi)
      }
      Region {
        intersection: Intersection.Combine
        x: Math.floor(calendarPopup.x); y: Math.floor(calendarPopup.y)
        width: calendarPopup.shown ? Math.ceil(calendarPopup.width) : 0
        height: calendarPopup.shown ? Math.ceil(calendarPopup.height) : 0
      }
      Region {
          intersection: Intersection.Combine
          x: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.x) : 0
          y: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.y) : 0
          width: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.width) : 0
          height: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.height) : 0
      }
    }

    // main dynamic pill bar
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: (!fullscreenActive && !notifFullscreenMode && !LockController.locked) ? 1 : 0
      visible: opacity > 0
      clip: true

      property bool appLauncher: false
      property bool hovered: false
      property bool miniDashboard: false
      property bool controlCenter: false
      property bool cliphistOpen: false
      property bool wallpaperSwitcherOpen: false
      property bool powerMenuOpen: false

      property var battery: UPower.displayDevice
      property bool hasBattery: battery.isLaptopBattery && battery.isPresent
      property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
      readonly property string batteryIconColor: box.charging || box.batteryLevel > 30 ? "#4bd25c" : box.batteryLevel <= 15 ? "#e22323" : "#eecc47"
      readonly property int batteryLevel: hasBattery ? Math.round(battery.percentage * 100) : 0
      // battery icon on laptops, plug icon on desktops
      readonly property string batteryIcon: {
        if (!hasBattery)
          return String.fromCodePoint(0xf06a5) + " " // nf-md-power_plug
        const icons = [0xf0083, 0xf007a, 0xf007d, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0082, 0xf0081, 0xf0079]
        const base = String.fromCodePoint(icons[Math.min(Math.floor(batteryLevel / 10), 9)])
        return charging ? base + String.fromCodePoint(0xf140b) : base
      }

      onChargingChanged: {
        if (!box.controlCenter) box.activeOsd = "battery"
        osdHideTimer.interval = Config.osdDuration
        osdHideTimer.restart()
      }

      property string accent: Theme.accent

      // control center UI
      property real ccButtonBorderWidth: 1
      property string ccButtonBorderColor: Theme.borderBg4
      property real ccButtonWidth: 85.3
      property int ccButtonHeight: 35
      property int ccButtonRadius: 10
      property string ccButtonBgOff: Theme.bg1
      property string ccButtonFgOff: Theme.fg3
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: Theme.sliderBg
      // invisible extra clickable area above/below the thin slider bars
      // (proportional to the bar height, so it scales with sliderHeight)
      property int sliderHitSlop: sliderHeight * 2
      property int mprisControlsIconSize: 20

      property string activeOsd: "" // volume, brightness, battery

      Process { id: brightnessSetProc; running: false }

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }
      Timer { id: brightnessThrottle; interval: 80; repeat: false }

      onImplicitHeightChanged: {
          heightAnim.stop()
          heightAnim.to = implicitHeight
          heightAnim.duration = 220
          heightAnim.start()
      }

      readonly property int notifBump: notificationModule.notifications.length > 0
        ? Math.min(notifList.contentHeight + 40, 130) : 0

      // adjust box shape conditionally
      readonly property real dpi: Config.dpiScale

      property bool cliphistPreviewing: false

      // keep Clock truly centered even when systray appears (left/right groups anchored, center independent)
      readonly property real barContentOpacity: !box.cliphistOpen && !notificationModule.active && !box.controlCenter && !box.miniDashboard && box.activeOsd === "" && !box.appLauncher && !box.powerMenuOpen ? 1 : 0
      readonly property real baseWidth: activeOsd === "battery" ? osdWidth
                     : activeOsd === "volume" ? osdWidth
                     : activeOsd === "brightness" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 320
                     : controlCenter ? 390
                     : appLauncher ? 390
                     : wallpaperSwitcherOpen ? 600
                     : powerMenuOpen ? 400
                     : miniDashboard ? 420
                      : (cliphistOpen && cliphistPreviewing) ? 400
                      : cliphistOpen ? 460
                      : (leftGroup.implicitWidth + centerClock.implicitWidth + rightGroup.implicitWidth + 26 * Config.paddingScale) + (12 * Config.paddingScale) + (hovered ? 68 : 56) * Config.paddingScale

      readonly property real baseHeight: activeOsd === "battery" ? osdHeight
                  : activeOsd === "volume" ? osdHeight
                  : activeOsd === "brightness" ? osdHeight
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : controlCenter && mprisModule.hasPlayer
                      ? (240 + notifBump)
                  : controlCenter
                      ? (118 + notifBump)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                   : cliphistOpen ? 270
                   : miniDashboard ? 155
                   : appLauncher ? 410
                   : wallpaperSwitcherOpen ? 308
                   : powerMenuOpen ? 90
                   : (Math.max(leftGroup.implicitHeight, centerClock.implicitHeight, rightGroup.implicitHeight) * Config.pillScale) + 10

      readonly property real baseRadius: notificationModule.active ? 99
        : cliphistOpen && cliphistPreviewing ? 35
        : cliphistOpen ? 28
        : wallpaperSwitcherOpen ? 30
        : powerMenuOpen ? 24
        : controlCenter ? (notificationModule.notifications.length > 0
          ? (mprisModule.hasPlayer ? 27 : 25)
          : (mprisModule.hasPlayer ? 26 : 22))
        : appLauncher ? 30
        : miniDashboard ? 20
        : 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight
      radius: baseRadius
      scale: dpi
      transformOrigin: Item.Top

      Behavior on radius {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }

      color: controlCenter
             ? Qt.rgba(Theme.bgD1.r, Theme.bgD1.g, Theme.bgD1.b, root.barSurfaceOpacity)
             : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.barSurfaceOpacity)

      onMiniDashboardChanged: {
          if (!box.miniDashboard) {
              calendarPopup.shown = false
              if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
          }
      }

      Behavior on implicitWidth { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      NumberAnimation { id: heightAnim; target: box; property: "height"; easing.type: Easing.OutExpo }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: box.hovered = true
        onExited: box.hovered = false

        onClicked: (mouse) => {

          // restrict control center to only accept left click
          if (box.controlCenter) {
            if (mouse.button === Qt.LeftButton)
                box.controlCenter = false
            return
          }

          // same, cliphist accept middle
          if (box.cliphistOpen) {
            if (mouse.button === Qt.MiddleButton) {
              box.cliphistOpen = false
            }
            return
          }

          // mini dashboard accept only right
          if (box.miniDashboard) {
            if (mouse.button === Qt.RightButton) {
              box.miniDashboard = false
            }
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

      // modules in bar - split to keep Clock centered when systray appears
      RowLayout {
        id: leftGroup
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 28
        spacing: 13 * Config.paddingScale
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Battery {}
        Volume {
          id: volumeModule
          onVolumeChanged: {
            if (!box.controlCenter) box.activeOsd = "volume"
            osdHideTimer.interval = Config.osdDuration
            osdHideTimer.restart()
            }
        }
      }
      Clock {
        id: centerClock
        anchors.centerIn: parent
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
      }
      RowLayout {
        id: rightGroup
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 28
        spacing: 13 * Config.paddingScale
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        RowLayout {
          spacing: 4 * Config.paddingScale
          Text {
            text: brightnessModule.icon
            color: Theme.fg
            font { family: Theme.nerdFontFamily; pixelSize: 10 * Config.pillScale }
          }
          Text {
            text: Math.round(brightnessModule.percent * 100) + "%"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
          }
        }
        TrayModule { parentWindow: panelWindow }
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
                && !notifFullscreenMode
                && box.activeOsd === ""
        notif: notificationModule.current
      }

      // cliphist opens on middle click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 26
        height: (box.cliphistOpen ? box.implicitHeight - 26 : 0) + cliphistExtraHeight
        opacity: box.cliphistOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter ? 1 : 0
        visible: opacity > 0

        property real cliphistExtraHeight: 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.cliphistOpen ? 15 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
          }
        }

        Cliphist {
          id: cliphistPanel
          shown: box.cliphistOpen
          anchors.fill: parent
          onCloseRequested: box.cliphistOpen = false
          onPreviewToggled: (active) => box.cliphistPreviewing = active
        }
      }

      // wallpaper switcher opens through IPC
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 28
        height: box.wallpaperSwitcherOpen ? 280 : 0
        opacity: box.wallpaperSwitcherOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter
                 && !box.miniDashboard
                 && !box.cliphistOpen
                 && !box.appLauncher ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.wallpaperSwitcherOpen ? 15 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
          }
        }
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
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 28
        height: box.powerMenuOpen ? 70 : 0
        opacity: box.powerMenuOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter
                 && !box.miniDashboard
                 && !box.cliphistOpen
                 && !box.appLauncher
                 && !box.wallpaperSwitcherOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.powerMenuOpen ? 15 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
          }
        }
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

      // app launcher opens through IPC
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 26
          height: box.appLauncher ? 384 : 0
          opacity: box.appLauncher
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.miniDashboard
                   && !box.cliphistOpen ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.appLauncher ? 15 : 0 }
                  NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
              }
          }

          Loader {
              anchors.fill: parent
              active: box.appLauncher
              asynchronous: true

              sourceComponent: AppLauncher {
                  shown: box.appLauncher
                  onCloseRequested: box.appLauncher = false
              }
          }
      }

      // control center opens on left click
      Item {
        id: controlCenterPanel
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        Keys.onEscapePressed: box.controlCenter = false
        Connections {
          target: box
          function onControlCenterChanged() {
            if (box.controlCenter) controlCenterPanel.forceActiveFocus()
          }
        }
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active ? 1 : 0
        visible: opacity > 0
        height: box.controlCenter && box.activeOsd === "" ? box.implicitHeight - 25 : 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.controlCenter ? 15 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
          }
        }

        // media player
        MediaPlayer {}

        // control center buttons
        CcButtons {
          id: ccButtons
          buttonBorderColor: box.ccButtonBorderColor
          buttonBorderWidth: box.ccButtonBorderWidth
          buttonWidth: box.ccButtonWidth
          buttonHeight: box.ccButtonHeight
          buttonRadius: box.ccButtonRadius
          buttonBgOff: box.ccButtonBgOff
          buttonFgOff: box.ccButtonFgOff
          controlCenterOpen: box.controlCenter
          hasPlayer: mprisModule.hasPlayer
          playerHeight: box.ccButtonHeight
          notificationPopup: notificationModule.active
        } 

        // control center sliders
        Column {
          id: sliderColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: mprisModule.hasPlayer ? box.ccButtonHeight + 137 : 50
          anchors.leftMargin: 15
          anchors.rightMargin: 2
          spacing: 5

          RowLayout {
            width: parent.width
            spacing: 14

            Text {
              id: volIcon
              text: volumeModule.icon
              color: volumeModule.muted ? "#fd2222" : Theme.fg
              font.family: Theme.nerdFontFamily
              font.pixelSize: 13
              Behavior on color { ColorAnimation { duration: 100 } }

              // fade + scale pulse on every text change
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
              height: box.sliderHeight
              radius: box.sliderRadius
              color: Theme.bg5

              Rectangle {
                width: parent.width * (volumeModule.vol / 100)
                height: parent.height
                radius: box.sliderRadius
                color: box.sliderColor
                Behavior on width {
                  SpringAnimation {
                    spring: 15.5
                    damping: 1.8
                    epsilon: 0.40
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                // negative margins extend the clickable area beyond the thin bar
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
              Layout.minimumWidth: 35
              onTextChanged: valPulse.restart()
              SequentialAnimation {
                id: valPulse
                NumberAnimation { target: volVal; property: "scale"; to: 0.9; duration: 60; easing.type: Easing.OutQuad }
                NumberAnimation { target: volVal; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
              }
            }
          }

          RowLayout {
            width: parent.width
            spacing: 14

            Text {
              id: blIcon
              text: brightnessModule.icon
              color: Theme.fg
              font.family: Theme.nerdFontFamily
              font.pixelSize: 13

              // fade+scale pulse on every text change
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
              height: box.sliderHeight
              radius: box.sliderRadius
              color: Theme.bg5

              Rectangle {
                width: parent.width * brightnessModule.percent
                height: parent.height
                radius: box.sliderRadius
                color: box.sliderColor
                Behavior on width {
                  SpringAnimation {
                    spring: 15.5
                    damping: 1.8
                    epsilon: 0.40
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                // negative margins extend the clickable area beyond the thin bar
                anchors.topMargin: -box.sliderHitSlop
                anchors.bottomMargin: -box.sliderHitSlop
                onClicked: (mouse) => {
                  let pct = Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                  brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
                  brightnessSetProc.running = false
                  brightnessSetProc.running = true
                }
                onPositionChanged: (mouse) => {
                  if (pressed && !brightnessThrottle.running) {
                    let pct = Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                    brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
                    brightnessSetProc.running = false
                    brightnessSetProc.running = true
                    brightnessThrottle.start()
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
              Layout.minimumWidth: 35
              onTextChanged: btPulse.restart()
              SequentialAnimation {
                  id: btPulse
                  NumberAnimation { target: btVal; property: "scale"; to: 0.9; duration: 60; easing.type: Easing.OutQuad }
                  NumberAnimation { target: btVal; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
              }
            }
          }
        } 

      // notifications stack popped header
      Rectangle {
        id: headerBar
        anchors.top: notifBox.top
        anchors.topMargin: -20
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 10
        height: 20
        topLeftRadius: 13
        topRightRadius: 13
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: Theme.bg5
        visible: notifBox.visible
        z: 0

        Item {
          anchors.fill: parent

          Text {
            text: "Notifications (" + notificationModule.notifications.length + ")"
            color: Theme.fg2
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
          }

          Rectangle {
            width: 60
            height: 16
            radius: 10
            color: clearAllHover.containsMouse ? Theme.bg : Theme.bg1
            Behavior on color { ColorAnimation { duration: 100 } }
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "Clear all"
              color: Theme.fg3
              font { family: Theme.fontFamily; pixelSize: 8; weight: 300 }
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
        }
      }

      // notifications list stack
      Rectangle {
        id: notifBox
        anchors.top: sliderColumn.bottom
        anchors.topMargin: 32
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 10
        height: Math.min(notifList.contentHeight + 7, notifMaxHeight)
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 13
        bottomRightRadius: 13
        color: Theme.bgD
        visible: notificationModule.notifications.length > 0 && box.controlCenter
        clip: true
        border.width: 1
        border.color: Theme.bg2
        z: 1

        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        ListView {
          id: notifList
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 5
          anchors.leftMargin: 5
          anchors.rightMargin: 5
          height: Math.min(contentHeight, notifMaxHeight)
          spacing: 6
          model: notificationModule.notificationsReversed
          clip: true
          interactive: contentHeight > height
          flickDeceleration: 3000
          maximumFlickVelocity: 2500
          boundsBehavior: Flickable.StopAtBounds

          // cache delegates instead of recreating on scroll
          cacheBuffer: 200
          reuseItems: true

          ScrollBar.vertical: ScrollBar {
            id: notifScrollBar
            policy: ScrollBar.AlwaysOff
            visible: notifList.contentHeight > notifList.height
            width: 10
            anchors.rightMargin: 10
            z: 20
            contentItem: Rectangle {
              implicitWidth: 8
              radius: 10
              color: notifScrollBar.pressed ? "#888"
                   : scrollHover.hovered ? "#6f6f6f"
                   : "#3a3a3a"
              Behavior on color { ColorAnimation { duration: 100 } }
              HoverHandler { id: scrollHover }
            }
          }

          // add/append notifications in the stack
          delegate: Item {
            id: notifDelegate
            width: ListView.view.width
            height: contentColumn.implicitHeight + 7

            // glyph (nerd font) bell icon
            Text {
              id: bellIcon
              text: String.fromCodePoint(0xf0f3)
              color: Theme.fg
              font { family: Theme.nerdFontFamily; pixelSize: 16 }
              visible: notifIcon.status !== Image.Ready
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.topMargin: 10
              anchors.leftMargin: 16
            }

            // custom appicon
            Image {
              id: notifIcon
              width: 22
              height: 22
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              source: {
                // Only show the app icon. Attached images (e.g. screenshots)
                // are hidden: a dark 16:9 image in a 22x22 box renders as a
                // broken-looking black square.
                if (modelData.appIcon) {
                  if (modelData.appIcon.startsWith("/")) return "file://" + modelData.appIcon
                  // iconPath(icon, true) returns "" if the icon is missing
                  // from the theme, so we never see the black/purple
                  // "missing texture" block.
                  return Quickshell.iconPath(modelData.appIcon, true)
                }
                return ""
              }
              enabled: true
              smooth: true
              // cap decode size so big icons don't burn VRAM at thumbnail size
              sourceSize: Qt.size(64, 64)
              visible: status === Image.Ready
              onStatusChanged: if (status === Image.Error) visible = false
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.topMargin: 10
              anchors.leftMargin: 15
            }

            ColumnLayout {
              id: contentColumn
              anchors.fill: parent
              anchors.leftMargin: 50
              anchors.rightMargin: 3
              anchors.bottomMargin: 20
              spacing: 1

              Item {
                Layout.fillHeight: true
                Layout.topMargin: 8
                visible: !bodyText.visible
              }

              // heading / summary
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

                // close button
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

              // description / body
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
              width: parent.width
              height: 1
              color: Theme.bg5
              visible: index < notificationModule.notifications.length - 1
            }
          }
        }
      }
      }

      // mini dashboard opens on right click
      Item {
        id: miniDashboardPanel
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        Keys.onEscapePressed: box.miniDashboard = false
        Connections {
          target: box
          function onMiniDashboardChanged() {
            if (box.miniDashboard) miniDashboardPanel.forceActiveFocus()
          }
        }
        height: box.miniDashboard ? box.implicitHeight - 30 : 0  // don't fight the animation
        opacity: box.miniDashboard
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.miniDashboard ? 1 : 0 }
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
          }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    box.miniDashboard = !box.miniDashboard
            }
        }

        RowLayout {
         // profile picture (display picture)
           ClippingRectangle {
            id: avatarClip
            width: avatarSize
            height: avatarSize
            radius: avatarSize / 2
            property string imgPath: Config.displayPicture ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
            color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.bg5 : "transparent"
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(avatarSize, avatarSize)

            Image {
              id: avatarImg
              anchors.fill: parent
              source: avatarClip.imgPath
              fillMode: Image.PreserveAspectCrop
              asynchronous: false
              smooth: true
              mipmap: true
              sourceSize: Qt.size(avatarSize, avatarSize)
            }
          }

          Process {
            id: whoamiProc
            command: ["sh", "-c", 'whoami']
            running: true
            stdout: StdioCollector {
              onStreamFinished: { whoamiText.text = this.text.trim(); whoamiProc.running = false }
            }
          }

          Process {
            id: hostnameProc
            command: ["sh", "-c", "cat /etc/hostname"]
            running: true
            stdout: StdioCollector {
              onStreamFinished: { hostnameText.text = "(" + this.text.trim() + ")"; hostnameProc.running = false }
            }
          }

          Process {
            id: uptimeProc
            command: ["sh", "-c", 'uptime -p']
            running: true
            stdout: StdioCollector {
              onStreamFinished: uptimeText.text = this.text
            }
          }

          // uptime refresh every 60 sec
          Timer {
            interval: 60000
            running: box.miniDashboard
            repeat: true
            triggeredOnStart: true
            onTriggered: {
              uptimeProc.running = false
              uptimeProc.running = true
            }
          }

          // username + uptime stacked
          ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
              Text {
                id: whoamiText
                color: Theme.fg
                Layout.leftMargin: 10
                font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
              }

              Text {
                id: hostnameText
                color: Theme.fg5
                Layout.topMargin: 2
                font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
              }
            }

            Text {
              id: uptimeText
              color: Theme.fg
              opacity: 0.6
              Layout.leftMargin: 10
              font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
            }
          }
        }

        // show battery in mini dashboard too
        Battery {
          fontSize: 14
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: 8
          anchors.rightMargin: 12
        }

        // internet protocol information
        IpStatus {
          anchors.left: parent.left
          anchors.leftMargin: 5
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 42
        }

        // bandwidth usage status
        Bandwidth {
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 42
        }

        // rectangle where poweroff, sleep etc. buttons placed
        Rectangle {
          color: Theme.bg1
          implicitWidth: 15
          implicitHeight: 30
          radius: 8

          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 95

          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰌾";
                color: lockHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 8
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: lockHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: LockController.lock()
                hoverEnabled: true
              }
            }

            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰤄";
                color: sleepHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 9
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: sleepHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { sleepProc.running = false; sleepProc.running = true }
                hoverEnabled: true
              }
              Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
            }

            Item { Layout.fillWidth: true }

            Datetime { id: datetimeItem; dateFg: Theme.fg4; }

            Item { Layout.fillWidth: true }

            WeatherIndicator { id: weatherIndicatorItem }

            Item { Layout.fillWidth: true }

            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰜉";
                color: rebootHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 9;
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: rebootHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { rebootProc.running = false; rebootProc.running = true }
                hoverEnabled: true
              }
              Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
            }

            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰐥";
                color: shutdownHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 12;
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: shutdownHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { shutdownProc.running = false; shutdownProc.running = true }
                hoverEnabled: true
              }
              Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
            }
          }
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }

    // calendar popup box
    CalendarBox { id: calendarPopup }

    Loader {
        id: weatherPopupLoader
        active: false
        asynchronous: false

        sourceComponent: WeatherPopup {
            onShownChanged: if (!shown) closeTimer.start()
        }

        onLoaded: item.shown = true
        Timer {
            id: closeTimer
            interval: 250
            onTriggered: weatherPopupLoader.active = false
        }
    }

    // open calendar when click on date in mini dashboard
    Connections {
      target: datetimeItem
      function onToggleCalendar() {
        calendarPopup.shown = !calendarPopup.shown
        if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
      }
    }

    // open weather when click on weather in mini dashboard
    Connections {
        target: weatherIndicatorItem
        function onToggleWeather() {
          if (!weatherPopupLoader.active)
            weatherPopupLoader.active = true
          else
            weatherPopupLoader.item.shown = !weatherPopupLoader.item.shown
          calendarPopup.shown = false
        }
    }

    }

  MprisModule { id: mprisModule; visible: false }

  NotificationServer {
    id: notifServer
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

  FullscreenOsd {
    id: fsNotif
    active: notificationModule.active && notifFullscreenMode
    visible: notifFullscreenMode
    cardWidth: 300 * box.dpi
    cardHeight: 52 * box.dpi

    property var displayNotif: null

    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: 12 * box.dpi

      Text {
        text: String.fromCodePoint(0xf0f3)
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 14 * box.dpi }
        visible: cardIcon.status !== Image.Ready
      }

      Image {
        id: cardIcon
        width: 23; height: 23
        fillMode: Image.PreserveAspectCrop
        source: {
          if (fsNotif.displayNotif && fsNotif.displayNotif.image) return fsNotif.displayNotif.image
          if (fsNotif.displayNotif && fsNotif.displayNotif.appIcon) {
            if (fsNotif.displayNotif.appIcon.startsWith("/")) {
              return "file://" + fsNotif.displayNotif.appIcon
            }
            // iconPath(icon, true) returns "" if the icon is missing from the
            // theme, so we never see the black/purple "missing texture" block.
            return Quickshell.iconPath(fsNotif.displayNotif.appIcon, true)
          }
          return ""
        }
        sourceSize: Qt.size(23 * box.dpi, 23 * box.dpi)
        visible: status === Image.Ready
      }

      ColumnLayout {
        spacing: 3 * box.dpi

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.summary : ""
          textFormat: Text.PlainText
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 10 * box.dpi; weight: 700 }
          elide: Text.ElideRight
          Layout.maximumWidth: 200
        }

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.body.replace(
            /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
            '<a href="$2">$1</a>'
          ) : ""
          textFormat: Text.StyledText
          linkColor: Theme.accent
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 9 * box.dpi }
          elide: Text.ElideRight
          visible: text !== ""
          Layout.maximumWidth: 200
        }
      }
    }
  }

  Connections {
    target: notificationModule
    function onActiveChanged() {
        if (notificationModule.active) {
            notifFullscreenMode = fullscreenActive
        } else {
            notifFullscreenMode = false
        }
    }
    function onCurrentChanged() {
      if (notificationModule.current) fsNotif.displayNotif = notificationModule.current
    }
  }

  // --- Idle / power management (replaces swayidle) ---
  IdleMonitor {
    id: dimMonitor
    timeout: 300
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) {
        brightnessDimProc.running = false
        brightnessDimProc.running = true
      } else {
        brightnessRestoreProc.running = false
        brightnessRestoreProc.running = true
      }
    }
  }

  IdleMonitor {
    id: lockMonitor
    timeout: 330
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) LockController.lock()
    }
  }

  IdleMonitor {
    id: offMonitor
    timeout: 360
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) {
        monitorsOffProc.running = false
        monitorsOffProc.running = true
      } else {
        monitorsOnProc.running = false
        monitorsOnProc.running = true
      }
    }
  }

  IdleMonitor {
    id: suspendMonitor
    timeout: 600
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) {
        suspendProc.running = false
        suspendProc.running = true
      }
    }
  }

  Process { id: brightnessDimProc; command: ["bash", "-c", "brightnessctl -s set 10"]; running: false }
  Process { id: brightnessRestoreProc; command: ["bash", "-c", "brightnessctl -r"]; running: false }
  Process { id: monitorsOffProc; command: ["bash", "-c", "niri msg action power-off-monitors"]; running: false }
  Process { id: monitorsOnProc; command: ["bash", "-c", "niri msg action power-on-monitors && brightnessctl -r"]; running: false }
  Process { id: suspendProc; command: ["bash", "-c", "systemctl suspend"]; running: false }

  LockScreen {}

}
