import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import IslandBackend

// ~/.config/niri/keybinds.kdl plus the shell's own IPC commands
// opened with Mod+/ or `ringo-shell call keybinds toggle`
Item {
  id: root
  clip: true

  property bool shown: false
  property string searchQuery: ""
  property int selectedIndex: 0
  // [{ keys, action, section, name, comment }]; FuzzySearch scores name/comment
  property var bindings: []
  property var sectionNames: ["All"]
  property string activeSection: "All"

  signal closeRequested()

  readonly property var filtered: {
    const inSection = activeSection === "All"
      ? bindings
      : bindings.filter(b => b.section === activeSection)
    if (searchQuery.length === 0) return inSection
    return FuzzySearch.filterAndSort(inSection, searchQuery, "All")
  }

  function setSearchText(t) {
    searchQuery = t
    selectedIndex = 0
  }

  function moveSelection(delta) {
    if (filtered.length === 0) return
    selectedIndex = (selectedIndex + delta + filtered.length) % filtered.length
    list.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  // niri syntax: `Mod+Key`, optional hotkey-overlay-title, then a brace block
  function parse(text) {
    const entries = []
    let section = "General"
    const lines = text.split("\n")

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const trimmed = line.trim()

      if (trimmed.startsWith("//")) {
        const comment = trimmed.replace(/^\/\/\s*/, "").trim()
        if (comment.length > 0 && !trimmed.startsWith("///")) section = comment
        continue
      }
      if (trimmed.length === 0 || !trimmed.includes("{")) continue
      // the `binds { ... }` wrapper would otherwise swallow every binding
      if (/^binds\s*\{/.test(trimmed)) continue

      const head = trimmed.match(/^([A-Za-z0-9+_,\/.-]+)\s*(.*)$/)
      if (!head) continue
      const keys = head[1]
      if (!/^[A-Za-z]/.test(keys)) continue

      let depth = 0
      let block = ""
      for (let j = i; j < lines.length; j++) {
        const body = lines[j]
        depth += (body.match(/\{/g) || []).length
        depth -= (body.match(/\}/g) || []).length
        block += body + "\n"
        if (depth <= 0) {
          i = j
          break
        }
      }

      const title = (block.match(/hotkey-overlay-title="([^"]*)"/) || [])[1]
      let action = ""
      for (const bodyLine of block.split("\n")) {
        const line = bodyLine.trim()
        if (line.length === 0 || line.startsWith("//")) continue
        const inner = line.includes("{") ? line.slice(line.indexOf("{") + 1) : line
        const statement = inner.split(";")[0].trim()
        if (statement.length === 0) continue
        action = statement
        break
      }
      action = action
        .replace(/^spawn-sh\s+/, "")
        .replace(/^spawn\s+/, "")
        .replace(/"/g, "")
        .replace(/^show-hotkey-overlay$/, "Show the keybind overlay")
        .trim()

      const label = title && title.length > 0 ? title : action
      if (label.length === 0) continue

      entries.push({
        keys: keys,
        label: label,
        action: action,
        section: section,
        name: keys + " " + label,
        comment: label + " " + action + " " + section
      })
    }

    const sections = ["All"]
    for (const entry of entries)
      if (!sections.includes(entry.section)) sections.push(entry.section)

    bindings = entries
    sectionNames = sections
    if (!sections.includes(activeSection)) activeSection = "All"
    selectedIndex = 0
  }

  readonly property string keybindPath: Quickshell.env("HOME") + "/.config/niri/keybinds.kdl"

  // FileView only watches; text comes from the backend since its accessor is not
  // a plain string from a handler
  FileView {
    id: keybindFile
    path: root.keybindPath
    watchChanges: true
    onLoaded: root.reloadBindings()
    onFileChanged: root.reloadBindings()
  }

  function reloadBindings() {
    parse(Tools.readText(root.keybindPath))
  }

  Component.onCompleted: reloadBindings()

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Theme.cardBg
    border.width: 1
    border.color: Theme.cardBorder

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 6

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: "\uf11c"
          color: Theme.accent
          font { family: Theme.nerdFontFamily; pixelSize: 12 }
        }

        Text {
          Layout.fillWidth: true
          text: "Keybinds"
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
        }

        Text {
          text: root.filtered.length + " / " + root.bindings.length
          color: Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 9 }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        radius: 8
        color: Theme.chipBg
        border.width: 1
        border.color: searchInput.activeFocus ? Theme.accent : Theme.cardBorder
        Behavior on border.color { ColorAnimation { duration: 120 } }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          verticalAlignment: TextInput.AlignVCenter
          color: Theme.fg
          selectionColor: Theme.accent
          selectedTextColor: Theme.bg
          font { family: Theme.fontFamily; pixelSize: 10 }
          clip: true
          focus: root.shown

          onTextChanged: root.searchQuery = text

          Text {
            text: "Search keybinds, actions, commands..."
            color: Theme.fg5
            font: searchInput.font
            visible: searchInput.text.length === 0
            anchors.verticalCenter: parent.verticalCenter
          }

          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Down) {
              root.moveSelection(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.moveSelection(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              const idx = root.sectionNames.indexOf(root.activeSection)
              root.activeSection = root.sectionNames[(idx + 1) % root.sectionNames.length]
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.closeRequested()
              event.accepted = true
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: root.sectionNames.length > 1

        Repeater {
          model: root.sectionNames

          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            radius: 6
            color: root.activeSection === modelData
                   ? Theme.accentSoft
                   : (sectionHover.hovered ? Theme.chipBgHover : Theme.chipBg)
            border.width: 1
            border.color: root.activeSection === modelData ? Theme.accent : Theme.cardBorder
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: modelData
              color: root.activeSection === modelData ? Theme.accent : Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 8; weight: root.activeSection === modelData ? 700 : 500 }
              elide: Text.ElideRight
              width: parent.width - 8
              horizontalAlignment: Text.AlignHCenter
            }

            HoverHandler { id: sectionHover }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.activeSection = modelData; root.selectedIndex = 0 }
            }
          }
        }
      }

      ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.filtered
        currentIndex: root.selectedIndex
        highlightFollowsCurrentItem: false
        spacing: 2

        delegate: Rectangle {
          width: list.width
          height: 30
          radius: 7
          color: index === root.selectedIndex ? Theme.chipBgHover : "transparent"
          Behavior on color { ColorAnimation { duration: 100 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Row {
              Layout.preferredWidth: 150
              spacing: 3

              Repeater {
                model: modelData.keys.split("+")

                delegate: Rectangle {
                  height: 18
                  width: keyText.implicitWidth + 10
                  radius: 5
                  color: Theme.bgD
                  border.width: 1
                  border.color: index === root.selectedIndex ? Theme.accent : Theme.cardBorder

                  Text {
                    id: keyText
                    anchors.centerIn: parent
                    text: modelData
                    color: index === root.selectedIndex ? Theme.accent : Theme.fg3
                    font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              text: modelData.label
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 9 }
              elide: Text.ElideRight
            }

            Text {
              text: modelData.section
              color: Theme.fg5
              font { family: Theme.fontFamily; pixelSize: 8 }
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }
}
