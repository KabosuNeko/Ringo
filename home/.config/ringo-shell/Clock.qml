import Quickshell
import QtQuick

Text {
  text: Qt.formatDateTime(clock.date, Config.clockFormat)
  color: Theme.fg

  font {
    family: Theme.fontFamily
    weight: 500
    pixelSize: 10 * Config.pillScale
    letterSpacing: -0.5
  }
}
