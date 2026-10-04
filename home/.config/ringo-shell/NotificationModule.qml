import Quickshell
import QtQuick
import IslandBackend

Item {
  id: root

  property var queue: []
  property var current: null
  readonly property bool active: current !== null
  property int displayTime: Config.notificationDisplayTime

  property int _idCounter: 0
  readonly property bool dndEnabled: Notifier.dndEnabled // single source of truth: the backend
  property var notifications: []
  property var notificationsReversed: [] // pre-computed. avoid recomputing per bindig
  property int maxStored: Config.maxNotificationsInStack
  property bool avoidDuplicateNotifications: Config.avoidDuplicateNotifications

  function syncReversed(): void {
    notificationsReversed = notifications.slice().reverse()
  }

  function makeEntry(notif) {
    const entry = {}
    for (let key in notif) {
      entry[key] = notif[key]
    }
    entry.notif = notif
    entry.baseSummary = notif.summary
    entry.count = 1
    entry.receivedTime = new Date()
    entry.tracked = true
    entry._id = _idCounter++
    return entry
  }

  function findDuplicate(notif) {
    for (let i = 0; i < notifications.length; i++) {
      const e = notifications[i]
      if (e.appName === notif.appName &&
          e.baseSummary === notif.summary &&
          e.body === notif.body) {
        return e
      }
    }
    return null
  }

  function enqueue(notif): void {
      if (avoidDuplicateNotifications) {
        const dup = findDuplicate(notif)
        if (dup) {
          dup.count += 1
          dup.summary = dup.baseSummary + " (" + dup.count + ")"
          dup.receivedTime = new Date()

          const idx = notifications.indexOf(dup)
          if (idx !== -1) notifications.splice(idx, 1)
          notifications.push(dup)

          trimStack()
          syncReversed()
          notificationsChanged()
          schedule(dup)
          return
        }
      }

    const entry = makeEntry(notif)
    notifications.push(entry)
    trimStack()
    syncReversed()
    notificationsChanged()
    schedule(entry)
  }

  function advance(): void {
    if (queue.length === 0) { current = null; return }
    current = queue.shift()
    hideTimer.restart()
  }

  // dropped entries are forgotten everywhere they were referenced, so no toast outlives its entry
  function trimStack(): void {
    while (notifications.length > maxStored) {
      const old = notifications.shift()
      if (old.notif) old.notif.tracked = false
      old.tracked = false
      const qidx = queue.indexOf(old)
      if (qidx !== -1) queue.splice(qidx, 1)
    }
  }

  // pending queue is capped like the stack so a burst cannot grow it unbounded
  function schedule(entry): void {
    if (dndEnabled) return
    queue.push(entry)
    while (queue.length > maxStored) queue.shift()
    if (!current) advance()
  }

  function findEntry(target) {
    for (let i = 0; i < notifications.length; i++) {
      const e = notifications[i]
      if (e === target || e.notif === target || e._id === target)
        return i
    }
    return -1
  }

  function dismiss(target): void {
    const idx = findEntry(target)
    if (idx === -1) return
    const entry = notifications[idx]
    notifications.splice(idx, 1)
    if (entry.notif) entry.notif.tracked = false
    entry.tracked = false
    const qidx = queue.indexOf(entry)
    if (qidx !== -1) queue.splice(qidx, 1)
    syncReversed()
    notificationsChanged()
  }

  function clearAll(): void {
    for (let i = 0; i < notifications.length; i++) {
      if (notifications[i].notif) notifications[i].notif.tracked = false
      notifications[i].tracked = false
    }
    notifications = []
    notificationsReversed = []
    queue = []
    current = null
    hideTimer.stop()
    notificationsChanged()
  }

  Timer {
    id: hideTimer
    interval: root.displayTime
    onTriggered: root.advance()
  }
}
