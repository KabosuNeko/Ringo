import Quickshell
import QtQuick

Text {
  id: root

  property int fontSize: 10 * Config.pillScale

  text: Qt.formatDateTime(clock.date, Config.clockFormat)
  color: Theme.fg

  font {
    family: Theme.fontFamily
    weight: 600
    pixelSize: root.fontSize
    letterSpacing: -0.2
  }
}
