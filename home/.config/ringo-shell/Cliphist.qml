import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import IslandBackend

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property string searchQuery: ""
    property string deletingId: ""
    property string collapsingId: ""
    property bool imgFullPreview: false
    property int previewSlideDir: 1  // 1 = down/next, -1 = up/prev

    signal closeRequested()
    signal previewToggled(bool active)

    visible: opacity > 0
    opacity: shown ? 1 : 0

    onShownChanged: {
        if (shown) {
            CliphistModel.refresh()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    onSearchQueryChanged: {
        CliphistModel.searchQuery = searchQuery
        selectedIndex = 0
    }

    function refresh() {
        CliphistModel.refresh()
    }

    function copySelected() {
        if (CliphistModel.count === 0) return
        CliphistModel.copyItem(selectedIndex)
        root.closeRequested()
    }

    function deleteSelected() {
        if (CliphistModel.count === 0) return
        let entry = CliphistModel.get(selectedIndex)
        root.deletingId = entry.id
        holdRedTimer.entryId = entry.id
        holdRedTimer.restart()
    }

    function imgFullPreviewSelected() {
        let entry = CliphistModel.count > 0 ? CliphistModel.get(root.selectedIndex) : null
        if (!entry || !entry.imagePath) return

        imgFullPreview = !imgFullPreview
        root.previewToggled(imgFullPreview)
    }

    function findAdjacentImageIndex(direction) {
        if (CliphistModel.count === 0) return -1
        let idx = root.selectedIndex
        for (let i = 0; i < CliphistModel.count; i++) {
            idx = (idx + direction + CliphistModel.count) % CliphistModel.count
            let e = CliphistModel.get(idx)
            if (e && e.imagePath) return idx
        }
        return -1
    }

    Timer {
        id: holdRedTimer
        property string entryId: ""
        interval: 160
        repeat: false
        onTriggered: {
            root.collapsingId = entryId
            removeTimer.entryId = entryId
            removeTimer.restart()
        }
    }

    Timer {
        id: removeTimer
        property string entryId: ""
        interval: 220  // matches the collapse animation on below
        repeat: false
        onTriggered: {
            let currentIdx = root.selectedIndex
            let savedContentY = listView.contentY

            CliphistModel.deleteById(entryId)

            root.deletingId = ""
            root.collapsingId = ""

            let newLength = CliphistModel.count
            if (newLength === 0) root.selectedIndex = -1
            else if (currentIdx >= newLength) root.selectedIndex = newLength - 1
            else root.selectedIndex = currentIdx

            Qt.callLater(() => {
                let maxY = Math.max(0, listView.contentHeight - listView.height)
                listView.contentY = Math.min(savedContentY, maxY)
                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
            })
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: imgFullPreview ? 24 : 18
        color: Theme.bgD1
        border.color: Theme.borderBg2
        border.width: 1
        clip: true
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        clip: true

        RowLayout {
          width: parent.width
          visible: !imgFullPreview

          Text {
              text: "Clipboard History"
              color: Theme.fg2
              font { family: Theme.fontFamily; pixelSize: 11; weight: 700 }
              Layout.alignment: Qt.AlignLeft
              Layout.leftMargin: 4
          }

          Text {
            id: listCountText
            text: (CliphistModel.count === 0 ? 0 : root.selectedIndex + 1)
                   + " / " + CliphistModel.count + " (" + CliphistModel.totalCount + ")"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 6
          }
        }

        Rectangle {
            width: parent.width
            height: 26
            radius: 6
            color: Theme.bg4
            border.color: searchInput.activeFocus ? Theme.borderBgFocus : Theme.borderBg
            border.width: 1
            visible: !imgFullPreview

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10 }
                clip: true
                readOnly: imgFullPreview

                onTextChanged: root.searchQuery = text

                Text {
                    text: "search clips..."
                    color: Theme.fg3
                    font: searchInput.font
                    visible: searchInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        if (imgFullPreview) {
                            let next = root.findAdjacentImageIndex(1)
                            if (next !== -1) {
                                root.previewSlideDir = 1
                                root.selectedIndex = next
                            }
                        } else if (CliphistModel.count > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % CliphistModel.count
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (imgFullPreview) {
                            let prev = root.findAdjacentImageIndex(-1)
                            if (prev !== -1) {
                                root.previewSlideDir = -1
                                root.selectedIndex = prev
                            }
                        } else if (CliphistModel.count > 0) {
                            root.selectedIndex = root.selectedIndex <= 0 ? CliphistModel.count - 1 : root.selectedIndex - 1
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.copySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        if (imgFullPreview) {
                            imgFullPreview = false
                            previewToggled(false)
                        } else {
                            root.closeRequested()
                        }
                    } else if (event.key === Qt.Key_Delete) {
                        root.deleteSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        root.imgFullPreviewSelected()
                        event.accepted = true
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height
            visible: imgFullPreview

            Loader {
                anchors.fill: parent
                active: imgFullPreview
                asynchronous: true

                sourceComponent: Component {
                    Item {
                        anchors.fill: parent

                        readonly property string currentEntryId: {
                            let idx = root.selectedIndex
                            if (idx < 0 || idx >= CliphistModel.count) return ""
                            return CliphistModel.get(idx).id
                        }

                        Image {
                            id: previewImage
                            width: parent.width - 15
                            height: parent.height - 25
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 25
                            anchors.horizontalCenter: parent.horizontalCenter
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(500, 500)

                            opacity: currentEntryId === root.collapsingId ? 0 : (status === Image.Ready ? 1 : 0)
                            scale: currentEntryId === root.collapsingId ? 0.8 : 1
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            source: {
                                let idx = root.selectedIndex
                                if (idx < 0 || idx >= CliphistModel.count) return ""
                                let entry = CliphistModel.get(idx)
                                return entry.imagePath ? ("file://" + entry.imagePath) : ""
                            }

                            property real slideY: 0
                            transform: Translate { y: previewImage.slideY }

                            onSourceChanged: {
                                slideY = root.previewSlideDir * 26
                                slideAnim.restart()
                            }

                            NumberAnimation {
                                id: slideAnim
                                target: previewImage
                                property: "slideY"
                                to: 0
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.topMargin: 5
                            anchors.fill: previewImage
                            radius: 15
                            color: Theme.deleting
                            opacity: currentEntryId === root.deletingId ? 0.70 : 0
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            anchors.centerIn: previewImage
                            text: "Deleted"
                            color: "white"
                            font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
                            opacity: currentEntryId === root.deletingId ? 1 : 0
                            scale: currentEntryId === root.deletingId ? 1 : 0.80
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.margins: 2
                            text: (root.selectedIndex + 1) + " / " + CliphistModel.count
                            color: Theme.fg4
                            font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                        }
                    }
                }
            }
        }

        ListView {
            id: listView
            width: parent.width
            height: parent.height - 67
            clip: true
            model: CliphistModel
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            highlightMoveDuration: 80
            visible: !imgFullPreview

            removeDisplaced: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                width: listView.width
                height: model.clipId === root.collapsingId ? 5 : (model.imagePath ? 55 : 30)
                radius: 7
                color: model.clipId === root.deletingId ? Theme.deleting : (index === root.selectedIndex ? Theme.focusBg1 : "transparent")
                clip: true
                opacity: model.clipId === root.collapsingId ? 0 : 1
                scale: model.clipId === root.collapsingId ? 0.75 : 1

                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: model.imagePath ? ("file://" + model.imagePath) : ""
                    visible: model.imagePath !== ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(80, 50)
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    text: model.label
                    visible: !model.imagePath && !imgFullPreview
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10 }
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedIndex = index
                        root.copySelected()
                    }
                }
            }
        }
    }
}
