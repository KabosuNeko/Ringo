import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import IslandBackend

// dwm-titus style settings list: sectioned rows with switches and action rows,
// plus wifi / bluetooth / audio / default-apps sub-pages. Hosted by shell.qml's
// OverlaySlot.
Rectangle {
  id: panel

  property bool shown: false
  property string diagnosticVerdict: ""
  property string page: "main"

  signal closeRequested
  signal pageRequested(string name)

  signal openWallpaperSwitcher
  signal openKeybinds
  signal openClipboard
  signal diagnosticsRequested
  signal openConfigFile

  anchors.fill: parent
  color: Theme.bgD1
  radius: 22
  visible: opacity > 0
  opacity: shown ? 1 : 0
  focus: true

  // The panel owns its whole surface. Declared first so it sits under every
  // interactive child; without it a left-click on a section header, a margin or
  // the 2 px gap between two rows falls through to box's MouseArea in shell.qml,
  // which closes the overlay.
  MouseArea { anchors.fill: parent }

  onVisibleChanged: if (visible) panel.refreshNetwork()

  Timer {
    interval: 10000
    repeat: true
    running: panel.visible
    onTriggered: panel.refreshNetwork()
  }

  // password entry for a secured, unsaved wifi network
  property bool passwordVisible: false
  property string passwordSsid: ""
  // the ssid of the attempt in flight, so success can dismiss the overlay
  property string pendingSsid: ""
  property bool showPassword: false

  // why the pairing overlay refused the submitted secret
  property string pairingError: ""

  // rows above the list on a sub-page: back, plus the radio and scan rows on the
  // two network pages
  readonly property int subStaticRows: 3
  readonly property int listHeaderRows: (page === "wifi" || page === "bluetooth")
                                       ? subStaticRows : 1

  property int selectedIndex: firstPageRow()

  // Identity of the selected list row (wifi SSID / device address / node name /
  // mime type). The models reorder and shrink under the cursor — a rescan
  // re-sorts by signal, a forget shifts the rows up, turning the radio off
  // empties the list — so the row is tracked by name and selectedIndex is only
  // ever derived from it.
  property string selectedKey: ""

  readonly property int subRowCount: page === "nightlight" ? 5 : listHeaderRows + listCount()

  // Audio devices. Pipewire objects are untracked unless asked, so every node is
  // tracked to keep descriptions and volumes live.
  readonly property var trackedNodes: Pipewire.nodes.values
  readonly property var outputNodes: trackedNodes.filter(n => panel.isAudioNode(n) && n.isSink)
  readonly property var inputNodes: trackedNodes.filter(n => panel.isAudioNode(n) && !n.isSink)
  readonly property var streamNodes: trackedNodes.filter(n => panel.isStreamNode(n))
  property string audioError: ""

  // Wired / VPN state from nmcli. Wi-Fi and Bluetooth have their own controllers;
  // this only fills the two rows the shell otherwise cannot see.
  property var ethernetDevices: []
  property var vpnConnections: []
  property int vpnIndex: 0
  property bool networkBusy: false
  property string networkError: ""

  function refreshNetwork(): void {
    if (panel.networkBusy) return
    panel.networkBusy = true
    panel.networkError = ""
    networkDevices.running = true
  }

  function parseNetworkDevices(text): void {
    const rows = []
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line.length === 0) continue
      const parts = line.split(":")
      if (parts.length < 3 || parts[1] !== "ethernet") continue
      rows.push({
        device: parts[0],
        state: parts[2],
        connection: parts.length > 3 ? parts[3] : ""
      })
    }
    panel.ethernetDevices = rows
  }

  function parseNetworkConnections(text): void {
    const rows = []
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line.length === 0) continue
      const parts = line.split(":")
      if (parts.length < 2) continue
      if (parts[1] !== "vpn" && parts[1] !== "wireguard") continue
      rows.push({
        name: parts[0],
        type: parts[1],
        active: parts.length > 2 && parts[2] !== ""
      })
    }
    panel.vpnConnections = rows
    if (panel.vpnIndex >= rows.length) panel.vpnIndex = 0
  }

  function ethernetActive(): bool {
    for (let i = 0; i < panel.ethernetDevices.length; i++)
      if (panel.ethernetDevices[i].state === "connected") return true
    return false
  }

  function ethernetLabel(): string {
    if (panel.ethernetDevices.length === 0)
      return panel.networkError.length > 0 ? "Unavailable" : "Not present"
    for (let i = 0; i < panel.ethernetDevices.length; i++) {
      const dev = panel.ethernetDevices[i]
      if (dev.state === "connected")
        return dev.connection.length > 0 ? dev.connection : "Connected"
    }
    const first = panel.ethernetDevices[0]
    return first.state === "unavailable" ? "Unavailable" : "Disconnected"
  }

  function toggleEthernet(): void {
    const dev = panel.ethernetDevices[0]
    if (!dev) return
    panel.runNetworkAction([
      "nmcli", "device",
      panel.ethernetActive() ? "disconnect" : "connect",
      dev.device
    ])
  }

  function activeVpn(): var {
    for (let i = 0; i < panel.vpnConnections.length; i++)
      if (panel.vpnConnections[i].active) return panel.vpnConnections[i]
    return null
  }

  function vpnLabel(): string {
    if (panel.networkError.length > 0) return "Error"
    const active = panel.activeVpn()
    if (active) return active.name
    if (panel.vpnConnections.length === 0) return "None"
    const vpn = panel.vpnConnections[panel.vpnIndex]
    return vpn ? vpn.name + " · off" : "Off"
  }

  function toggleVpn(): void {
    const active = panel.activeVpn()
    if (active) {
      panel.runNetworkAction(["nmcli", "connection", "down", active.name])
      return
    }
    const vpn = panel.vpnConnections[panel.vpnIndex]
    if (vpn) panel.runNetworkAction(["nmcli", "connection", "up", vpn.name])
  }

  function cycleVpn(): void {
    if (panel.vpnConnections.length < 2 || panel.activeVpn() !== null) return
    panel.vpnIndex = (panel.vpnIndex + 1) % panel.vpnConnections.length
  }

  readonly property var lightSliders: [
    { key: "low", label: "Night colour", from: 2500, to: 5000, step: 100, unit: "K" },
    { key: "high", label: "Day colour", from: 5000, to: 7000, step: 100, unit: "K" },
    { key: "gamma", label: "Intensity", from: 0.8, to: 1.2, step: 0.05, unit: "" }
  ]

  function lightSliderValue(key: string): real {
    if (key === "low") return Config.nightLightLowTemperature
    if (key === "high") return Config.nightLightHighTemperature
    return Config.nightLightGamma
  }

  function setLightSliderValue(key: string, value: real): void {
    let spec = null
    for (let i = 0; i < panel.lightSliders.length; i++)
      if (panel.lightSliders[i].key === key) spec = panel.lightSliders[i]
    if (!spec) return
    let next = Math.max(spec.from, Math.min(spec.to, value))
    next = key === "gamma" ? Math.round(next * 20) / 20
                            : Math.round(next / spec.step) * spec.step
    if (key === "low")
      Config.setNightLight(next, Config.nightLightHighTemperature, Config.nightLightGamma)
    else if (key === "high")
      Config.setNightLight(Config.nightLightLowTemperature, next, Config.nightLightGamma)
    else
      Config.setNightLight(Config.nightLightLowTemperature, Config.nightLightHighTemperature, next)
  }

  function adjustLightSlider(key: string, direction: int): void {
    const step = key === "gamma" ? 0.05 : 100
    panel.setLightSliderValue(key, panel.lightSliderValue(key) + direction * step)
  }

  readonly property var notificationDisplayPresets: [2000, 3000, 5000, 8000, 10000]
  readonly property var notificationHistoryPresets: [10, 20, 30, 50]
  readonly property var notificationOsdPresets: [500, 800, 1200, 1600]
  readonly property var idlePresets: ({
    dim: [60, 120, 300, 600, 900, 1800],
    lock: [120, 300, 330, 600, 900, 1800, 3600],
    off: [180, 360, 600, 900, 1800, 3600],
    suspend: [0, 300, 600, 900, 1800, 3600, 7200]
  })

  function nextPreset(values, current): var {
    const index = values.indexOf(current)
    if (index >= 0) return values[(index + 1) % values.length]
    // Cascading idle limits can produce 630s, 690s, ... that are not presets.
    // Move to the next larger slot instead of wrapping down to the first one.
    for (let i = 0; i < values.length; i++)
      if (values[i] > current) return values[i]
    return values[0]
  }

  function formatIdle(seconds: int): string {
    if (seconds <= 0) return "Never"
    return seconds % 60 === 0 ? (seconds / 60) + "m"
                              : (seconds / 60).toFixed(1) + "m"
  }

  function cycleNotificationDisplay(): void {
    Config.setNotificationPolicy(
      panel.nextPreset(panel.notificationDisplayPresets, Config.notificationDisplayTime),
      Config.maxNotificationsInStack, Config.avoidDuplicateNotifications, Config.osdDuration)
  }

  function cycleNotificationHistory(): void {
    Config.setNotificationPolicy(
      Config.notificationDisplayTime,
      panel.nextPreset(panel.notificationHistoryPresets, Config.maxNotificationsInStack),
      Config.avoidDuplicateNotifications, Config.osdDuration)
  }

  function cycleNotificationOsd(): void {
    Config.setNotificationPolicy(
      Config.notificationDisplayTime, Config.maxNotificationsInStack,
      Config.avoidDuplicateNotifications,
      panel.nextPreset(panel.notificationOsdPresets, Config.osdDuration))
  }

  function toggleNotificationDuplicates(): void {
    Config.setNotificationPolicy(Config.notificationDisplayTime,
      Config.maxNotificationsInStack, !Config.avoidDuplicateNotifications, Config.osdDuration)
  }

  function cycleIdle(key: string): void {
    const current = key === "dim" ? Config.idleDimSeconds
                  : key === "lock" ? Config.idleLockSeconds
                  : key === "off" ? Config.idleScreenOffSeconds
                  : Config.idleSuspendSeconds
    const list = key === "dim" ? panel.idlePresets.dim
               : key === "lock" ? panel.idlePresets.lock
               : key === "off" ? panel.idlePresets.off
               : panel.idlePresets.suspend
    Config.setIdleTimer(key, panel.nextPreset(list, current))
  }

  function nudgeSelected(direction: int): void {
    if (panel.page === "nightlight") {
      if (panel.selectedIndex === 1) {
        NightLightController.enabled = !NightLightController.enabled
        return
      }
      if (panel.selectedIndex >= 2) {
        const slider = panel.lightSliders[panel.selectedIndex - 2]
        if (slider) panel.adjustLightSlider(slider.key, direction)
      }
      return
    }
    if (panel.page === "streams") {
      panel.adjustStreamVolume(panel.selectedStreamNode(), direction)
      return
    }
    if (panel.page === "main") {
      const row = panel.rows[panel.selectedIndex]
      if (row && row.cycle && !row.toggle) { row.cycle(); return }
    }
    panel.toggleSelected()
  }

  function runNetworkAction(argv): void {
    panel.networkError = ""
    networkAction.command = argv
    networkAction.running = true
  }

  // Default apps: filled from `gio mime` when the page is opened.
  property var appRows: panel.blankAppRows()
  property var mimeQueue: []
  property int mimeIndex: 0
  property string appsError: ""

  function firstSelectable(): int {
    for (let i = 0; i < rows.length; i++)
      if (rows[i].section === undefined) return i
    return 0
  }

  function firstPageRow(): int {
    return page === "main" ? firstSelectable() : 0
  }

  function isSelectable(i: int): bool {
    return i >= 0 && i < rows.length && rows[i].section === undefined
  }

  function pageRowCount(): int {
    return page === "main" ? rows.length : subRowCount
  }

  // the audio pages share one page, so they share its repeater and body;
  // nothing reads these on the main page
  readonly property var listRepeater: page === "wifi" ? wifiRepeater
                                    : page === "bluetooth" ? btRepeater
                                    : page === "apps" ? appsRepeater
                                    : page === "streams" ? streamsRepeater
                                    : audioRepeater

  // the scrolling body that holds listRepeater's rows
  readonly property var listView: page === "wifi" ? wifiList
                                : page === "bluetooth" ? btList
                                : page === "apps" ? appsList
                                : page === "streams" ? streamsList
                                : audioList

  function listCount(): int {
    return page === "main" || page === "nightlight" ? 0 : listRepeater.count
  }

  function listKeyAt(listIndex: int): string {
    if (listIndex < 0) return ""
    const item = listRepeater.itemAt(listIndex)
    return item && item.rowKey !== undefined ? item.rowKey : ""
  }

  function listIndexOfKey(key: string): int {
    if (key.length === 0) return -1
    for (let i = 0; i < listCount(); i++)
      if (listKeyAt(i) === key) return i
    return -1
  }

  // Single entry point for the selection, so selectedIndex and selectedKey can
  // never point at different rows.
  function selectRow(index: int): void {
    panel.selectedIndex = index
    panel.selectedKey = panel.page === "main" || panel.page === "nightlight"
                     || index < panel.listHeaderRows
                     ? "" : panel.listKeyAt(index - panel.listHeaderRows)
  }

  // After the model reorders or shrinks: keep the same row selected by name, or
  // fall back to the first list row when it is gone (first static row if empty).
  function rebindSelection(): void {
    if (panel.page === "main" || panel.page === "nightlight"
        || panel.selectedIndex < panel.listHeaderRows) return
    const found = panel.listIndexOfKey(panel.selectedKey)
    if (found >= 0) { panel.selectedIndex = panel.listHeaderRows + found; return }
    panel.selectRow(panel.listCount() > 0 ? panel.listHeaderRows : 0)
  }

  function moveSelection(step: int): void {
    const count = pageRowCount()
    if (count <= 0) return
    let i = panel.selectedIndex
    for (let n = 0; n < count; n++) {
      i = (i + step + count) % count
      if (page === "main" ? isSelectable(i) : true) {
        panel.selectRow(i)
        if (panel.page === "main") panel.ensureRowVisible(i)
        else if (panel.page !== "nightlight" && i >= panel.listHeaderRows)
          panel.ensureListVisible(i - panel.listHeaderRows)
        return
      }
    }
  }

  function ensureListVisible(listIndex: int): void {
    const list = panel.listView
    if (!list || list.height <= 0) return
    const top = listIndex * 34
    if (top < list.contentY) list.contentY = top
    else if (top + 32 > list.contentY + list.height) list.contentY = top + 32 - list.height
  }

  // the main page scrolls too: it has more sections than the panel is tall
  function ensureRowVisible(index: int): void {
    const row = mainRows.itemAt(index)
    if (!row || mainList.height <= 0) return
    if (row.y < mainList.contentY) mainList.contentY = row.y
    else if (row.y + row.height > mainList.contentY + mainList.height)
      mainList.contentY = row.y + row.height - mainList.height
  }

  function activateSelected(): void {
    if (panel.passwordVisible) { panel.submitPassword(); return }
    if (panel.page === "bluetooth" && BluetoothPairingAgent.requestActive) { panel.submitPairing(); return }
    if (panel.page === "nightlight") {
      if (panel.selectedIndex === 0) panel.pageRequested("main")
      else if (panel.selectedIndex === 1)
        NightLightController.enabled = !NightLightController.enabled
      return
    }
    if (panel.page === "main") {
      const row = rows[panel.selectedIndex]
      if (!row || !isSelectable(panel.selectedIndex)) return
      if (row.activate) row.activate()
      else if (row.toggle) row.toggle()
      else if (row.cycle) row.cycle()
      return
    }
    if (panel.selectedIndex === 0) { panel.pageRequested("main"); return }
    if (panel.listHeaderRows === panel.subStaticRows) { // wifi / bluetooth
      if (panel.selectedIndex === 1) { panel.toggleSelected(); return }
      if (panel.selectedIndex === 2) { panel.scanSelected(); return }
    }
    // Act on the row selectedKey names, never on whatever now sits at selectedIndex.
    let i = panel.listIndexOfKey(panel.selectedKey)
    if (i < 0) { panel.rebindSelection(); i = panel.listIndexOfKey(panel.selectedKey) }
    if (i < 0) return
    const item = panel.listRepeater.itemAt(i)
    if (item && item.activate) item.activate()
  }

  function toggleSelected(): void {
    if (panel.page === "main") {
      const row = rows[panel.selectedIndex]
      if (row && row.toggle) row.toggle()
    } else if (panel.selectedIndex === 1 && panel.listHeaderRows === panel.subStaticRows) {
      if (panel.page === "wifi") WifiController.setEnabled(!WifiController.enabled)
      else if (panel.page === "bluetooth") BluetoothController.setEnabled(!BluetoothController.enabled)
    }
  }

  function scanSelected(): void {
    if (panel.page === "wifi") {
      if (WifiController.enabled) WifiController.refreshNetworks(true)
    } else if (panel.page === "bluetooth") {
      if (BluetoothController.enabled) BluetoothController.refreshDevices(true)
    }
  }

  // ------------------------------------------------------------------- audio
  function mediaClass(node): string {
    const props = node && node.properties ? node.properties : {}
    return String(props["media.class"] || "")
  }

  // An audio device: not a video node and not an application stream.
  function isAudioNode(node): bool {
    return node !== null && node !== undefined && node.audio && !node.isStream
           && panel.mediaClass(node).startsWith("Audio/")
  }

  function audioLabel(node): string {
    if (!node) return ""
    return node.description && node.description.length > 0 ? node.description : node.name
  }

  function audioVolume(node): string {
    if (!node || !node.audio) return ""
    return Math.round(node.audio.volume * 100) + "%"
  }

  // Playback streams only: capture streams belong to the input-device page.
  function isStreamNode(node): bool {
    return node !== null && node !== undefined && node.audio && node.isStream
           && panel.mediaClass(node).startsWith("Stream/Output/Audio")
  }

  function streamLabel(node): string {
    if (!node) return ""
    const props = node.properties || {}
    const app = String(props["application.name"] || "")
    const media = String(props["media.name"] || "")
    if (app.length > 0 && media.length > 0 && media !== app)
      return app + " · " + media
    return app.length > 0 ? app
         : (node.description && node.description.length > 0 ? node.description : node.name)
  }

  function selectedStreamNode(): var {
    const index = panel.listIndexOfKey(panel.selectedKey)
    return index >= 0 ? panel.streamNodes[index] : null
  }

  function toggleStreamMute(node): void {
    if (node && node.audio) node.audio.muted = !node.audio.muted
  }

  function adjustStreamVolume(node, direction: int): void {
    if (!node || !node.audio) return
    node.audio.volume = Math.max(0, Math.min(1.5, node.audio.volume + direction * 0.05))
  }

  // Pipewire.defaultAudioSink / defaultAudioSource are read-only: the writable
  // knob is the configured (preferred) default, which WirePlumber then selects.
  function setAudioDefault(node): void {
    if (!node) return
    panel.audioError = ""
    try {
      if (node.isSink) Pipewire.preferredDefaultAudioSink = node
      else Pipewire.preferredDefaultAudioSource = node
    } catch (e) {
      panel.audioError = "Could not switch the default device: " + e
    }
  }

  function defaultOutputLabel(): string {
    const node = Pipewire.defaultAudioSink
    return node ? panel.audioLabel(node) : "None"
  }

  function defaultInputLabel(): string {
    const node = Pipewire.defaultAudioSource
    return node ? panel.audioLabel(node) : "None"
  }

  // ------------------------------------------------------------ default apps
  // gio is the only thing that knows both the current default and the installed
  // candidates for a mimetype, so the rows are answers to `gio mime <type>`.
  function appRoleTemplate(): var {
    return [
      { icon: "\uf0ac", label: "Browser", mime: "x-scheme-handler/http" },
      { icon: "\uf07b", label: "File manager", mime: "inode/directory" },
      { icon: "\uf120", label: "Terminal", mime: "x-scheme-handler/terminal" },
      { icon: "\uf03e", label: "Image viewer", mime: "image/png" },
      { icon: "\uf03d", label: "Video player", mime: "video/mp4" },
      { icon: "\uf1c1", label: "PDF viewer", mime: "application/pdf" },
      { icon: "\uf044", label: "Text editor", mime: "text/plain" }
    ]
  }

  function appValue(row): string {
    if (!row) return ""
    if (row.loading) return "…"
    if (row.def && row.def.length > 0) return row.def
    return row.candidates && row.candidates.length > 0 ? "Not set" : "None"
  }

  function blankAppRows(): var {
    const rows = panel.appRoleTemplate()
    for (let i = 0; i < rows.length; i++) {
      rows[i].def = ""
      rows[i].candidates = []
      rows[i].loading = true
    }
    return rows
  }

  function refreshApps(): void {
    panel.appsError = ""
    panel.appRows = panel.blankAppRows()
    panel.queryMimes([0, 1, 2, 3, 4, 5, 6])
  }

  // one gio call at a time, in order
  function queryMimes(indices): void {
    panel.mimeQueue = indices.slice()
    panel.queryNextMime()
  }

  function queryNextMime(): void {
    if (panel.mimeQueue.length === 0) return
    const index = panel.mimeQueue[0]
    const row = panel.appRows[index]
    if (!row) { panel.mimeQueue = panel.mimeQueue.slice(1); panel.queryNextMime(); return }
    panel.mimeIndex = index
    mimeQuery.command = ["gio", "mime", row.mime]
    mimeQuery.running = true
  }

  function parseMimeOutput(text: string): var {
    const lines = String(text).split("\n")
    const registered = []
    const recommended = []
    let def = ""
    let bucket = null
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line.length === 0) continue
      if (line.startsWith("Default application for")) {
        def = line.substring(line.lastIndexOf(":") + 1).trim()
        bucket = null
        continue
      }
      if (line.startsWith("No default applications")) { def = ""; bucket = null; continue }
      if (line.startsWith("Registered applications")) { bucket = registered; continue }
      if (line.startsWith("Recommended applications")) { bucket = recommended; continue }
      if (bucket) bucket.push(line)
    }
    const candidates = []
    for (let i = 0; i < registered.length; i++)
      if (candidates.indexOf(registered[i]) < 0) candidates.push(registered[i])
    for (let i = 0; i < recommended.length; i++)
      if (candidates.indexOf(recommended[i]) < 0) candidates.push(recommended[i])
    return { def: def, candidates: candidates }
  }

  function applyMimeQuery(text: string): void {
    const index = panel.mimeIndex
    const rows = panel.appRows.slice()
    const row = rows[index]
    if (row) {
      const parsed = panel.parseMimeOutput(text)
      row.def = parsed.def
      row.candidates = parsed.candidates
      row.loading = false
      panel.appRows = rows
    }
    panel.mimeQueue = panel.mimeQueue.slice(1)
    panel.queryNextMime()
  }

  // Cycle to the next installed candidate and let gio write it, then re-read the
  // row so the value is what gio reports rather than what we asked for.
  function cycleDefaultApp(index: int): void {
    const row = panel.appRows[index]
    if (!row || !row.candidates || row.candidates.length === 0) return
    if (mimeSet.running || mimeQuery.running) return
    const at = row.candidates.indexOf(row.def)
    const next = row.candidates[(at + 1) % row.candidates.length]
    if (next === row.def) return
    panel.appsError = ""
    // the row reads "…" until the write and the re-read are done
    const rows = panel.appRows.slice()
    rows[index].loading = true
    panel.appRows = rows
    panel.mimeIndex = index
    mimeSet.command = ["gio", "mime", row.mime, next]
    mimeSet.running = true
  }

  function pageTitle(): string {
    if (panel.page === "nightlight") return "Night light"
    if (panel.page === "audioout") return "Output devices"
    if (panel.page === "audioin") return "Input devices"
    if (panel.page === "streams") return "Application streams"
    if (panel.page === "apps") return "Default apps"
    return ""
  }

  function handleEscape(): void {
    if (panel.passwordVisible) { panel.cancelPassword(); return }
    if (panel.page === "bluetooth" && BluetoothPairingAgent.requestActive) { panel.cancelPairing(); return }
    if (panel.page !== "main") { panel.pageRequested("main"); return }
    panel.closeRequested()
  }

  function startPassword(ssid: string): void {
    panel.passwordSsid = ssid
    panel.showPassword = false
    panel.passwordVisible = true
    passwordFocusTimer.restart()
  }

  // The overlay stays up for the whole attempt: it is dismissed on success (the
  // requested ssid comes up connected) or by the user, and a wrong password
  // leaves the field in place with the backend's error next to it.
  function submitPassword(): void {
    if (!panel.passwordVisible || panel.passwordSsid.length === 0) return
    if (!WifiController.enabled || WifiController.busy) return
    WifiController.clearMessages()
    panel.pendingSsid = panel.passwordSsid
    WifiController.connectToNetwork(panel.passwordSsid, passwordField.text)
  }

  function cancelPassword(): void {
    panel.passwordVisible = false
    panel.passwordSsid = ""
    panel.pendingSsid = ""
    passwordField.text = ""
    panel.forceActiveFocus()
  }

  function submitPairing(): void {
    if (!BluetoothPairingAgent.requestActive) return

    if (BluetoothPairingAgent.requestRequiresInput) {
      const secret = btSecretField.text.trim()
      // submitSecret() silently refuses empty or out-of-range input; validate
      // here so the overlay never stays up around a field that goes nowhere.
      if (secret.length === 0) {
        panel.pairingError = BluetoothPairingAgent.requestNumericInput
              ? "Enter the passkey shown on the device" : "Enter the PIN"
        btSecretField.forceActiveFocus()
        return
      }
      if (BluetoothPairingAgent.requestNumericInput && !/^\d{1,6}$/.test(secret)) {
        panel.pairingError = "A passkey is 1–6 digits"
        btSecretField.forceActiveFocus()
        return
      }
      BluetoothPairingAgent.submitSecret(secret)
      if (BluetoothPairingAgent.requestActive) {
        panel.pairingError = "A passkey is 1–6 digits"
        btSecretField.forceActiveFocus()
        return
      }
      btSecretField.text = ""
      panel.pairingError = ""
    } else if (BluetoothPairingAgent.requestRequiresConfirmation) {
      BluetoothPairingAgent.confirmRequest()
    } else {
      BluetoothPairingAgent.cancelRequest()
    }
    panel.forceActiveFocus()
  }

  function cancelPairing(): void {
    if (!BluetoothPairingAgent.requestActive) return
    if (BluetoothPairingAgent.requestRequiresConfirmation) BluetoothPairingAgent.rejectRequest()
    else BluetoothPairingAgent.cancelRequest()
    btSecretField.text = ""
    panel.forceActiveFocus()
  }

  Keys.onUpPressed: panel.moveSelection(-1)
  Keys.onDownPressed: panel.moveSelection(1)
  Keys.onReturnPressed: panel.activateSelected()
  Keys.onEnterPressed: panel.activateSelected()
  Keys.onSpacePressed: panel.activateSelected()
  Keys.onLeftPressed: panel.nudgeSelected(-1)
  Keys.onRightPressed: panel.nudgeSelected(1)
  Keys.onEscapePressed: panel.handleEscape()

  onPageChanged: {
    panel.selectRow(panel.firstPageRow())
    panel.passwordVisible = false
    panel.passwordSsid = ""
    panel.pendingSsid = ""
    panel.pairingError = ""
    if (panel.page === "wifi" && WifiController.enabled) WifiController.refreshNetworks(true)
    else if (panel.page === "bluetooth" && BluetoothController.enabled) BluetoothController.refreshDevices(true)
    else if (panel.page === "apps") panel.refreshApps()
    panel.forceActiveFocus()
  }

  Component.onCompleted: {
    panel.refreshNetwork()
    if (panel.page === "wifi" && WifiController.enabled) WifiController.refreshNetworks(true)
    else if (panel.page === "bluetooth" && BluetoothController.enabled) BluetoothController.refreshDevices(true)
    else if (panel.page === "apps") panel.refreshApps()
  }

  // Both models reset wholesale (a rescan re-sorts by signal, a device drops out,
  // the radio goes off) and the Repeaters rebuild their delegates; re-resolve the
  // selection once that has settled.
  Connections {
    target: WifiController.networks
    function onModelReset() { Qt.callLater(panel.rebindSelection) }
  }

  Connections {
    target: BluetoothController.devices
    function onModelReset() { Qt.callLater(panel.rebindSelection) }
  }

  // A password attempt ends either connected — dismiss the overlay — or with the
  // backend's error, which keeps it up with the field ready for another try.
  Connections {
    target: WifiController

    function onCurrentSsidChanged() {
      if (panel.passwordVisible && panel.pendingSsid.length > 0
          && WifiController.currentSsid === panel.pendingSsid)
        panel.cancelPassword()
    }

    function onBusyChanged() {
      if (!panel.passwordVisible || WifiController.busy) return
      if (WifiController.currentSsid === panel.pendingSsid) return
      if (WifiController.errorMessage.length > 0) passwordField.selectAll()
      passwordFocusTimer.restart()
    }
  }

  Timer {
    id: passwordFocusTimer
    interval: 100
    onTriggered: if (panel.passwordVisible) passwordField.forceActiveFocus()
  }

  Timer {
    id: btFocusTimer
    interval: 60
    onTriggered: {
      if (BluetoothPairingAgent.requestActive && BluetoothPairingAgent.requestRequiresInput)
        btSecretField.forceActiveFocus()
    }
  }

  // Keeps every node the audio pages can list live (descriptions, volumes).
  PwObjectTracker {
    objects: panel.trackedNodes
  }

  Process {
    id: networkDevices
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    environment: ({ LC_ALL: "C" })
    stdout: StdioCollector { id: networkDevicesOut; waitForEnd: true }
    stderr: StdioCollector { id: networkDevicesErr; waitForEnd: true }

    onExited: (code, status) => {
      if (code !== 0) {
        panel.networkError = networkDevicesErr.text.trim() || ("nmcli exited with " + code)
        panel.networkBusy = false
        return
      }
      panel.parseNetworkDevices(networkDevicesOut.text)
      networkConnections.running = true
    }
  }

  Process {
    id: networkConnections
    command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]
    environment: ({ LC_ALL: "C" })
    stdout: StdioCollector { id: networkConnectionsOut; waitForEnd: true }
    stderr: StdioCollector { id: networkConnectionsErr; waitForEnd: true }

    onExited: (code, status) => {
      if (code !== 0)
        panel.networkError = networkConnectionsErr.text.trim() || ("nmcli exited with " + code)
      else
        panel.parseNetworkConnections(networkConnectionsOut.text)
      panel.networkBusy = false
    }
  }

  Process {
    id: networkAction
    environment: ({ LC_ALL: "C" })
    stderr: StdioCollector { id: networkActionErr; waitForEnd: true }

    onExited: (code, status) => {
      if (code !== 0)
        panel.networkError = networkActionErr.text.trim() || ("nmcli exited with " + code)
      panel.refreshNetwork()
    }
  }

  // `gio mime <type>` — one query at a time, LC_ALL=C so the output parses the
  // same whatever the session locale is.
  Process {
    id: mimeQuery
    environment: ({ LC_ALL: "C" })

    stdout: StdioCollector {
      id: mimeQueryOut
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: mimeQueryErr
      waitForEnd: true
    }

    onExited: (code, status) => {
      if (code !== 0)
        panel.appsError = mimeQueryErr.text.trim() || ("gio mime exited with " + code)
      panel.applyMimeQuery(code === 0 ? mimeQueryOut.text : "")
    }
  }

  // `gio mime <type> <app.desktop>` — cycles a default app
  Process {
    id: mimeSet
    environment: ({ LC_ALL: "C" })

    stdout: StdioCollector { waitForEnd: true }

    stderr: StdioCollector {
      id: mimeSetErr
      waitForEnd: true
    }

    onExited: (code, status) => {
      const index = panel.mimeIndex
      if (code !== 0) {
        panel.appsError = mimeSetErr.text.trim() || ("gio mime exited with " + code)
        return
      }
      panel.queryMimes([index])
    }
  }

  // value: live text for the right side, on: switch state, activate: row click,
  // toggle: switch click and Left/Right, cycle: click on the value text,
  // page: the name of the sub-page the row opens — that is what earns the chevron.
  readonly property var rows: [
    { section: "Network" },
    { icon: "\uf1eb", label: "Wi-fi",
      page: "wifi",
      value: () => WifiController.enabled
             ? (WifiController.currentSsid.length > 0 ? WifiController.currentSsid
                : (WifiController.statusText.length > 0 ? WifiController.statusText : "Disconnected"))
             : "Off",
      on: () => WifiController.enabled,
      activate: () => panel.pageRequested("wifi"),
      toggle: () => WifiController.setEnabled(!WifiController.enabled) },
    { icon: "\uf294", label: "Bluetooth",
      page: "bluetooth",
      value: () => BluetoothController.enabled
             ? (BluetoothController.currentDeviceName.length > 0 ? BluetoothController.currentDeviceName
                : (BluetoothController.statusText.length > 0 ? BluetoothController.statusText : "Disconnected"))
             : "Off",
      on: () => BluetoothController.enabled,
      activate: () => panel.pageRequested("bluetooth"),
      toggle: () => BluetoothController.setEnabled(!BluetoothController.enabled) },
    { icon: "\uf0e8", label: "Ethernet",
      value: () => panel.ethernetLabel(),
      on: () => panel.ethernetActive(),
      toggle: () => panel.toggleEthernet() },
    { icon: "\uf023", label: "VPN",
      value: () => panel.vpnLabel(),
      on: () => panel.activeVpn() !== null,
      toggle: () => panel.toggleVpn(),
      cycle: () => panel.cycleVpn() },

    { section: "Audio" },
    { icon: "\uf028", label: "Output device",
      page: "audioout",
      value: () => panel.defaultOutputLabel(),
      activate: () => panel.pageRequested("audioout") },
    { icon: "\uf130", label: "Input device",
      page: "audioin",
      value: () => panel.defaultInputLabel(),
      activate: () => panel.pageRequested("audioin") },
    { icon: "\uf001", label: "App streams",
      page: "streams",
      value: () => panel.streamNodes.length + " active",
      activate: () => panel.pageRequested("streams") },

    { section: "Display" },
    { icon: "\uf03e", label: "Wallpaper",
      value: () => {
        const path = WallpaperController.path
        return path.length > 0 ? path.split("/").pop() : "None"
      },
      activate: () => panel.openWallpaperSwitcher() },
    { icon: "\uf03e", label: "Fit mode",
      value: () => WallpaperController.mode,
      cycle: () => {
        const modes = ["fill", "fit", "spread", "stretch", "tile"]
        const i = modes.indexOf(WallpaperController.mode)
        WallpaperController.mode = modes[(i + 1) % modes.length]
        WallpaperController.reload()
      } },
    { icon: "\uf008", label: "Slideshow",
      value: () => WallpaperController.slideshowEnabled
             ? WallpaperController.slideshowIntervalMinutes + "m" : "Off",
      on: () => WallpaperController.slideshowEnabled,
      toggle: () => WallpaperController.slideshowEnabled = !WallpaperController.slideshowEnabled,
      cycle: () => {
        const steps = [5, 15, 30, 60, 120]
        const i = steps.indexOf(WallpaperController.slideshowIntervalMinutes)
        WallpaperController.slideshowIntervalMinutes = steps[(i + 1) % steps.length]
      } },
    { icon: "\uf186", label: "Night light",
      page: "nightlight",
      value: () => !NightLightController.enabled ? "Off"
             : (NightLightController.active ? NightLightController.temperature + "K" : "Starting"),
      on: () => NightLightController.enabled,
      activate: () => panel.pageRequested("nightlight"),
      toggle: () => NightLightController.enabled = !NightLightController.enabled },

    { section: "Notifications" },
    { icon: "\uf1f6", label: "Quiet mode",
      value: () => Notifier.dndEnabled ? "On" : "Off",
      on: () => Notifier.dndEnabled,
      toggle: () => Notifier.dndEnabled = !Notifier.dndEnabled },
    { icon: "\uf0f3", label: "Toast duration",
      value: () => Math.round(Config.notificationDisplayTime / 1000) + "s",
      cycle: () => panel.cycleNotificationDisplay() },
    { icon: "\uf1da", label: "History depth",
      value: () => Config.maxNotificationsInStack + " items",
      cycle: () => panel.cycleNotificationHistory() },
    { icon: "\uf0c5", label: "Collapse repeats",
      value: () => Config.avoidDuplicateNotifications ? "On" : "Off",
      on: () => Config.avoidDuplicateNotifications,
      toggle: () => panel.toggleNotificationDuplicates() },
    { icon: "\uf017", label: "OSD duration",
      value: () => Config.osdDuration + "ms",
      cycle: () => panel.cycleNotificationOsd() },

    { section: "Power" },
    { icon: "\uf185", label: "Dim after",
      value: () => panel.formatIdle(Config.idleDimSeconds),
      cycle: () => panel.cycleIdle("dim") },
    { icon: "\uf023", label: "Lock after",
      value: () => panel.formatIdle(Config.idleLockSeconds),
      cycle: () => panel.cycleIdle("lock") },
    { icon: "\uf108", label: "Screen off after",
      value: () => panel.formatIdle(Config.idleScreenOffSeconds),
      cycle: () => panel.cycleIdle("off") },
    { icon: "\uf186", label: "Suspend after",
      value: () => panel.formatIdle(Config.idleSuspendSeconds),
      cycle: () => panel.cycleIdle("suspend") },

    { section: "Shell" },
    { icon: "\uf11c", label: "Keybinds",
      activate: () => panel.openKeybinds() },
    { icon: "\uf0ea", label: "Clipboard",
      activate: () => panel.openClipboard() },

    { section: "System" },
    { icon: "\uf085", label: "Default apps",
      page: "apps",
      activate: () => panel.pageRequested("apps") },
    { icon: "\uf0f1", label: "Diagnostics",
      value: () => panel.diagnosticVerdict.length > 0 ? panel.diagnosticVerdict : "Not run",
      activate: () => panel.diagnosticsRequested() },
    { icon: "\uf15c", label: "Config file",
      activate: () => panel.openConfigFile() }
  ]

  // ---------------------------------------------------------------- main page
  // Flickable, not a bare layout: there are more sections than fit in the panel,
  // and a squeezed ColumnLayout would crop the rows.
  Flickable {
    id: mainList

    anchors.fill: parent
    anchors.margins: 12
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentHeight: mainPage.implicitHeight
    contentWidth: width
    visible: panel.page === "main"

    ColumnLayout {
      id: mainPage

      width: mainList.width
      spacing: 1

      Repeater {
        id: mainRows

        model: panel.rows

        delegate: Item {
          id: entry

          readonly property bool isSection: modelData.section !== undefined
          readonly property var row: modelData
          readonly property bool isSelected: !isSection && panel.selectedIndex === index
          readonly property bool hasSwitch: row.toggle !== undefined
          readonly property bool switchOn: row.on ? row.on() : false
          readonly property string rowValue: row.value ? row.value() : ""

          Layout.fillWidth: true
          Layout.preferredHeight: entry.isSection ? 12 : 32

          function select(): void {
            panel.selectRow(index)
          }

          function activate(): void {
            entry.select()
            if (entry.row.activate) entry.row.activate()
            else if (entry.row.toggle) entry.row.toggle()
            else if (entry.row.cycle) entry.row.cycle()
          }

          Text {
            visible: entry.isSection
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            text: entry.isSection ? entry.row.section.toUpperCase() : ""
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
            font.letterSpacing: 1.5
          }

          Rectangle {
            id: rowBox

            visible: !entry.isSection
            anchors.fill: parent
            radius: 10
            color: entry.isSelected || rowHover.hovered ? Theme.bg5 : "transparent"
            border.width: entry.isSelected ? 1 : 0
            border.color: Theme.accent

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            HoverHandler { id: rowHover }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: entry.activate()
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              Text {
                text: entry.isSection || entry.row.icon === undefined ? "" : entry.row.icon
                color: entry.isSelected ? Theme.accent : Theme.fg4
                font { family: Theme.nerdFontFamily; pixelSize: 12 }
              }

              Text {
                Layout.fillWidth: true
                text: entry.isSection || entry.row.label === undefined ? "" : entry.row.label
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10; weight: entry.isSelected ? 600 : 500 }
                elide: Text.ElideRight
              }

              Item {
                id: valueBox

                visible: entry.row.value !== undefined
                Layout.preferredWidth: Math.min(valueText.implicitWidth, 150)
                Layout.preferredHeight: 16

                Text {
                  id: valueText

                  anchors.fill: parent
                  text: entry.rowValue
                  color: Theme.fg4
                  font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: entry.row.cycle !== undefined
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: {
                    entry.select()
                    if (entry.row.cycle) entry.row.cycle()
                  }
                }
              }

              Item {
                id: switchBox

                visible: entry.hasSwitch
                Layout.preferredWidth: 28
                Layout.preferredHeight: 16

                Rectangle {
                  anchors.fill: parent
                  radius: 8
                  color: entry.switchOn ? Theme.accent : Theme.chipBg

                  Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                  Rectangle {
                    width: 12
                    height: 12
                    y: 2
                    x: entry.switchOn ? 14 : 2
                    radius: 6
                    color: entry.switchOn ? Theme.bg : Theme.fg4

                    Behavior on x {
                      NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    entry.select()
                    if (entry.row.toggle) entry.row.toggle()
                  }
                }
              }

              Text {
                visible: entry.row.page !== undefined
                Layout.preferredWidth: 8
                text: "›"
                color: Theme.fg4
                horizontalAlignment: Text.AlignRight
                font { family: Theme.fontFamily; pixelSize: 14 }
              }
            }
          }
        }
      }
    }
  }

  // -------------------------------------------------------------- sub-pages
  ColumnLayout {
    id: subPage
    anchors.fill: parent
    anchors.margins: 12
    spacing: 2
    visible: panel.page !== "main"

    Rectangle {
      id: backRow

      Layout.fillWidth: true
      Layout.preferredHeight: 32
      radius: 10
      color: panel.selectedIndex === 0 || backHover.hovered ? Theme.bg5 : "transparent"
      border.width: panel.selectedIndex === 0 ? 1 : 0
      border.color: Theme.accent

      Behavior on color { ColorAnimation { duration: Theme.motionFast } }

      HoverHandler { id: backHover }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          panel.selectRow(0)
          panel.pageRequested("main")
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Text {
          text: "‹"
          color: panel.selectedIndex === 0 ? Theme.accent : Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 14 }
        }

        Text {
          Layout.fillWidth: true
          text: "Back"
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 10; weight: panel.selectedIndex === 0 ? 600 : 500 }
        }

        Text {
          visible: panel.pageTitle().length > 0
          text: panel.pageTitle()
          color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 8 }
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // ------------------------------------------------------ night light page
      ColumnLayout {
        id: nightLightPage
        anchors.fill: parent
        spacing: 8
        visible: panel.page === "nightlight"

        Rectangle {
          id: nlEnable
          Layout.fillWidth: true
          Layout.preferredHeight: 36
          radius: 10
          color: panel.selectedIndex === 1 || nlEnableHover.hovered ? Theme.bg5 : "transparent"
          border.width: panel.selectedIndex === 1 ? 1 : 0
          border.color: Theme.accent
          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          HoverHandler { id: nlEnableHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              panel.selectRow(1)
              NightLightController.enabled = !NightLightController.enabled
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: "\uf186"
              color: panel.selectedIndex === 1 ? Theme.accent : Theme.fg4
              font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
              Layout.fillWidth: true
              text: "Night light"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
            }

            Rectangle {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 16
              radius: 8
              color: NightLightController.enabled ? Theme.accent : Theme.chipBg
              Behavior on color { ColorAnimation { duration: Theme.motionFast } }

              Rectangle {
                width: 12
                height: 12
                y: 2
                x: NightLightController.enabled ? 14 : 2
                radius: 6
                color: NightLightController.enabled ? Theme.bg : Theme.fg4
                Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut } }
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
              }
            }
          }
        }

        Repeater {
          model: panel.lightSliders

          delegate: Item {
            id: sliderRow
            readonly property var spec: modelData
            property real liveValue: panel.lightSliderValue(spec.key)
            property real dragValue: 0

            Component.onCompleted: dragValue = liveValue
            onLiveValueChanged: if (!sliderMouse.pressed) dragValue = liveValue

            Layout.fillWidth: true
            Layout.preferredHeight: 54

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: panel.selectedIndex === 2 + index ? Theme.bg5 : "transparent"
              Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.topMargin: 6
              anchors.bottomMargin: 6
              spacing: 4

              RowLayout {
                Layout.fillWidth: true

                Text {
                  text: spec.label
                  color: Theme.fg
                  font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
                }

                Text {
                  Layout.fillWidth: true
                  text: spec.unit === "K"
                        ? Math.round(sliderRow.dragValue) + "K"
                        : sliderRow.dragValue.toFixed(2)
                  color: Theme.fg4
                  horizontalAlignment: Text.AlignRight
                  font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                }
              }

              Rectangle {
                id: sliderTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.bgD
                border.width: 1
                border.color: Theme.cardBorder

                Rectangle {
                  width: sliderTrack.width * (sliderRow.dragValue - spec.from) / (spec.to - spec.from)
                  height: parent.height
                  radius: 3
                  color: Theme.accent
                }

                Rectangle {
                  width: 12
                  height: 12
                  radius: 6
                  x: Math.max(0, Math.min(sliderTrack.width - width,
                       sliderTrack.width * (sliderRow.dragValue - spec.from) / (spec.to - spec.from) - width / 2))
                  anchors.verticalCenter: parent.verticalCenter
                  color: Theme.accent
                  border.width: 2
                  border.color: Theme.bg
                }

                MouseArea {
                  id: sliderMouse
                  anchors.fill: parent
                  anchors.topMargin: -12
                  anchors.bottomMargin: -12
                  cursorShape: Qt.PointingHandCursor

                  onPressed: (mouse) => {
                    panel.selectRow(2 + index)
                    updateFromX(mouse.x)
                  }
                  onPositionChanged: (mouse) => {
                    if (pressed) updateFromX(mouse.x)
                  }
                  onReleased: panel.setLightSliderValue(spec.key, sliderRow.dragValue)

                  function updateFromX(x) {
                    const ratio = Math.max(0, Math.min(1, x / width))
                    let value = spec.from + ratio * (spec.to - spec.from)
                    value = spec.key === "gamma"
                        ? Math.round(value * 20) / 20
                        : Math.round(value / spec.step) * spec.step
                    sliderRow.dragValue = value
                  }
                }
              }
            }
          }
        }

        Item { Layout.fillHeight: true }
      }

      // ----------------------------------------------------------- wifi page
      ColumnLayout {
        id: wifiPage
        anchors.fill: parent
        spacing: 2
        visible: panel.page === "wifi"

        Rectangle {
          id: wifiHeader

          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 10
          color: panel.selectedIndex === 1 || wifiHeaderHover.hovered ? Theme.bg5 : "transparent"
          border.width: panel.selectedIndex === 1 ? 1 : 0
          border.color: Theme.accent

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          HoverHandler { id: wifiHeaderHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              panel.selectRow(1)
              WifiController.setEnabled(!WifiController.enabled)
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: "\uf1eb"
              color: panel.selectedIndex === 1 ? Theme.accent : Theme.fg4
              font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
              Layout.fillWidth: true
              text: "Wi-fi"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 10; weight: panel.selectedIndex === 1 ? 600 : 500 }
            }

            Text {
              text: WifiController.enabled
                    ? (WifiController.currentSsid.length > 0 ? WifiController.currentSsid
                       : (WifiController.statusText.length > 0 ? WifiController.statusText : "Disconnected"))
                    : "Off"
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 9 }
              elide: Text.ElideRight
              Layout.maximumWidth: 140
            }

            Item {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 16

              Rectangle {
                anchors.fill: parent
                radius: 8
                color: WifiController.enabled ? Theme.accent : Theme.chipBg

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                Rectangle {
                  width: 12
                  height: 12
                  y: 2
                  x: WifiController.enabled ? 14 : 2
                  radius: 6
                  color: WifiController.enabled ? Theme.bg : Theme.fg4

                  Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut } }
                  Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  panel.selectRow(1)
                  WifiController.setEnabled(!WifiController.enabled)
                }
              }
            }
          }
        }

        Text {
          visible: !WifiController.enabled
          Layout.fillWidth: true
          Layout.leftMargin: 10
          Layout.preferredHeight: 16
          text: "Turn on Wi-fi to see networks"
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 9 }
          elide: Text.ElideRight
        }

        Rectangle {
          id: wifiScanRow

          // gated on the radio and on the work already in flight
          readonly property bool rowEnabled: WifiController.enabled && !WifiController.busy

          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 10
          opacity: wifiScanRow.rowEnabled ? 1 : 0.45
          color: wifiScanRow.rowEnabled
                 && (panel.selectedIndex === 2 || wifiScanHover.hovered) ? Theme.bg5 : "transparent"
          border.width: panel.selectedIndex === 2 ? 1 : 0
          border.color: Theme.accent

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          HoverHandler { id: wifiScanHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: wifiScanRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: wifiScanRow.rowEnabled
            onClicked: {
              panel.selectRow(2)
              WifiController.refreshNetworks(true)
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: "\uf021"
              color: panel.selectedIndex === 2 ? Theme.accent : Theme.fg4
              font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
              Layout.fillWidth: true
              text: "Scan"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 10; weight: panel.selectedIndex === 2 ? 600 : 500 }
            }

            Text {
              visible: WifiController.scanning
              text: "Scanning…"
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 9 }
            }
          }
        }

        Flickable {
          id: wifiList

          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentHeight: wifiColumn.implicitHeight
          contentWidth: width

          Column {
            id: wifiColumn
            width: wifiList.width
            spacing: 2

            Repeater {
              id: wifiRepeater
              model: WifiController.enabled ? WifiController.networks : null

              delegate: Rectangle {
                id: wifiNetRow

                readonly property int rowIndex: panel.listHeaderRows + index
                readonly property bool rowEnabled: WifiController.enabled && !WifiController.busy
                // the model role that names this row across reorders
                readonly property string rowKey: ssid
                // selection follows the key, not the position: a rescan re-sorts
                // the list and the highlight has to stay on the same network
                readonly property bool isSelected: panel.selectedKey.length > 0
                                                   && panel.selectedKey === rowKey

                width: wifiColumn.width
                height: 32
                radius: 10
                opacity: wifiNetRow.rowEnabled ? 1 : 0.45
                color: wifiNetRow.rowEnabled && (wifiNetRow.isSelected || wifiNetHover.hovered)
                       ? Theme.bg5 : "transparent"
                border.width: wifiNetRow.isSelected ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                function activate(): void {
                  if (!wifiNetRow.rowEnabled) return
                  panel.selectRow(wifiNetRow.rowIndex)
                  if (connected) { WifiController.disconnectCurrent(); return }
                  if (savedConnection || !secure) { WifiController.connectToNetwork(ssid); return }
                  panel.startPassword(ssid)
                }

                HoverHandler { id: wifiNetHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: wifiNetRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  enabled: wifiNetRow.rowEnabled
                  onClicked: wifiNetRow.activate()
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  Text {
                    text: secure ? "\uf023" : "\uf09c"
                    color: connected || wifiNetRow.isSelected ? Theme.accent : Theme.fg4
                    font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: displayName || ssid
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10; weight: connected ? 600 : 500 }
                    elide: Text.ElideRight
                  }

                  Text {
                    text: connected ? "Connected"
                          : savedConnection ? "Saved"
                          : (signal >= 0 ? signal + "%" : "")
                    color: connected ? Theme.accent : Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9 }
                  }
                }
              }
            }
          }

          // An empty list body must not read as broken. Pinned to the viewport
          // (contentItem scrolls with contentY), so it stays centred while empty.
          Text {
            visible: WifiController.enabled && wifiRepeater.count === 0
            x: 0
            y: wifiList.contentY
            width: wifiList.width
            height: wifiList.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: WifiController.scanning ? "Scanning…" : "No networks found"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 10 }
          }
        }

        Text {
          visible: WifiController.errorMessage.length > 0
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: WifiController.errorMessage
          color: Theme.deleting
          font { family: Theme.fontFamily; pixelSize: 9 }
          wrapMode: Text.WordWrap
        }
      }

      // ------------------------------------------------------ bluetooth page
      ColumnLayout {
        id: btPage
        anchors.fill: parent
        spacing: 2
        visible: panel.page === "bluetooth"

        Rectangle {
          id: btHeader

          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 10
          color: panel.selectedIndex === 1 || btHeaderHover.hovered ? Theme.bg5 : "transparent"
          border.width: panel.selectedIndex === 1 ? 1 : 0
          border.color: Theme.accent

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          HoverHandler { id: btHeaderHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              panel.selectRow(1)
              BluetoothController.setEnabled(!BluetoothController.enabled)
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: "\uf294"
              color: panel.selectedIndex === 1 ? Theme.accent : Theme.fg4
              font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
              Layout.fillWidth: true
              text: "Bluetooth"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 10; weight: panel.selectedIndex === 1 ? 600 : 500 }
            }

            Text {
              text: BluetoothController.enabled
                    ? (BluetoothController.currentDeviceName.length > 0 ? BluetoothController.currentDeviceName
                       : (BluetoothController.statusText.length > 0 ? BluetoothController.statusText : "Disconnected"))
                    : "Off"
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 9 }
              elide: Text.ElideRight
              Layout.maximumWidth: 140
            }

            Item {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 16

              Rectangle {
                anchors.fill: parent
                radius: 8
                color: BluetoothController.enabled ? Theme.accent : Theme.chipBg

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                Rectangle {
                  width: 12
                  height: 12
                  y: 2
                  x: BluetoothController.enabled ? 14 : 2
                  radius: 6
                  color: BluetoothController.enabled ? Theme.bg : Theme.fg4

                  Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut } }
                  Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  panel.selectRow(1)
                  BluetoothController.setEnabled(!BluetoothController.enabled)
                }
              }
            }
          }
        }

        Text {
          visible: BluetoothController.enabled && BluetoothController.adapterName.length > 0
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: "Visible as “" + BluetoothController.adapterName + "”"
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 9 }
          elide: Text.ElideRight
        }

        Text {
          visible: !BluetoothController.enabled
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: "Turn on Bluetooth to see devices"
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 9 }
          elide: Text.ElideRight
        }

        Rectangle {
          id: btScanRow

          // gated on the radio and on the work already in flight
          readonly property bool rowEnabled: BluetoothController.enabled && !BluetoothController.busy

          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 10
          opacity: btScanRow.rowEnabled ? 1 : 0.45
          color: btScanRow.rowEnabled
                 && (panel.selectedIndex === 2 || btScanHover.hovered) ? Theme.bg5 : "transparent"
          border.width: panel.selectedIndex === 2 ? 1 : 0
          border.color: Theme.accent

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          HoverHandler { id: btScanHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: btScanRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: btScanRow.rowEnabled
            onClicked: {
              panel.selectRow(2)
              BluetoothController.refreshDevices(true)
            }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: "\uf021"
              color: panel.selectedIndex === 2 ? Theme.accent : Theme.fg4
              font { family: Theme.nerdFontFamily; pixelSize: 12 }
            }

            Text {
              Layout.fillWidth: true
              text: "Scan"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 10; weight: panel.selectedIndex === 2 ? 600 : 500 }
            }

            Text {
              visible: BluetoothController.scanning
              text: "Scanning…"
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 9 }
            }
          }
        }

        Text {
          visible: BluetoothController.enabled
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: "Right-click a paired device to forget it"
          color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 8 }
          elide: Text.ElideRight
        }

        Flickable {
          id: btList

          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentHeight: btColumn.implicitHeight
          contentWidth: width

          Column {
            id: btColumn
            width: btList.width
            spacing: 2

            Repeater {
              id: btRepeater
              model: BluetoothController.enabled ? BluetoothController.devices : null

              delegate: Rectangle {
                id: btDevRow

                readonly property int rowIndex: panel.listHeaderRows + index
                readonly property bool rowEnabled: BluetoothController.enabled && !BluetoothController.busy
                // the model role that names this row across reorders
                readonly property string rowKey: address
                // selection follows the key, not the position: forgetting or a
                // device dropping out shifts the rows up under the cursor
                readonly property bool isSelected: panel.selectedKey.length > 0
                                                   && panel.selectedKey === rowKey

                width: btColumn.width
                height: 32
                radius: 10
                opacity: btDevRow.rowEnabled ? 1 : 0.45
                color: btDevRow.rowEnabled && (btDevRow.isSelected || btDevHover.hovered)
                       ? Theme.bg5 : "transparent"
                border.width: btDevRow.isSelected ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                function activate(): void {
                  if (!btDevRow.rowEnabled) return
                  panel.selectRow(btDevRow.rowIndex)
                  if (connected) { BluetoothController.disconnectDevice(address); return }
                  if (paired) { BluetoothController.connectDevice(address); return }
                  BluetoothController.pairDevice(address)
                }

                HoverHandler { id: btDevHover }

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  cursorShape: btDevRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  enabled: btDevRow.rowEnabled
                  onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                      panel.selectRow(btDevRow.rowIndex)
                      if (paired) BluetoothController.forgetDevice(address)
                      return
                    }
                    btDevRow.activate()
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  Text {
                    text: connected ? "\uf5b0" : paired ? "\uf0c1" : "\uf294"
                    color: connected || btDevRow.isSelected ? Theme.accent : Theme.fg4
                    font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: name
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10; weight: connected ? 600 : 500 }
                    elide: Text.ElideRight
                  }

                  Text {
                    text: connected ? "Connected"
                          : paired ? ("Paired" + (battery >= 0 ? " • " + battery + "%" : ""))
                          : "Not paired"
                    color: connected ? Theme.accent : Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9 }
                  }
                }
              }
            }
          }

          // An empty list body must not read as broken. Pinned to the viewport
          // (contentItem scrolls with contentY), so it stays centred while empty.
          Text {
            visible: BluetoothController.enabled && btRepeater.count === 0
            x: 0
            y: btList.contentY
            width: btList.width
            height: btList.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: BluetoothController.scanning ? "Scanning…" : "No devices found"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 10 }
          }
        }

        Text {
          visible: BluetoothController.errorMessage.length > 0
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: BluetoothController.errorMessage
          color: Theme.deleting
          font { family: Theme.fontFamily; pixelSize: 9 }
          wrapMode: Text.WordWrap
        }
      }

      // ----------------------------------------------------------- audio page
      // Output and input share one page: only the model, the marker and the
      // writable property differ, and the list itself is identical.
      ColumnLayout {
        id: audioPage

        anchors.fill: parent
        spacing: 2
        visible: panel.page === "audioout" || panel.page === "audioin"

        Flickable {
          id: audioList

          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentHeight: audioColumn.implicitHeight
          contentWidth: width

          Column {
            id: audioColumn
            width: audioList.width
            spacing: 2

            Repeater {
              id: audioRepeater
              model: panel.page === "audioin" ? panel.inputNodes : panel.outputNodes

              delegate: Rectangle {
                id: audioRow

                readonly property int rowIndex: panel.listHeaderRows + index
                // the node name is stable across the model reordering
                readonly property string rowKey: modelData.name
                readonly property bool isDefault:
                  panel.page === "audioin"
                    ? (Pipewire.defaultAudioSource !== null
                       && Pipewire.defaultAudioSource.name === modelData.name)
                    : (Pipewire.defaultAudioSink !== null
                       && Pipewire.defaultAudioSink.name === modelData.name)
                readonly property bool isSelected: panel.selectedKey.length > 0
                                                   && panel.selectedKey === rowKey

                width: audioColumn.width
                height: 32
                radius: 10
                color: audioRow.isSelected || audioHover.hovered ? Theme.bg5 : "transparent"
                border.width: audioRow.isSelected ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                function activate(): void {
                  panel.selectRow(audioRow.rowIndex)
                  panel.setAudioDefault(modelData)
                }

                HoverHandler { id: audioHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: audioRow.activate()
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  Text {
                    text: modelData.isSink ? "\uf028" : "\uf130"
                    color: audioRow.isDefault || audioRow.isSelected ? Theme.accent : Theme.fg4
                    font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: panel.audioLabel(modelData)
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10; weight: audioRow.isDefault ? 600 : 500 }
                    elide: Text.ElideRight
                  }

                  Text {
                    text: audioRow.isDefault ? "Default" : panel.audioVolume(modelData)
                    color: audioRow.isDefault ? Theme.accent : Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9 }
                  }
                }
              }
            }
          }

          // An empty list body must not read as broken. Pinned to the viewport
          // (contentItem scrolls with contentY), so it stays centred while empty.
          Text {
            visible: audioRepeater.count === 0
            x: 0
            y: audioList.contentY
            width: audioList.width
            height: audioList.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: panel.page === "audioin" ? "No input devices found" : "No output devices found"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 10 }
          }
        }

        Text {
          visible: panel.audioError.length > 0
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: panel.audioError
          color: Theme.deleting
          font { family: Theme.fontFamily; pixelSize: 9 }
          wrapMode: Text.WordWrap
        }
      }

      // --------------------------------------------------- application streams
      ColumnLayout {
        id: streamsPage

        anchors.fill: parent
        spacing: 2
        visible: panel.page === "streams"

        Text {
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: "Click a row to mute; use -/+ or Left/Right for volume."
          color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 8 }
          elide: Text.ElideRight
        }

        Flickable {
          id: streamsList

          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentHeight: streamsColumn.implicitHeight
          contentWidth: width

          Column {
            id: streamsColumn
            width: streamsList.width
            spacing: 2

            Repeater {
              id: streamsRepeater
              model: panel.streamNodes

              delegate: Rectangle {
                id: streamRow

                readonly property int rowIndex: panel.listHeaderRows + index
                readonly property string rowKey: String(modelData.id)
                readonly property bool isSelected: panel.selectedKey.length > 0
                                                   && panel.selectedKey === rowKey

                width: streamsColumn.width
                height: 34
                radius: 10
                color: streamRow.isSelected || streamHover.hovered ? Theme.bg5 : "transparent"
                border.width: streamRow.isSelected ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                function activate(): void {
                  panel.selectRow(streamRow.rowIndex)
                  panel.toggleStreamMute(modelData)
                }

                HoverHandler { id: streamHover }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: streamRow.activate()
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 6

                  Text {
                    text: modelData.audio.muted ? "\uf026" : "\uf001"
                    color: streamRow.isSelected ? Theme.accent : Theme.fg4
                    font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: panel.streamLabel(modelData)
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 6
                    color: minusHover.hovered ? Theme.chipBgHover : Theme.chipBg

                    Text {
                      anchors.centerIn: parent
                      text: "-"
                      color: Theme.fg4
                      font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
                    }

                    HoverHandler { id: minusHover }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        panel.selectRow(streamRow.rowIndex)
                        panel.adjustStreamVolume(modelData, -1)
                      }
                    }
                  }

                  Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 6
                    color: plusHover.hovered ? Theme.chipBgHover : Theme.chipBg

                    Text {
                      anchors.centerIn: parent
                      text: "+"
                      color: Theme.fg4
                      font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
                    }

                    HoverHandler { id: plusHover }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        panel.selectRow(streamRow.rowIndex)
                        panel.adjustStreamVolume(modelData, 1)
                      }
                    }
                  }

                  Text {
                    Layout.preferredWidth: 34
                    text: panel.audioVolume(modelData)
                    color: streamRow.isSelected ? Theme.accent : Theme.fg4
                    horizontalAlignment: Text.AlignRight
                    font { family: Theme.fontFamily; pixelSize: 9 }
                  }
                }
              }
            }
          }

          Text {
            visible: streamsRepeater.count === 0
            x: 0
            y: streamsList.contentY
            width: streamsList.width
            height: streamsList.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "No application streams"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 10 }
          }
        }
      }

      // ------------------------------------------------------ default apps page
      ColumnLayout {
        id: appsPage

        anchors.fill: parent
        spacing: 2
        visible: panel.page === "apps"

        Flickable {
          id: appsList

          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentHeight: appsColumn.implicitHeight
          contentWidth: width

          Column {
            id: appsColumn
            width: appsList.width
            spacing: 2

            Repeater {
              id: appsRepeater
              model: panel.appRows

              delegate: Rectangle {
                id: appRow

                readonly property int rowIndex: panel.listHeaderRows + index
                // nothing to switch to while gio has not answered, or when the
                // type has no installed handler at all
                readonly property bool rowEnabled: !modelData.loading
                                                   && modelData.candidates.length > 0
                readonly property string rowKey: modelData.mime
                readonly property bool isSelected: panel.selectedKey.length > 0
                                                   && panel.selectedKey === rowKey

                width: appsColumn.width
                height: 32
                radius: 10
                opacity: appRow.rowEnabled ? 1 : 0.45
                color: appRow.rowEnabled && (appRow.isSelected || appHover.hovered)
                       ? Theme.bg5 : "transparent"
                border.width: appRow.isSelected ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                function activate(): void {
                  if (!appRow.rowEnabled) return
                  panel.selectRow(appRow.rowIndex)
                  panel.cycleDefaultApp(index)
                }

                HoverHandler { id: appHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: appRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  enabled: appRow.rowEnabled
                  onClicked: appRow.activate()
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  Text {
                    text: modelData.icon
                    color: appRow.isSelected ? Theme.accent : Theme.fg4
                    font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.maximumWidth: 190
                    text: panel.appValue(modelData)
                    color: Theme.fg4
                    font { family: Theme.fontFamily; pixelSize: 9 }
                    elide: Text.ElideMiddle
                  }
                }
              }
            }
          }
        }

        Text {
          visible: panel.appsError.length > 0
          Layout.fillWidth: true
          Layout.leftMargin: 10
          text: panel.appsError
          color: Theme.deleting
          font { family: Theme.fontFamily; pixelSize: 9 }
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  // ------------------------------------------------------- wifi password
  Rectangle {
    id: passwordOverlay

    visible: panel.passwordVisible
    anchors.fill: parent
    color: Theme.bg1
    radius: 22
    z: 10

    onVisibleChanged: {
      if (visible) {
        passwordField.text = ""
        passwordFocusTimer.restart()
      }
    }

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      anchors.centerIn: parent
      width: parent.width - 32
      spacing: 10

      Text {
        Layout.fillWidth: true
        text: "Password for " + panel.passwordSsid
        color: Theme.fg2
        font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
        wrapMode: Text.Wrap
      }

      // The attempt stays on screen until it is decided: a wrong password has to
      // be retypable right here, not from a one-line error at the page bottom.
      Text {
        visible: WifiController.busy && panel.pendingSsid.length > 0
        Layout.fillWidth: true
        text: "Connecting…"
        color: Theme.fg4
        font { family: Theme.fontFamily; pixelSize: 10 }
      }

      Text {
        visible: !WifiController.busy && WifiController.errorMessage.length > 0
        Layout.fillWidth: true
        text: WifiController.errorMessage
        color: Theme.deleting
        font { family: Theme.fontFamily; pixelSize: 10 }
        wrapMode: Text.Wrap
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 8
        color: Theme.bg4
        border.color: passwordField.activeFocus ? Theme.accent : Theme.borderBg1
        border.width: passwordField.activeFocus ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        TextInput {
          id: passwordField
          anchors.fill: parent
          enabled: !WifiController.busy
          leftPadding: 12
          rightPadding: 38
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 12 }
          echoMode: panel.showPassword ? TextInput.Normal : TextInput.Password
          verticalAlignment: TextInput.AlignVCenter
          selectByMouse: true
          selectionColor: Theme.accent
          selectedTextColor: Theme.bg
          clip: true
          Keys.onReturnPressed: panel.submitPassword()
          Keys.onEscapePressed: panel.cancelPassword()

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter password..."
            color: Theme.fg4
            font: passwordField.font
            visible: passwordField.text.length === 0
          }
        }

        Rectangle {
          id: eyeBtn
          property bool showPassword: panel.showPassword

          anchors.right: parent.right
          anchors.rightMargin: 5
          anchors.verticalCenter: parent.verticalCenter
          width: 26
          height: 26
          radius: 6
          color: eyeMA.containsMouse ? Theme.bg5 : "transparent"

          Text {
            anchors.centerIn: parent
            text: eyeBtn.showPassword ? "󰈈" : "󰈉"
            color: eyeBtn.showPassword ? Theme.accent : Theme.fg3
            font { family: Theme.nerdFontFamily; pixelSize: 13 }
          }

          MouseArea {
            id: eyeMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.showPassword = !panel.showPassword
          }
        }
      }

      RowLayout {
        spacing: 8

        Rectangle {
          Layout.preferredWidth: 80
          Layout.preferredHeight: 30
          radius: 9
          opacity: joinMA.enabled ? 1 : 0.5
          color: joinMA.containsMouse ? Qt.darker(Theme.accent, 1.15) : Theme.accent

          Text {
            anchors.centerIn: parent
            text: "Join"
            color: Theme.fgL
            font { family: Theme.fontFamily; pixelSize: 11 }
          }

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          MouseArea {
            id: joinMA
            anchors.fill: parent
            enabled: !WifiController.busy
            hoverEnabled: true
            cursorShape: joinMA.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: panel.submitPassword()
          }
        }

        Rectangle {
          Layout.preferredWidth: 80
          Layout.preferredHeight: 30
          radius: 9
          color: cancelMA.containsMouse ? Theme.focusBg1 : Theme.bg5

          Text {
            anchors.centerIn: parent
            text: "Cancel"
            color: Theme.fg1
            font { family: Theme.fontFamily; pixelSize: 11 }
          }

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          MouseArea {
            id: cancelMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.cancelPassword()
          }
        }

        Item { Layout.fillWidth: true }
      }
    }
  }

  // ------------------------------------------------- bluetooth pairing agent
  Rectangle {
    id: btPairOverlay

    visible: panel.page === "bluetooth" && BluetoothPairingAgent.requestActive
    anchors.fill: parent
    color: Theme.bg1
    radius: 22
    z: 10
    focus: true

    Keys.onReturnPressed: panel.submitPairing()
    Keys.onEnterPressed: panel.submitPairing()
    Keys.onEscapePressed: panel.cancelPairing()

    onVisibleChanged: {
      if (!visible) return
      btSecretField.text = ""
      panel.pairingError = ""
      if (BluetoothPairingAgent.requestRequiresInput) btFocusTimer.restart()
      else btPairOverlay.forceActiveFocus()
    }

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      anchors.centerIn: parent
      width: parent.width - 32
      spacing: 10

      Text {
        Layout.fillWidth: true
        text: BluetoothPairingAgent.promptTitle.length > 0
              ? BluetoothPairingAgent.promptTitle
              : ("Pair with " + BluetoothPairingAgent.deviceName)
        color: Theme.fg2
        font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
        wrapMode: Text.Wrap
      }

      Text {
        visible: BluetoothPairingAgent.promptMessage.length > 0
        Layout.fillWidth: true
        text: BluetoothPairingAgent.promptMessage
        color: Theme.fg4
        font { family: Theme.fontFamily; pixelSize: 10 }
        wrapMode: Text.Wrap
      }

      // case 1: the agent wants a PIN or passkey typed in
      Rectangle {
        visible: BluetoothPairingAgent.requestRequiresInput
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 8
        color: Theme.bg4
        border.color: btSecretField.activeFocus ? Theme.accent : Theme.borderBg1
        border.width: btSecretField.activeFocus ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        TextInput {
          id: btSecretField
          anchors.fill: parent
          leftPadding: 12
          rightPadding: 12
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 12 }
          echoMode: TextInput.Normal
          verticalAlignment: TextInput.AlignVCenter
          selectByMouse: true
          selectionColor: Theme.accent
          selectedTextColor: Theme.bg
          clip: true
          inputMethodHints: BluetoothPairingAgent.requestNumericInput ? Qt.ImhDigitsOnly : Qt.ImhNone
          validator: BluetoothPairingAgent.requestNumericInput ? intValidator : null
          Keys.onReturnPressed: panel.submitPairing()
          Keys.onEscapePressed: panel.cancelPairing()

          IntValidator { id: intValidator; bottom: 0 }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothPairingAgent.requestNumericInput ? "Enter PIN or passkey..." : "Enter code..."
            color: Theme.fg4
            font: btSecretField.font
            visible: btSecretField.text.length === 0
          }
        }
      }

      // what the field is waiting for, when the submit was refused
      Text {
        visible: panel.pairingError.length > 0
        Layout.fillWidth: true
        text: panel.pairingError
        color: Theme.deleting
        font { family: Theme.fontFamily; pixelSize: 10 }
        wrapMode: Text.Wrap
      }

      // case 2: display-only code / case 3: confirmation of a shown passkey
      Text {
        visible: !BluetoothPairingAgent.requestRequiresInput
                 && BluetoothPairingAgent.displayedCode.length > 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: BluetoothPairingAgent.displayedCode
        color: Theme.fgL
        font { family: Theme.fontFamily; pixelSize: 22; weight: 700 }
        font.letterSpacing: 3
      }

      RowLayout {
        spacing: 8

        Rectangle {
          visible: BluetoothPairingAgent.requestRequiresInput
                  || BluetoothPairingAgent.requestRequiresConfirmation
          Layout.preferredWidth: 80
          Layout.preferredHeight: 30
          radius: 9
          color: pairMA.containsMouse ? Qt.darker(Theme.accent, 1.15) : Theme.accent

          Text {
            anchors.centerIn: parent
            text: BluetoothPairingAgent.requestRequiresInput ? "Pair" : "Confirm"
            color: Theme.fgL
            font { family: Theme.fontFamily; pixelSize: 11 }
          }

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          MouseArea {
            id: pairMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.submitPairing()
          }
        }

        // passive display: acknowledging cancels the pending agent request
        Rectangle {
          visible: !BluetoothPairingAgent.requestRequiresInput
                   && !BluetoothPairingAgent.requestRequiresConfirmation
          Layout.preferredWidth: 80
          Layout.preferredHeight: 30
          radius: 9
          color: pairOkMA.containsMouse ? Qt.darker(Theme.accent, 1.15) : Theme.accent

          Text {
            anchors.centerIn: parent
            text: "OK"
            color: Theme.fgL
            font { family: Theme.fontFamily; pixelSize: 11 }
          }

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          MouseArea {
            id: pairOkMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.submitPairing()
          }
        }

        Rectangle {
          visible: BluetoothPairingAgent.requestRequiresInput
                  || BluetoothPairingAgent.requestRequiresConfirmation
          Layout.preferredWidth: 80
          Layout.preferredHeight: 30
          radius: 9
          color: pairCancelMA.containsMouse ? Theme.focusBg1 : Theme.bg5

          Text {
            anchors.centerIn: parent
            text: BluetoothPairingAgent.requestRequiresConfirmation ? "Reject" : "Cancel"
            color: Theme.fg1
            font { family: Theme.fontFamily; pixelSize: 11 }
          }

          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          MouseArea {
            id: pairCancelMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.cancelPairing()
          }
        }

        Item { Layout.fillWidth: true }
      }
    }
  }
}
