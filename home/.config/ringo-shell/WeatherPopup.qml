import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import IslandBackend

PanelWindow {
  id: weatherWindow

  readonly property real dpi: Config.dpiScale
  property real anchorY: 0
  property bool shown: false

  visible: shown && !LockController.locked
  WlrLayershell.layer: WlrLayershell.Overlay
  WlrLayershell.namespace: "ringo-popup"
  exclusionMode: ExclusionMode.Ignore

  anchors.top: true
  margins.top: anchorY

  implicitWidth: 280 * dpi
  implicitHeight: card.implicitHeight
  color: "transparent"

  readonly property color tileBg: Theme.bg2
  readonly property int tileRadius: 11
  readonly property color dividerColor: Theme.borderBg2
  readonly property color labelText: Theme.fg5
  readonly property color valueText: Theme.fg
  readonly property color secondaryText: Theme.fg3
  readonly property color headerText: Theme.fg2
  readonly property int iconSizeMedium: 13
  readonly property int iconSizeForecast: 16
  readonly property int fontSizeTiny: 8
  readonly property int fontSizeSmall: 9
  readonly property int fontSizeBody: 9
  readonly property int tileSpacing: 8

  Rectangle {
    id: card
    anchors.fill: parent
    implicitHeight: contentCol.implicitHeight + 26 * dpi
    color: Theme.bg
    radius: 20 * dpi

    ColumnLayout {
      id: contentCol
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 14 * dpi
      spacing: 10 * dpi

      RowLayout {
        Layout.fillWidth: true

        Text {
          text: Config.weatherLocation
          color: weatherWindow.headerText
          font.family: Theme.fontFamily
          font.pixelSize: 12 * dpi
          font.weight: 500
          Layout.leftMargin: 3 * dpi
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        Text {
          text: "\uead2"
          color: refreshHover.containsMouse ? Theme.accent : Theme.fg5
          font.family: Config.nerdFontFamily
          font.pixelSize: 13 * dpi
          Behavior on color { ColorAnimation { duration: 100 } }
          MouseArea {
            id: refreshHover
            anchors.fill: parent
            anchors.margins: -6 * dpi
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: WeatherController.refresh()
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 16 * dpi

        Text {
          text: WeatherController.iconGlyph
          color: WeatherController.iconColor
          font.family: Config.nerdFontFamily
          font.pixelSize: 32 * dpi
          Layout.preferredWidth: 45 * dpi
          horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
          spacing: 1 * dpi
          Layout.fillWidth: true
          Text {
            text: WeatherController.loading ? "..."
                : WeatherController.errorMessage.length > 0 ? "—"
                : Math.round(WeatherController.temp) + "°" + (Config.weatherUnits === "metric" ? "C" : "F")
            color: Theme.fgL
            font.family: Theme.fontFamily
            font.pixelSize: 25 * dpi
            font.weight: 500
          }
          Text {
            text: WeatherController.condition
            color: Theme.fg4
            font.family: Theme.fontFamily
            font.pixelSize: weatherWindow.fontSizeBody * dpi
            font.weight: 400
            visible: !WeatherController.loading && WeatherController.errorMessage.length === 0
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: weatherWindow.tileSpacing * dpi
        visible: !WeatherController.loading && WeatherController.errorMessage.length === 0

        Repeater {
          model: [
            { icon: "\ue34e", color: "#f18d41", value: Math.round(WeatherController.feelsLike) + "°", label: "Feels" },
            { icon: "\ue373", color: "#5f99fa", value: WeatherController.humidity + "%", label: "Humidity" },
            { icon: "\ue34b", color: "#54e04b", value: Math.round(WeatherController.windSpeed) + " km/h", label: "Wind" }
          ]
          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62 * dpi
            radius: weatherWindow.tileRadius * dpi
            color: statHover.containsMouse ? Qt.lighter(weatherWindow.tileBg, 1.25) : weatherWindow.tileBg
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
              id: statHover
              anchors.fill: parent
              hoverEnabled: true
            }

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 3 * dpi

              Text {
                text: modelData.icon
                color: modelData.color
                font.family: Config.nerdFontFamily
                font.pixelSize: weatherWindow.iconSizeMedium * dpi
                Layout.alignment: Qt.AlignHCenter
              }

              Text {
                text: modelData.value
                color: weatherWindow.valueText
                font.family: Theme.fontFamily
                font.pixelSize: weatherWindow.fontSizeBody * dpi
                font.weight: 600
                Layout.alignment: Qt.AlignHCenter
              }

              Text {
                text: modelData.label
                color: weatherWindow.labelText
                font.family: Theme.fontFamily
                font.pixelSize: weatherWindow.fontSizeTiny * dpi
                Layout.alignment: Qt.AlignHCenter
              }
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1 * dpi; color: weatherWindow.dividerColor }

      RowLayout {
        Layout.fillWidth: true
        spacing: 0
        visible: !WeatherController.loading && WeatherController.errorMessage.length === 0

        RowLayout {
          spacing: 5 * dpi

          Text {
            text: "\ue34c"
            color: "#ffcd58"
            font.family: Config.nerdFontFamily
            font.pixelSize: weatherWindow.iconSizeMedium * dpi
            Layout.leftMargin: 10 * dpi
          }

          Text {
            text: WeatherController.sunrise
            color: weatherWindow.secondaryText
            font.family: Theme.fontFamily
            font.pixelSize: weatherWindow.fontSizeSmall * dpi
          }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
          Text {
            text: "\ue34d"
            color: "#ff904d"
            font.family: Config.nerdFontFamily
            font.pixelSize: weatherWindow.iconSizeMedium * dpi
          }

          Text {
            text: WeatherController.sunset
            color: weatherWindow.secondaryText
            font.family: Theme.fontFamily
            font.pixelSize: weatherWindow.fontSizeSmall * dpi
            Layout.rightMargin: 10 * dpi
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1 * dpi; color: weatherWindow.dividerColor }

      RowLayout {
        Layout.fillWidth: true
        spacing: weatherWindow.tileSpacing * dpi

        Repeater {
          model: WeatherController.forecast
          delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 5 * dpi

            Text {
              text: Qt.formatDate(new Date(modelData.date), "ddd")
              color: Theme.fg5
              font.family: Theme.fontFamily
              font.pixelSize: weatherWindow.fontSizeTiny * dpi
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: modelData.iconGlyph
              color: modelData.iconColor
              font.family: Config.nerdFontFamily
              font.pixelSize: weatherWindow.iconSizeForecast * dpi
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: Math.round(modelData.maxTemp) + "°/" + Math.round(modelData.minTemp) + "°"
              color: Theme.fg3
              font.family: Theme.fontFamily
              font.pixelSize: weatherWindow.fontSizeTiny * dpi
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }
      }

      Text {
        text: "Updated at " + Qt.formatTime(WeatherController.lastUpdated, "hh:mm")
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: weatherWindow.fontSizeTiny * dpi
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 2 * dpi
      }
    }
  }
}
