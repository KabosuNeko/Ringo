pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import IslandBackend

Singleton {
  id: root

  IpcHandler {
    target: "focusTimer"
    function toggle(): void { root.toggle() }
    function reset(): void { root.reset() }
    function skip(): void { root.skip() }
  }

  property bool running: false
  property string mode: "work" // "work" (45m) or "break" (5m)
  property int workDuration: 45 * 60
  property int breakDuration: 5 * 60
  property int timeLeft: workDuration
  property bool autoDnd: true
  property bool dndWasEnabledBeforeFocus: false

  readonly property string formattedTime: {
    let m = Math.floor(timeLeft / 60)
    let s = timeLeft % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  readonly property real progress: {
    let total = (mode === "work") ? workDuration : breakDuration
    return total > 0 ? (1.0 - (timeLeft / total)) : 0
  }

  signal completed(string finishedMode)

  Timer {
    id: ticker
    interval: 1000
    repeat: true
    running: root.running
    onTriggered: {
      if (root.timeLeft > 1) {
        root.timeLeft -= 1
      } else {
        root.timeLeft = 0
        root.running = false
        root.handleComplete()
      }
    }
  }

  function handleComplete() {
    let finished = root.mode
    if (finished === "work") {
      SoundController.playAlarm()
      Quickshell.execDetached([
        "notify-send", "-u", "critical", "-i", "alarm", "-a", "Ringo Focus",
        "Focus Session Complete! (" + Math.floor(root.workDuration / 60) + " min)",
        "Hết giờ tập trung! Hãy nghỉ ngơi giải lao 5 phút."
      ])
      root.mode = "break"
      root.timeLeft = root.breakDuration
    } else {
      SoundController.playComplete()
      Quickshell.execDetached([
        "notify-send", "-u", "normal", "-i", "alarm", "-a", "Ringo Focus",
        "Break Finished!",
        "Hết giờ nghỉ giải lao! Sẵn sàng cho phiên tập trung mới."
      ])
      root.mode = "work"
      root.timeLeft = root.workDuration
    }
    root.completed(finished)
  }

  function setWorkDuration(minutes): void {
    root.workDuration = minutes * 60
    if (!root.running && root.mode === "work") {
      root.timeLeft = root.workDuration
    }
  }

  function toggle(): void {
    root.running = !root.running
  }

  function reset(): void {
    root.running = false
    root.mode = "work"
    root.timeLeft = root.workDuration
  }

  function skip(): void {
    root.running = false
    if (root.mode === "work") {
      root.mode = "break"
      root.timeLeft = root.breakDuration
    } else {
      root.mode = "work"
      root.timeLeft = root.workDuration
    }
  }
}
