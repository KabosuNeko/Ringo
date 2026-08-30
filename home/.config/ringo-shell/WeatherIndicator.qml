import QtQuick
import IslandBackend

Item {
  id: root
  signal toggleWeather()

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property string weatherFg: Theme.fg4

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Text {
      text: WeatherController.iconGlyph
      color: weatherFg
      font { family: Config.nerdFontFamily; pixelSize: 12 }
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: WeatherController.loading ? "--" : Math.round(WeatherController.temp) + "°" + (Config.weatherUnits === "metric" ? "C" : "F")
      color: weatherFg
      font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggleWeather()
  }
}
