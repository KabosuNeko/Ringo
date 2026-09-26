import IslandBackend

// Power actions strip; all rendering, keys and selection live in MenuStrip.
MenuStrip {
  items: [
    { icon: "󰌾", label: "Lock", action: () => LockController.lock() },
    { icon: "󰤄", label: "Sleep", action: () => NiriController.suspend() },
    { icon: "󰜉", label: "Reboot", action: () => NiriController.reboot() },
    { icon: "󰐥", label: "Shutdown", action: () => NiriController.powerOff() },
    { icon: "󰿅", label: "Logout", action: () => NiriController.quit() }
  ]
}
