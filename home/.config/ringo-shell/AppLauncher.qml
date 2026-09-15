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
    property var categories: ["All", "Internet", "Dev", "Media", "System"]
    property string activeCategory: "All"

    signal closeRequested()

    width: 420
    height: 384
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    scale: shown ? 1 : 0.96
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property var filteredApps: appsCache.filter(a => {
        let q = searchQuery.toLowerCase()
        let matchesSearch = q.length === 0 ||
            a.name.toLowerCase().includes(q) ||
            a.comment.toLowerCase().includes(q)

        if (!matchesSearch) return false
        if (activeCategory === "All") return true

        let cat = (a.entry.categories || []).join(" ").toLowerCase()
        if (activeCategory === "Dev") {
            return cat.includes("development") || cat.includes("programming") || a.name.toLowerCase().includes("code") || a.name.toLowerCase().includes("git")
        }
        if (activeCategory === "Internet") {
            return cat.includes("network") || cat.includes("webbrowser") || cat.includes("chat") || a.name.toLowerCase().includes("browser") || a.name.toLowerCase().includes("discord")
        }
        if (activeCategory === "Media") {
            return cat.includes("audiovideo") || cat.includes("audio") || cat.includes("video") || cat.includes("player") || cat.includes("graphics")
        }
        if (activeCategory === "System") {
            return cat.includes("system") || cat.includes("utility") || cat.includes("settings") || cat.includes("terminal")
        }
        return true
    })

    onFilteredAppsChanged: selectedIndex = 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (root.appsCache.length === 0 || root.shown) loadApps()
        }
    }

    Component.onCompleted: {
        loadApps()
    }

    onShownChanged: {
        if (shown) {
            loadApps()
            searchQuery = ""
            activeCategory = "All"
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Spotlight Search Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 10
            color: Theme.bgD
            border.color: searchInput.activeFocus ? Theme.accent : Theme.cardBorder
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "\uf002"
                    color: searchInput.activeFocus ? Theme.accent : Theme.fg5
                    font { family: Theme.nerdFontFamily; pixelSize: 13 }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 11; weight: 500 }
                    clip: true

                    onTextChanged: root.searchQuery = text

                    Text {
                        text: "Type to search apps..."
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
                        } else if (event.key === Qt.Key_Tab) {
                            let idx = root.categories.indexOf(root.activeCategory)
                            root.activeCategory = root.categories[(idx + 1) % root.categories.length]
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

                Rectangle {
                    radius: 5
                    color: Theme.chipBg
                    implicitHeight: 18
                    implicitWidth: countText.implicitWidth + 8

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: (filteredApps.length === 0 ? "0" : (root.selectedIndex + 1)) + " / " + root.filteredApps.length
                        color: Theme.fg4
                        font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    }
                }
            }
        }

        // Category Filter Chips
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: root.categories

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    radius: 6
                    color: root.activeCategory === modelData
                           ? Theme.accentSoft
                           : (catHover.hovered ? Theme.chipBgHover : Theme.chipBg)
                    border.width: 1
                    border.color: root.activeCategory === modelData ? Theme.accent : Theme.cardBorder
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: root.activeCategory === modelData ? Theme.accent : Theme.fg4
                        font { family: Theme.fontFamily; pixelSize: 9; weight: root.activeCategory === modelData ? 700 : 500 }
                    }

                    HoverHandler { id: catHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeCategory = modelData
                    }
                }
            }
        }

        // Applications List View
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredApps
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            highlightMoveDuration: 80
            spacing: 3

            delegate: Rectangle {
                id: rowDelegate
                width: appList.width
                height: 42
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
                        font { family: Theme.nerdFontFamily; pixelSize: 20 }
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 3
                        Layout.rightMargin: 3
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

        // Keycap Footer
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 4
                Rectangle {
                    radius: 3
                    color: Theme.chipBg
                    border.width: 1
                    border.color: Theme.cardBorder
                    implicitWidth: 18; implicitHeight: 14
                    Text { anchors.centerIn: parent; text: "↵"; color: Theme.fg4; font { pixelSize: 8; weight: 600 } }
                }
                Text { text: "Launch"; color: Theme.fg5; font { family: Theme.fontFamily; pixelSize: 8; weight: 500 } }
            }

            RowLayout {
                spacing: 4
                Rectangle {
                    radius: 3
                    color: Theme.chipBg
                    border.width: 1
                    border.color: Theme.cardBorder
                    implicitWidth: 20; implicitHeight: 14
                    Text { anchors.centerIn: parent; text: "Tab"; color: Theme.fg4; font { pixelSize: 8; weight: 600 } }
                }
                Text { text: "Filter"; color: Theme.fg5; font { family: Theme.fontFamily; pixelSize: 8; weight: 500 } }
            }

            RowLayout {
                spacing: 4
                Rectangle {
                    radius: 3
                    color: Theme.chipBg
                    border.width: 1
                    border.color: Theme.cardBorder
                    implicitWidth: 20; implicitHeight: 14
                    Text { anchors.centerIn: parent; text: "Esc"; color: Theme.fg4; font { pixelSize: 8; weight: 600 } }
                }
                Text { text: "Close"; color: Theme.fg5; font { family: Theme.fontFamily; pixelSize: 8; weight: 500 } }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
