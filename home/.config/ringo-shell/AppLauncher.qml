import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import IslandBackend

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property string searchQuery: ""
    property string initialQuery: ""
    property var appsCache: []
    property var categories: ["All", "Internet", "Dev", "Media", "System"]
    property string activeCategory: "All"

    signal closeRequested()

    width: 420
    height: 384
    visible: opacity > 0
    opacity: shown ? 1 : 0

    property var filteredApps: FuzzySearch.filterAndSort(appsCache, searchQuery, activeCategory)

    readonly property var mathResult: evaluateMath(searchQuery)
    readonly property var specialAction: getSpecialAction(searchQuery)
    readonly property bool hasSpecialCard: mathResult !== null || specialAction !== null

    function evaluateMath(text) {
        if (!text) return null
        let t = text.trim()
        if (t.length < 2) return null
        if (t.startsWith("?")) return null

        let isExplicit = t.startsWith("=")
        let expr = isExplicit ? t.slice(1).trim() : t
        if (expr.length === 0) return null

        // Quick rejection for paths/URLs
        if (/^[a-zA-Z]+:\/\//.test(expr) || expr.startsWith("/") || expr.startsWith("~")) return null

        // Must have at least one math operator or starts with '='
        let hasMathOp = /[+\-*/%^]/.test(expr) || /^(sqrt|abs|sin|cos|tan|log|pow)\b/i.test(expr)
        if (!isExplicit && !hasMathOp) return null

        let clean = expr
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\^/g, "**")
            .replace(/\bpi\b/gi, "Math.PI")
            .replace(/\be\b/gi, "Math.E")
            .replace(/\bsqrt\(([^)]+)\)/gi, "Math.sqrt($1)")
            .replace(/\babs\(([^)]+)\)/gi, "Math.abs($1)")
            .replace(/\bround\(([^)]+)\)/gi, "Math.round($1)")
            .replace(/\bpow\(([^,]+),([^)]+)\)/gi, "Math.pow($1,$2)")
            .replace(/(\d+(?:\.\d+)?)\s*%\s*(?:of)?\s*(\d+(?:\.\d+)?)/gi, "($1/100 * $2)")
            .replace(/(\d+(?:\.\d+)?)\s*%/g, "($1/100)")

        let check = clean.replace(/Math\.(PI|E|sqrt|abs|round|pow|sin|cos|tan|log)/g, "")
        if (/[^0-9.+\-*/%(),\s]/.test(check)) return null

        try {
            let res = Function('"use strict"; return (' + clean + ')')()
            if (typeof res === 'number' && !isNaN(res) && isFinite(res)) {
                let formatted = (Math.round(res * 1000000) / 1000000).toString()
                return {
                    expression: expr,
                    result: formatted
                }
            }
        } catch (e) {
            return null
        }
        return null
    }

    function getSpecialAction(text) {
        if (!text) return null
        let t = text.trim()
        if (t.length === 0) return null

        if (t.startsWith("?")) {
            let q = t.slice(1).trim()
            return {
                type: "search",
                title: "Search Web: " + (q.length > 0 ? "\"" + q + "\"" : "..."),
                subtitle: "Press Enter to search in browser",
                icon: "\uf002",
                target: "https://www.google.com/search?q=" + encodeURIComponent(q)
            }
        }

        if (/^https?:\/\//i.test(t) || /^[a-zA-Z0-9.-]+\.(com|org|net|io|dev|app|edu|gov|vn)(:[0-9]+)?(\/.*)?$/i.test(t) || /^localhost(:[0-9]+)?(\/.*)?$/i.test(t)) {
            let url = /^https?:\/\//i.test(t) ? t : "http://" + t
            return {
                type: "url",
                title: "Open URL: " + t,
                subtitle: "Press Enter to open in browser",
                icon: "\uf0c1",
                target: url
            }
        }

        if (filteredApps.length === 0 && evaluateMath(text) === null) {
            return {
                type: "search",
                title: "Search Web: \"" + t + "\"",
                subtitle: "No local apps found - press Enter to search",
                icon: "\uf002",
                target: "https://www.google.com/search?q=" + encodeURIComponent(t)
            }
        }

        return null
    }

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
            if (appsCache.length === 0) loadApps()
            searchQuery = initialQuery
            activeCategory = "All"
            searchInput.text = initialQuery
            initialQuery = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    function setSearchText(t) {
        searchInput.text = t
        root.searchQuery = t
    }

    function loadApps() {
        let list = []
        let seenIds = {}
        let seenNames = {}
        let entries = DesktopEntries.applications.values || []

        for (let i = 0; i < entries.length; i++) {
            let e = entries[i]
            if (!e || !e.name || e.name.trim().length === 0) continue
            if (e.noDisplay) continue

            // Deduplicate by entry ID (e.g. "antigravity", "futon", "xfce4-about")
            let idKey = e.id ? e.id.toLowerCase().trim() : ""
            if (idKey.length > 0 && seenIds[idKey]) continue

            // Deduplicate by Name (e.g. across user/system dirs or quickshell live reloads)
            let nameKey = e.name.toLowerCase().trim()
            if (seenNames[nameKey]) continue

            if (idKey.length > 0) seenIds[idKey] = true
            seenNames[nameKey] = true

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
      if (mathResult !== null) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + mathResult.result + "' | wl-copy"])
        Quickshell.execDetached(["notify-send", "-i", "accessories-calculator", "-a", "Ringo Calculator", "Calculated: " + mathResult.result, mathResult.expression + " = " + mathResult.result + " (copied to clipboard)"])
        root.closeRequested()
        return
      }

      if (specialAction !== null && (filteredApps.length === 0 || searchQuery.startsWith("?") || searchQuery.startsWith("http"))) {
        Quickshell.execDetached(["xdg-open", specialAction.target])
        root.closeRequested()
        return
      }

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
                        text: root.mathResult !== null ? "Math"
                            : (root.specialAction && root.filteredApps.length === 0 ? "Web"
                            : ((filteredApps.length === 0 ? "0" : (root.selectedIndex + 1)) + " / " + root.filteredApps.length))
                        color: root.mathResult !== null ? Theme.accent : Theme.fg4
                        font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: !root.hasSpecialCard

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

        // Special Action Card (Inline Math Calculator / Web Search / Direct URL)
        Rectangle {
            id: specialCard
            Layout.fillWidth: true
            Layout.preferredHeight: root.hasSpecialCard ? 50 : 0
            visible: root.hasSpecialCard
            radius: 10
            color: root.mathResult !== null ? Theme.accentSoft : Theme.chipBgHover
            border.width: 1
            border.color: root.mathResult !== null ? Theme.accent : Theme.cardBorder
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 8
                    color: root.mathResult !== null ? Theme.accent : Theme.chipBg

                    Text {
                        anchors.centerIn: parent
                        text: root.mathResult !== null ? "\uf1ec" : (root.specialAction ? root.specialAction.icon : "\uf002")
                        color: root.mathResult !== null ? Theme.bg : Theme.accent
                        font { family: Theme.nerdFontFamily; pixelSize: 14 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.mathResult !== null ? root.mathResult.expression : (root.specialAction ? root.specialAction.title : "")
                        color: root.mathResult !== null ? Theme.fg4 : Theme.fg
                        font { family: Theme.fontFamily; pixelSize: root.mathResult !== null ? 10 : 11; weight: root.mathResult !== null ? 500 : 600 }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.mathResult !== null ? ("= " + root.mathResult.result) : (root.specialAction ? root.specialAction.subtitle : "")
                        color: root.mathResult !== null ? Theme.accent : Theme.fg5
                        font { family: Theme.fontFamily; pixelSize: root.mathResult !== null ? 14 : 9; weight: root.mathResult !== null ? 700 : 400 }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    radius: 5
                    color: root.mathResult !== null ? Theme.accent : Theme.chipBg
                    border.width: root.mathResult !== null ? 0 : 1
                    border.color: Theme.cardBorder
                    implicitHeight: 22
                    implicitWidth: actionBtnText.implicitWidth + 12

                    Text {
                        id: actionBtnText
                        anchors.centerIn: parent
                        text: root.mathResult !== null ? "↵ Copy" : (root.specialAction && root.specialAction.type === "url" ? "↵ Open" : "↵ Search")
                        color: root.mathResult !== null ? Theme.bg : Theme.fg
                        font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchSelected()
            }
        }

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
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
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
                visible: appList.count === 0 && !root.hasSpecialCard
                text: "No applications found"
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
            }
        }

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
                Text {
                    text: root.mathResult !== null ? "Copy"
                        : (root.specialAction && root.filteredApps.length === 0 ? "Open" : "Launch")
                    color: Theme.fg5
                    font { family: Theme.fontFamily; pixelSize: 8; weight: 500 }
                }
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
