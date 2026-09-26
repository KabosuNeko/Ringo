import Quickshell

// Screen recording strip; all rendering, keys and selection live in MenuStrip.
MenuStrip {
  items: [
    { icon: "󰕾", label: "System", action: () => record("only-sound") },
    { icon: "󰍬", label: "Mic+System", action: () => record("micro") },
    { icon: "󰝟", label: "No Sound", action: () => record("no-sound") }
  ]

  function record(mode: string): void {
    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/record.sh", mode])
  }
}
