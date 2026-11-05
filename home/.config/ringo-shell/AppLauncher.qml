import Quickshell
import Quickshell.Io
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
    property var resultTypes: ["All", "Apps", "Files", "Web"]
    property string activeCategory: "All"
    property string resultType: "All"

    readonly property bool searching: searchQuery.trim().length > 0
    readonly property var filterChips: searching ? resultTypes : categories
    readonly property string activeFilter: searching ? resultType : activeCategory

    signal closeRequested()

    width: 420
    height: 384
    visible: opacity > 0
    opacity: shown ? 1 : 0

    property var webApps: [
        { key: "chatgpt", name: "ChatGPT", url: "https://chatgpt.com/" },
        { key: "gemini", name: "Gemini", url: "https://gemini.google.com/app" },
        { key: "claude", name: "Claude", url: "https://claude.ai/" },
        { key: "youtube", name: "YouTube", url: "https://youtube.com/" },
        { key: "github", name: "GitHub", url: "https://github.com/" },
        { key: "gmail", name: "Gmail", url: "https://mail.google.com/" }
    ]

    property var appMatches: []
    property var webMatches: []
    property var fileMatches: []
    property var filteredApps: []
    property int fileSearchSeq: 0
    readonly property var currentRow: filteredApps.length > 0
        && selectedIndex >= 0 && selectedIndex < filteredApps.length
        ? filteredApps[selectedIndex] : null
    readonly property string emptyText: !searching ? "No applications found"
        : resultType === "Files" ? "No files found"
        : resultType === "Apps" ? "No applications found"
        : "No web results"

    Process {
        id: fileSearch
        property int seq: 0
        stdout: StdioCollector {
            id: fileSearchOut
            waitForEnd: true
        }
        onExited: (code, status) => {
            if (seq !== root.fileSearchSeq || code !== 0) return
            const rows = []
            const paths = fileSearchOut.text.split("\u0000")
            for (let i = 0; i < paths.length; i++) {
                const path = paths[i]
                if (path.length === 0) continue
                const slash = path.lastIndexOf("/")
                rows.push({
                    name: path.substring(slash + 1),
                    comment: "File · " + path.substring(0, slash),
                    icon: "text-x-generic",
                    entry: null,
                    file: path
                })
            }
            root.fileMatches = rows
            root.applyResults()
        }
    }

    Timer {
        id: searchDebounce
        interval: 60
        onTriggered: {
            const category = root.searching ? "All" : root.activeCategory
            root.appMatches = FuzzySearch.filterAndSort(root.appsCache, root.searchQuery, category)
            root.webMatches = root.resolveWebApps(root.searchQuery)
            root.fileMatches = []
            root.applyResults()
            root.runFileSearch()
        }
    }

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

        if (/^[a-zA-Z]+:\/\//.test(expr) || expr.startsWith("/") || expr.startsWith("~")) return null

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
                subtitle: "Press Enter to search with Firefox",
                icon: "\uf002",
                query: q
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

        if (filteredApps.length === 0 && evaluateMath(text) === null
            && (!root.searching || root.resultType === "All" || root.resultType === "Web")) {
            return {
                type: "search",
                title: "Search Web: \"" + t + "\"",
                subtitle: "Press Enter to search with Firefox",
                icon: "\uf002",
                query: t
            }
        }

        return null
    }

    onFilteredAppsChanged: selectedIndex = 0
    onActiveCategoryChanged: searchDebounce.restart()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            loadApps()
        }
    }

    Component.onCompleted: {
        loadApps()
    }

    onShownChanged: {
        if (shown) {
            loadApps()
            searchQuery = initialQuery
            activeCategory = "All"
            resultType = "All"
            searchInput.text = initialQuery
            initialQuery = ""
            searchDebounce.triggered()
            selectedIndex = 0
            searchInput.forceActiveFocus()
        } else {
            // A file search can outlive the launcher; stop it so a broad fd
            // scan does not keep consuming CPU/IO after the UI is gone.
            searchDebounce.stop()
            fileSearch.running = false
            root.fileSearchSeq++
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

    function resolveWebApps(query) {
        let q = query.trim().toLowerCase()
        if (q.length < 2) return []
        let rows = []
        for (let i = 0; i < webApps.length; i++) {
            let w = webApps[i]
            if (w.key.indexOf(q) < 0 && w.name.toLowerCase().indexOf(q) < 0) continue
            let native = findNativeEntry(w.key)
            rows.push({
                name: w.name,
                comment: w.name + (native !== null ? " (app)" : " (web)"),
                icon: native !== null ? native.icon : "",
                entry: null,
                web: { url: w.url, native: native }
            })
        }
        return rows
    }

    function findNativeEntry(key) {
        let k = key.toLowerCase()
        for (let i = 0; i < appsCache.length; i++) {
            let entry = appsCache[i].entry
            let id = entry.id ? entry.id.toLowerCase() : ""
            if (id.indexOf(k) >= 0 || appsCache[i].name.toLowerCase().indexOf(k) >= 0) return entry
        }
        return null
    }

    function rowKind(row): string {
        if (row.file) return "Files"
        if (row.web) return "Web"
        return "Apps"
    }

    function applyResults(): void {
        let rows = root.rankResults(
            root.appMatches.concat(root.fileMatches),
            root.webMatches,
            root.searchQuery
        )
        if (root.searching && root.resultType !== "All")
            rows = rows.filter(r => root.rowKind(r) === root.resultType)
        root.filteredApps = rows
    }

    function selectFilter(name: string): void {
        if (root.searching) {
            root.resultType = name
            root.applyResults()
        } else {
            root.activeCategory = name
            searchDebounce.restart()
        }
    }

    function cycleFilter(): void {
        const list = root.filterChips
        const current = list.indexOf(root.activeFilter)
        root.selectFilter(list[(current + 1) % list.length])
    }

    function runFileSearch(): void {
        const q = searchQuery.trim()
        const skip = q.length < 2
            || q.startsWith("?") || q.startsWith("=")
            || /^(https?:|\/|~)/i.test(q)
        root.fileSearchSeq++
        fileSearch.seq = root.fileSearchSeq
        fileSearch.running = false
        root.fileMatches = []
        if (skip) {
            root.applyResults()
            return
        }

        fileSearch.command = [
            "fd", "--type", "f", "--hidden", "--color", "never",
            "--fixed-strings", "--ignore-case", "--absolute-path", "--print0",
            "--max-results", "24",
            "--exclude", ".git", "--exclude", ".cache",
            "--exclude", ".mozilla", "--exclude", "node_modules",
            "--exclude", ".venv", "--exclude", "target", "--exclude", "build",
            "--", q, Quickshell.env("HOME")
        ]
        fileSearch.running = true
    }

    // Exact name hits stay on top, then the web apps, then the fuzzy leftovers.
    function rankResults(apps, webs, query) {
        if (webs.length === 0) return apps
        let q = query.trim().toLowerCase()
        let exact = []
        let rest = []
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].name.toLowerCase() === q) exact.push(apps[i])
            else rest.push(apps[i])
        }
        let rows = []
        for (let i = 0; i < webs.length; i++) {
            let native = webs[i].web.native
            let shadowed = false
            if (native !== null) {
                for (let j = 0; j < exact.length; j++) {
                    if (exact[j].entry.id === native.id) shadowed = true
                }
            }
            if (!shadowed) rows.push(webs[i])
        }
        return exact.concat(rows, rest)
    }

    function launchEntry(app) {
      if (app.runInTerminal) {
         if (!Config.defaultTerminal || Config.defaultTerminal.length === 0) return
         // argv stays a list so paths with spaces survive; app.command is a QML sequence
         let argv = [Config.defaultTerminal, "-e"]
         for (let i = 0; i < app.command.length; i++) argv.push(app.command[i])
         Quickshell.execDetached(argv)
      } else {
         app.execute()
      }
    }

    function searchWeb(query) {
      // Firefox resolves --search with the user's configured default engine.
      Quickshell.execDetached(["firefox", "--search", query])
    }

    function launchSelected() {
      if (mathResult !== null) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + mathResult.result + "' | wl-copy"])
        Notifier.post("Calculated: " + mathResult.result,
                      mathResult.expression + " = " + mathResult.result + " (copied to clipboard)",
                      "accessories-calculator", "Ringo Calculator")
        root.closeRequested()
        return
      }

      if (specialAction !== null && (filteredApps.length === 0 || searchQuery.startsWith("?") || searchQuery.startsWith("http"))) {
        if (specialAction.type === "search") searchWeb(specialAction.query)
        else Quickshell.execDetached(["xdg-open", specialAction.target])
        root.closeRequested()
        return
      }

      if (filteredApps.length === 0) return
      const row = filteredApps[selectedIndex]
      if (row.file) {
        Quickshell.execDetached(["xdg-open", row.file])
      } else if (row.web) {
        if (row.web.native) launchEntry(row.web.native)
        else Quickshell.execDetached(["xdg-open", row.web.url])
      } else {
        launchEntry(row.entry)
      }
      root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusXl
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
            radius: Theme.radiusLg
            color: Theme.bgD
            border.color: searchInput.activeFocus ? Theme.accent : Theme.cardBorder
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "\uf002"
                    color: searchInput.activeFocus ? Theme.accent : Theme.fg5
                    font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
                    Behavior on color { ColorAnimation { duration: Theme.motionBase } }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: 500 }
                    clip: true

                    onTextChanged: {
                        root.searchQuery = text
                        if (text.trim().length === 0) root.resultType = "All"
                        searchDebounce.restart()
                    }

                    Text {
                        text: "Search apps, files, web..."
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
                            root.cycleFilter()
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
                    radius: Theme.radiusSm
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
                        font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 600 }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.searching
                ? (root.mathResult === null
                    && !(root.specialAction && root.specialAction.type === "url"))
                : !root.hasSpecialCard

            Repeater {
                model: root.filterChips

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    radius: Theme.radiusSm
                    color: root.activeFilter === modelData
                           ? Theme.accentSoft
                           : (catHover.hovered ? Theme.chipBgHover : Theme.chipBg)
                    border.width: 1
                    border.color: root.activeFilter === modelData ? Theme.accent : Theme.cardBorder
                    Behavior on color { ColorAnimation { duration: Theme.motionBase } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionBase } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: root.activeFilter === modelData ? Theme.accent : Theme.fg4
                        font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: root.activeFilter === modelData ? 700 : 500 }
                    }

                    HoverHandler { id: catHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectFilter(modelData)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.hasSpecialCard ? 50 : 0
            visible: root.hasSpecialCard
            radius: Theme.radiusLg
            color: root.mathResult !== null ? Theme.accentSoft : Theme.chipBgHover
            border.width: 1
            border.color: root.mathResult !== null ? Theme.accent : Theme.cardBorder
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easeOut } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: Theme.radiusMd
                    color: root.mathResult !== null ? Theme.accent : Theme.chipBg

                    Text {
                        anchors.centerIn: parent
                        text: root.mathResult !== null ? "\uf1ec" : (root.specialAction ? root.specialAction.icon : "\uf002")
                        color: root.mathResult !== null ? Theme.bg : Theme.accent
                        font { family: Theme.nerdFontFamily; pixelSize: Theme.fontLg }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.mathResult !== null ? root.mathResult.expression : (root.specialAction ? root.specialAction.title : "")
                        color: root.mathResult !== null ? Theme.fg4 : Theme.fg
                        font { family: Theme.fontFamily; pixelSize: root.mathResult !== null ? Theme.fontXs : Theme.fontSm; weight: root.mathResult !== null ? 500 : 600 }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.mathResult !== null ? ("= " + root.mathResult.result) : (root.specialAction ? root.specialAction.subtitle : "")
                        color: root.mathResult !== null ? Theme.accent : Theme.fg5
                        font { family: Theme.fontFamily; pixelSize: root.mathResult !== null ? Theme.fontLg : Theme.fontXs; weight: root.mathResult !== null ? 700 : 400 }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    radius: Theme.radiusSm
                    color: root.mathResult !== null ? Theme.accent : Theme.chipBg
                    border.width: root.mathResult !== null ? 0 : 1
                    border.color: Theme.cardBorder
                    implicitHeight: 22
                    implicitWidth: actionBtnText.implicitWidth + 12

                    Text {
                        id: actionBtnText
                        anchors.centerIn: parent
                        text: root.mathResult !== null ? "↵ Copy"
                            : root.specialAction !== null
                                ? (root.specialAction.type === "url" ? "↵ Open" : "↵ Search")
                                : (root.currentRow && (root.currentRow.file || root.currentRow.web) ? "↵ Open" : "↵ Launch")
                        color: root.mathResult !== null ? Theme.bg : Theme.fg
                        font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 600 }
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
            // don't incubate delegates while the launcher is hidden
            model: root.shown ? root.filteredApps : null
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            highlightMoveDuration: Theme.motionFast
            spacing: 3

            delegate: Rectangle {
                width: appList.width
                height: 42
                radius: Theme.radiusMd
                color: index === root.selectedIndex
                       ? Theme.chipBgHover
                       : (rowHover.hovered ? Theme.chipBg : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.motionBase } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 18
                    radius: Theme.radiusXs
                    color: Theme.accent
                    opacity: index === root.selectedIndex ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        id: appIconImg
                        readonly property string resolvedIcon: Quickshell.iconPath(modelData.icon, true)
                        visible: resolvedIcon
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: resolvedIcon
                        asynchronous: true
                    }

                    Text {
                        visible: !appIconImg.resolvedIcon
                        text: modelData.file ? "\uf15b" : (modelData.web ? "\uf0ac" : "󰣆")
                        color: Theme.accent
                        font { family: Theme.nerdFontFamily; pixelSize: Theme.fontXxl }
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
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSm; weight: index === root.selectedIndex ? 700 : 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.comment
                            visible: text.length > 0
                            color: Theme.fg5
                            font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 400 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        readonly property string kind: modelData.file ? "FILE"
                            : modelData.web ? "WEB" : "APP"
                        text: kind
                        color: Theme.fg5
                        font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 700; letterSpacing: 0.8 }
                        Layout.alignment: Qt.AlignVCenter
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
                text: root.emptyText
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 500 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 4
                Rectangle {
                    radius: Theme.radiusXs
                    color: Theme.chipBg
                    border.width: 1
                    border.color: Theme.cardBorder
                    implicitWidth: 18; implicitHeight: 14
                    Text { anchors.centerIn: parent; text: "↵"; color: Theme.fg4; font { pixelSize: Theme.fontXs; weight: 600 } }
                }
                Text {
                    text: root.mathResult !== null ? "Copy"
                        : root.specialAction !== null
                            ? (root.specialAction.type === "url" ? "Open" : "Search")
                            : (root.currentRow && (root.currentRow.file || root.currentRow.web) ? "Open" : "Launch")
                    color: Theme.fg5
                    font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 500 }
                }
            }

            RowLayout {
                spacing: 4
                Rectangle {
                    radius: Theme.radiusXs
                    color: Theme.chipBg
                    border.width: 1
                    border.color: Theme.cardBorder
                    implicitWidth: 20; implicitHeight: 14
                    Text { anchors.centerIn: parent; text: "Tab"; color: Theme.fg4; font { pixelSize: Theme.fontXs; weight: 600 } }
                }
                Text { text: "Filter"; color: Theme.fg5; font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 500 } }
            }

            RowLayout {
                spacing: 4
                Rectangle {
                    radius: Theme.radiusXs
                    color: Theme.chipBg
                    border.width: 1
                    border.color: Theme.cardBorder
                    implicitWidth: 20; implicitHeight: 14
                    Text { anchors.centerIn: parent; text: "Esc"; color: Theme.fg4; font { pixelSize: Theme.fontXs; weight: 600 } }
                }
                Text { text: "Close"; color: Theme.fg5; font { family: Theme.fontFamily; pixelSize: Theme.fontXs; weight: 500 } }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
