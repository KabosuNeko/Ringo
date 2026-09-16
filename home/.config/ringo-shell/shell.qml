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
import Quickshell.Services.SystemTray

ShellRoot {
  id: root


  IpcHandler {
      target: "cliphist"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
      function show(): void { box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
      function hide(): void { box.miniDashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = !box.appLauncher; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = true; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = false }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = !box.wallpaperSwitcherOpen; box.powerMenuOpen = false; box.recordMenuOpen = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = true; box.powerMenuOpen = false; box.recordMenuOpen = false }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false }
  }

  IpcHandler {
    target: "powerMenu"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = !box.powerMenuOpen; box.recordMenuOpen = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = true; box.recordMenuOpen = false }
    function hide(): void { box.powerMenuOpen = false }
  }

  IpcHandler {
    target: "recordMenu"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = !box.recordMenuOpen }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false; box.powerMenuOpen = false; box.recordMenuOpen = true }
    function hide(): void { box.recordMenuOpen = false }
  }

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barHidden = !root.barHidden }
    function show(): void { root.barHidden = false }
    function hide(): void { root.barHidden = true }
  }

  IpcHandler {
    target: "calendar"
    function toggle(): void { calendarPopup.shown = !calendarPopup.shown; weatherPopup.shown = false }
    function show(): void { calendarPopup.shown = true; weatherPopup.shown = false }
    function hide(): void { calendarPopup.shown = false }
  }

  IpcHandler {
    target: "weather"
    function toggle(): void { weatherPopup.shown = !weatherPopup.shown; calendarPopup.shown = false }
    function show(): void { weatherPopup.shown = true; calendarPopup.shown = false }
    function hide(): void { weatherPopup.shown = false }
  }

  property string bg: Theme.bg
  property real barSurfaceOpacity: 0.5
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48


  property bool notifFullscreenMode: false
  readonly property bool fullscreenActive: NiriController.fullscreenActive
  property bool barHidden: false

  Component.onCompleted: {
    WeatherController.weatherLocation = Config.weatherLocation
    WeatherController.weatherUnits = Config.weatherUnits
    WeatherController.refreshInterval = Config.weatherRefreshInterval
    WeatherController.refresh()
  }

  Connections {
    target: Config
    function onWeatherLocationChanged() { WeatherController.weatherLocation = Config.weatherLocation; WeatherController.refresh() }
    function onWeatherUnitsChanged() { WeatherController.weatherUnits = Config.weatherUnits; WeatherController.refresh() }
    function onWeatherRefreshIntervalChanged() { WeatherController.refreshInterval = Config.weatherRefreshInterval }
  }


  readonly property int notifMaxHeight: 97

  PanelWindow {
    id: panelWindow
    visible: !LockController.locked && !root.barHidden
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.namespace: "ringo-shell"
    WlrLayershell.keyboardFocus: (box.controlCenter || box.miniDashboard || box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen || box.powerMenuOpen || box.recordMenuOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Height follows the actual content: pill box capsule.
    implicitWidth: Math.ceil(box.width * box.dpi)
    implicitHeight: Math.ceil(box.y + box.height * box.dpi)
    onScreenChanged: { }

    anchors {
      top: true
    }

    // fixed gap of the active window for the top bar
    margins.top: Config.pillTopMargin
    exclusiveZone: root.barHidden ? 0 : Config.pillBottomMargin
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      x: Math.floor(box.x - box.width * (box.dpi - 1) / 2)
      y: Math.floor(box.y)
      width: Math.ceil(box.width * box.dpi)
      height: Math.ceil(box.height * box.dpi)
    }

    // main dynamic pill bar
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: (!fullscreenActive && !notifFullscreenMode && !LockController.locked) ? 1 : 0
      visible: opacity > 0
      clip: true
      focus: true

      Keys.onEscapePressed: (event) => {
          box.controlCenter = false
          box.miniDashboard = false
          box.cliphistOpen = false
          box.appLauncher = false
          box.wallpaperSwitcherOpen = false
          box.powerMenuOpen = false
          box.recordMenuOpen = false
          box.activeOsd = ""
          event.accepted = true
      }

      property bool appLauncher: false
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

      property string accent: Theme.accent


      property real ccButtonBorderWidth: 1
      property string ccButtonBorderColor: Theme.cardBorder
      property real ccButtonWidth: 85.3
      property int ccButtonHeight: 35
      property int ccButtonRadius: 11
      property color ccButtonBgOff: Theme.cardBg
      property color ccButtonFgOff: Theme.fg3
      property int sliderHeight: 6
      property int sliderRadius: 3
      property string sliderColor: Theme.accent
      // invisible extra clickable area above/below the thin slider bars
      // (proportional to the bar height, so it scales with sliderHeight)
      property int sliderHitSlop: 12
      property int mprisControlsIconSize: 20

      property string activeOsd: "" // volume, brightness, battery

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }

      onImplicitHeightChanged: {
          heightAnim.stop()
          heightAnim.to = implicitHeight
          heightAnim.duration = 220
          heightAnim.start()
      }



      // adjust box shape conditionally
      readonly property real dpi: Config.dpiScale

      property bool cliphistPreviewing: false

      readonly property real barContentOpacity: !box.cliphistOpen && !notificationModule.active && !box.controlCenter && !box.miniDashboard && box.activeOsd === "" && !box.appLauncher && !box.powerMenuOpen && !box.recordMenuOpen ? 1 : 0

      readonly property real baseWidth: activeOsd !== "" ? 220
                     : (notificationModule.active && !notifFullscreenMode) ? 320
                     : controlCenter ? 410
                     : appLauncher ? 420
                     : wallpaperSwitcherOpen ? 600
                     : powerMenuOpen ? 400
                     : recordMenuOpen ? 360
                     : miniDashboard ? 410
                      : (cliphistOpen && cliphistPreviewing) ? 400
                      : cliphistOpen ? 460
                        : leftWing.implicitWidth + centerClock.implicitWidth + rightWing.implicitWidth + (hovered ? 68 : 58) * Config.paddingScale

      readonly property real baseHeight: activeOsd !== "" ? 40
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : controlCenter
                      ? (ccColumn.implicitHeight + 24)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                   : cliphistOpen ? 270
                   : miniDashboard ? 160
                   : appLauncher ? 410
                    : wallpaperSwitcherOpen ? 308
                    : powerMenuOpen ? 90
                    : recordMenuOpen ? 90
                    : (Math.max(batMod.implicitHeight, volumeModule.implicitHeight, centerClock.implicitHeight, barBrightnessRow.implicitHeight, barWeatherIndicator.implicitHeight) * Config.pillScale) + 10

      readonly property real baseRadius: 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight
      radius: baseRadius
      scale: dpi
      transformOrigin: Item.Top

      border.width: 1
      border.color: Theme.pillBorder

      Behavior on radius {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
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

      Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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


      Item {
        id: centerGroup
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -5 * Config.paddingScale
        anchors.verticalCenter: parent.verticalCenter
        width: centerClock.implicitWidth
        height: centerClock.implicitHeight
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        Clock {
          id: centerClock
          anchors.centerIn: parent
        }

        WheelHandler {
          orientation: Qt.Vertical
          onWheel: (event) => {
            if (event.angleDelta.y > 0) {
              NiriController.action("FocusColumnLeft")
            } else if (event.angleDelta.y < 0) {
              NiriController.action("FocusColumnRight")
            }
          }
        }
      }


      RowLayout {
        id: leftWing
        anchors.right: centerGroup.left
        anchors.rightMargin: (box.hovered ? 16 : 13) * Config.paddingScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: (box.hovered ? 14 : 11) * Config.paddingScale
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

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


      RowLayout {
        id: rightWing
        anchors.left: centerGroup.right
        anchors.leftMargin: (box.hovered ? 15 : 12) * Config.paddingScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: (box.hovered ? 13 : 10) * Config.paddingScale
        opacity: box.barContentOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        RowLayout {
          id: barBrightnessRow
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

          WheelHandler {
            orientation: Qt.Vertical
            onWheel: (event) => {
              const step = 0.05
              const delta = event.angleDelta.y > 0 ? step : -step
              BrightnessController.setPercent(Math.max(0.01, Math.min(1.0, BrightnessController.percent + delta)))
            }
          }
        }

        WeatherIndicator {
          id: barWeatherIndicator
          weatherFg: Theme.fg
          clickable: false
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

      // record menu opens through IPC (Mod+F11) — quickshell picker replaces rofi
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 28
        height: box.recordMenuOpen ? 70 : 0
        opacity: box.recordMenuOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter
                 && !box.miniDashboard
                 && !box.cliphistOpen
                 && !box.appLauncher
                 && !box.wallpaperSwitcherOpen
                 && !box.powerMenuOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.recordMenuOpen ? 15 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
          }
        }
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
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 24
          height: box.appLauncher ? 386 : 0
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
          SequentialAnimation {
            PauseAnimation { duration: box.controlCenter ? 15 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
          }
        }

        ColumnLayout {
          id: ccColumn
          width: parent.width
          spacing: 6


          MediaPlayer {
            id: ccMediaPlayer
            Layout.fillWidth: true
          }


          CcButtons {
            id: ccButtons
            Layout.fillWidth: true
            controlCenterOpen: box.controlCenter
            hasPlayer: MprisController.hasPlayer
          }


          Rectangle {
            id: sliderCard
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
                      SpringAnimation {
                        spring: 15.5
                        damping: 1.8
                        epsilon: 0.40
                      }
                    }
                  }

                  MouseArea {
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
                      SpringAnimation {
                        spring: 15.5
                        damping: 1.8
                        epsilon: 0.40
                      }
                    }
                  }

                  MouseArea {
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
            id: ccTrayModule
            parentWindow: panelWindow
            Layout.fillWidth: true
          }

          // 5. Bento Notifications Pod
          Rectangle {
            id: notifCard
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
                  anchors.leftMargin: 12
                }

                // custom appicon
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
                  id: whoamiText
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
                  id: uptimeText
                  text: "up " + SystemMonitor.uptime
                  color: Theme.fg4
                  font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Battery Indicator
            Battery {
              fontSize: 10
              Layout.alignment: Qt.AlignVCenter
            }
          }

          // 2. Dual Bento Telemetry Pods (Network Radar & Resource Gauge)
          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            spacing: 8

            // Left Pod: Network Radar
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

            // Right Pod: Resource Gauge (CPU & RAM)
            ResourceGauge {
              Layout.fillWidth: true
              Layout.fillHeight: true
            }
          }

          // 3. Cockpit Footer: Datetime & Weather Card
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

  // calendar popup window
  CalendarBox {
    id: calendarPopup
    datetimeItem: datetimeItem
    anchorY: Config.pillTopMargin + Math.round(box.height * box.dpi) + 5 * Config.dpiScale
  }

  // weather popup window
  WeatherPopup {
    id: weatherPopup
    anchorY: Config.pillTopMargin + Math.round(box.height * box.dpi) + 5 * Config.dpiScale
  }

  // open calendar when click on date in mini dashboard
  Connections {
    target: datetimeItem
    function onToggleCalendar() {
      calendarPopup.shown = !calendarPopup.shown
      weatherPopup.shown = false
    }
  }

  // open weather when click on weather in mini dashboard
  Connections {
    target: weatherIndicatorItem
    function onToggleWeather() {
      weatherPopup.shown = !weatherPopup.shown
      calendarPopup.shown = false
    }
  }

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
        Layout.preferredWidth: 23; Layout.preferredHeight: 23
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
      if (isIdle) BrightnessController.dim()
      else BrightnessController.restore()
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
        NiriController.powerOffMonitors()
      } else {
        NiriController.powerOnMonitors()
        BrightnessController.restore()
      }
    }
  }

  IdleMonitor {
    id: suspendMonitor
    timeout: 600
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) NiriController.suspend()
    }
  }

  LockScreen {}

}
