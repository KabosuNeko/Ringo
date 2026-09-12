import QtQuick
import IslandBackend

Item {
  id: root
  signal toggleWeather()

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property string weatherFg: Theme.fg4
  property int fontSize: 10 * Config.pillScale
  property bool clickable: true

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Text {
      text: WeatherController.iconGlyph
      color: weatherFg
      font { family: Config.nerdFontFamily; pixelSize: root.fontSize }
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: WeatherController.loading ? "--" : Math.round(WeatherController.temp) + "°" + (Config.weatherUnits === "metric" ? "C" : "F")
      color: weatherFg
      font { family: Theme.fontFamily; pixelSize: root.fontSize; weight: 500 }
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.clickable
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.toggleWeather()
  }
}
