import QtQuick
import Quickshell
import Quickshell.Io

// Wired / VPN state from nmcli for SettingsPanel. Wi-Fi and Bluetooth have
// their own controllers; this only fills the two rows the shell otherwise cannot see.
Scope {
  id: model

  property var ethernetDevices: []
  property var vpnConnections: []
  property int vpnIndex: 0
  property bool networkBusy: false
  property string networkError: ""

  function refreshNetwork(): void {
    if (model.networkBusy) return
    model.networkBusy = true
    model.networkError = ""
    networkDevices.running = true
    networkTimeout.restart()
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
    model.ethernetDevices = rows
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
    model.vpnConnections = rows
    if (model.vpnIndex >= rows.length) model.vpnIndex = 0
  }

  function ethernetActive(): bool {
    for (let i = 0; i < model.ethernetDevices.length; i++)
      if (model.ethernetDevices[i].state === "connected") return true
    return false
  }

  function ethernetLabel(): string {
    if (model.ethernetDevices.length === 0)
      return model.networkError.length > 0 ? "Unavailable" : "Not present"
    for (let i = 0; i < model.ethernetDevices.length; i++) {
      const dev = model.ethernetDevices[i]
      if (dev.state === "connected")
        return dev.connection.length > 0 ? dev.connection : "Connected"
    }
    const first = model.ethernetDevices[0]
    return first.state === "unavailable" ? "Unavailable" : "Disconnected"
  }

  function toggleEthernet(): void {
    const dev = model.ethernetDevices[0]
    if (!dev) return
    model.runNetworkAction([
      "nmcli", "device",
      model.ethernetActive() ? "disconnect" : "connect",
      dev.device
    ])
  }

  function activeVpn(): var {
    for (let i = 0; i < model.vpnConnections.length; i++)
      if (model.vpnConnections[i].active) return model.vpnConnections[i]
    return null
  }

  function vpnLabel(): string {
    if (model.networkError.length > 0) return "Error"
    const active = model.activeVpn()
    if (active) return active.name
    if (model.vpnConnections.length === 0) return "None"
    const vpn = model.vpnConnections[model.vpnIndex]
    return vpn ? vpn.name + " · off" : "Off"
  }

  function toggleVpn(): void {
    const active = model.activeVpn()
    if (active) {
      model.runNetworkAction(["nmcli", "connection", "down", active.name])
      return
    }
    const vpn = model.vpnConnections[model.vpnIndex]
    if (vpn) model.runNetworkAction(["nmcli", "connection", "up", vpn.name])
  }

  function cycleVpn(): void {
    if (model.vpnConnections.length < 2 || model.activeVpn() !== null) return
    model.vpnIndex = (model.vpnIndex + 1) % model.vpnConnections.length
  }

  function runNetworkAction(argv): void {
    model.networkError = ""
    networkAction.command = argv
    networkAction.running = true
  }

  Timer {
    id: networkTimeout
    interval: 5000
    onTriggered: {
      if (networkDevices.running) networkDevices.running = false
      if (networkConnections.running) networkConnections.running = false
      model.networkBusy = false
      model.networkError = "NetworkManager did not respond"
    }
  }

  Process {
    id: networkDevices
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    environment: ({ LC_ALL: "C" })
    stdout: StdioCollector { id: networkDevicesOut; waitForEnd: true }
    stderr: StdioCollector { id: networkDevicesErr; waitForEnd: true }

    onExited: (code, status) => {
      networkTimeout.stop()
      if (code !== 0) {
        model.networkError = networkDevicesErr.text.trim() || ("nmcli exited with " + code)
        model.networkBusy = false
        return
      }
      model.parseNetworkDevices(networkDevicesOut.text)
      networkConnections.running = true
      networkTimeout.restart()
    }
  }

  Process {
    id: networkConnections
    command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]
    environment: ({ LC_ALL: "C" })
    stdout: StdioCollector { id: networkConnectionsOut; waitForEnd: true }
    stderr: StdioCollector { id: networkConnectionsErr; waitForEnd: true }

    onExited: (code, status) => {
      networkTimeout.stop()
      if (code !== 0)
        model.networkError = networkConnectionsErr.text.trim() || ("nmcli exited with " + code)
      else
        model.parseNetworkConnections(networkConnectionsOut.text)
      model.networkBusy = false
    }
  }

  Process {
    id: networkAction
    environment: ({ LC_ALL: "C" })
    stderr: StdioCollector { id: networkActionErr; waitForEnd: true }

    onExited: (code, status) => {
      if (code !== 0)
        model.networkError = networkActionErr.text.trim() || ("nmcli exited with " + code)
      model.refreshNetwork()
    }
  }
}
