import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property string searchQuery: ""
    property var appsCache: []

    signal closeRequested()

    width: 320
    height: 120
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    scale: shown ? 1 : 0.96
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property var filteredApps: searchQuery.length === 0
        ? appsCache
        : appsCache.filter(a =>
            a.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            a.comment.toLowerCase().includes(searchQuery.toLowerCase()))

    onFilteredAppsChanged: selectedIndex = 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (root.appsCache.length === 0 || root.shown) loadApps()
        }
    }

    onShownChanged: {
        if (shown) {
            loadApps()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    function loadApps() {
        let list = []
        let entries = DesktopEntries.applications.values
        for (let i = 0; i < entries.length; i++) {
            let e = entries[i]
            list.push({
                name: e.name,
                comment: e.comment || "",
                icon: e.icon,
                entry: e
            })
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        appsCache = list
    }

    function launchSelected() {
      if (filteredApps.length === 0) return
      const app = filteredApps[selectedIndex].entry
      if (app.runInTerminal) {
         if (!Config.defaultTerminal || Config.defaultTerminal.length === 0) {
             console.log("No defaultTerminal configured, cannot launch this terminal app:", app.name)
             return
         }
         Quickshell.execDetached([Config.defaultTerminal, "-e", "sh", "-c", app.command.join(" ")])
      } else {
         app.execute()
      }
      root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Theme.cardBg
        border.color: Theme.cardBorder
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
          width: parent.width

          Text {
              text: "Applications"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
              Layout.alignment: Qt.AlignLeft
              Layout.leftMargin: 4
          }

          Text {
              id: listCountText
              text: (filteredApps.length === 0 ? "0" : (root.selectedIndex + 1))
                     + " / " + root.filteredApps.length
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
              Layout.alignment: Qt.AlignRight
              Layout.rightMargin: 4
            }
        }

        // Spotlight search bar
        Rectangle {
            width: parent.width
            height: 34
            radius: 9
            color: Theme.bgD
            border.color: searchInput.activeFocus ? Theme.accent : Theme.cardBorder
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "\uf002"
                    color: searchInput.activeFocus ? Theme.accent : Theme.fg5
                    font { family: Theme.nerdFontFamily; pixelSize: 12 }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 11 }
                    clip: true

                    onTextChanged: root.searchQuery = text

                    Text {
                        text: "Type to search..."
                        color: Theme.fg5
                        font: searchInput.font
                        visible: searchInput.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) {
                            if (root.filteredApps.length > 0)
                                root.selectedIndex = (root.selectedIndex + 1) % root.filteredApps.length
                            appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (root.filteredApps.length > 0)
                                root.selectedIndex = root.selectedIndex <= 0
                                    ? root.filteredApps.length - 1
                                    : root.selectedIndex - 1
                            appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launchSelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeRequested()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        ListView {
            id: appList
            width: parent.width
            height: parent.height - 86
            clip: true
            model: root.filteredApps
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            highlightMoveDuration: 80
            spacing: 3

            delegate: Rectangle {
                id: rowDelegate
                width: appList.width
                height: 44
                radius: 8
                color: index === root.selectedIndex
                       ? Theme.chipBgHover
                       : (rowHover.hovered ? Theme.chipBg : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                // Left accent indicator pill
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 18
                    radius: 2
                    color: Theme.accent
                    opacity: index === root.selectedIndex ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        id: appIcon
                        visible: Quickshell.iconPath(modelData.icon, true)
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: Quickshell.iconPath(modelData.icon, true)
                        asynchronous: true
                        scale: index === root.selectedIndex ? 1.08 : (rowHover.hovered ? 1.05 : 1)
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    }

                    Text {
                        visible: !Quickshell.iconPath(modelData.icon, true)
                        text: "󰣆"
                        color: Theme.accent
                        font { family: Theme.nerdFontFamily; pixelSize: 22 }
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: modelData.name
                            color: Theme.fg
                            font { family: Theme.fontFamily; pixelSize: 11; weight: index === root.selectedIndex ? 700 : 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.comment
                            visible: text.length > 0
                            color: Theme.fg5
                            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    id: rowHover
                    property bool hovered: false
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: hovered = true
                    onExited: hovered = false
                    onClicked: {
                        root.selectedIndex = index
                        root.launchSelected()
                    }
                }
              }

            Text {
                anchors.centerIn: parent
                visible: appList.count === 0
                text: "No applications found"
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
            }
        }

        // Footer keyboard hints
        RowLayout {
            width: parent.width
            Item { Layout.fillWidth: true }
            Text {
                text: "↵ Launch   Esc Close"
                color: Theme.fg5
                font { family: Theme.fontFamily; pixelSize: 8; weight: 500 }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
