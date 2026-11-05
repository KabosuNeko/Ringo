import QtQuick
import Quickshell
import Quickshell.Io

// Default applications per role, read and written through `gio mime`.
Scope {
  id: model

  // Default apps: filled from `gio mime` when the page is opened.
  property var appRows: model.blankAppRows()
  property var mimeQueue: []
  property int mimeIndex: 0
  property string appsError: ""

  // gio is the only thing that knows both the current default and the installed
  // candidates for a mimetype, so the rows are answers to `gio mime <type>`.
  function appRoleTemplate(): var {
    return [
      { icon: "\uf0ac", label: "Browser", mime: "x-scheme-handler/http" },
      { icon: "\uf07b", label: "File manager", mime: "inode/directory" },
      { icon: "\uf120", label: "Terminal", mime: "x-scheme-handler/terminal" },
      { icon: "\uf03e", label: "Image viewer", mime: "image/png" },
      { icon: "\uf03d", label: "Video player", mime: "video/mp4" },
      { icon: "\uf1c1", label: "PDF viewer", mime: "application/pdf" },
      { icon: "\uf044", label: "Text editor", mime: "text/plain" }
    ]
  }

  function appValue(row): string {
    if (!row) return ""
    if (row.loading) return "…"
    if (row.def && row.def.length > 0) return row.def
    return row.candidates && row.candidates.length > 0 ? "Not set" : "None"
  }

  function blankAppRows(): var {
    const rows = model.appRoleTemplate()
    for (let i = 0; i < rows.length; i++) {
      rows[i].def = ""
      rows[i].candidates = []
      rows[i].loading = true
    }
    return rows
  }

  function refreshApps(): void {
    model.appsError = ""
    model.appRows = model.blankAppRows()
    model.queryMimes([0, 1, 2, 3, 4, 5, 6])
  }

  // one gio call at a time, in order
  function queryMimes(indices): void {
    model.mimeQueue = indices.slice()
    model.queryNextMime()
  }

  function queryNextMime(): void {
    if (model.mimeQueue.length === 0) return
    const index = model.mimeQueue[0]
    const row = model.appRows[index]
    if (!row) { model.mimeQueue = model.mimeQueue.slice(1); model.queryNextMime(); return }
    model.mimeIndex = index
    mimeQuery.command = ["gio", "mime", row.mime]
    mimeQuery.running = true
  }

  function parseMimeOutput(text: string): var {
    const lines = String(text).split("\n")
    const registered = []
    const recommended = []
    let def = ""
    let bucket = null
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line.length === 0) continue
      if (line.startsWith("Default application for")) {
        def = line.substring(line.lastIndexOf(":") + 1).trim()
        bucket = null
        continue
      }
      if (line.startsWith("No default applications")) { def = ""; bucket = null; continue }
      if (line.startsWith("Registered applications")) { bucket = registered; continue }
      if (line.startsWith("Recommended applications")) { bucket = recommended; continue }
      if (bucket) bucket.push(line)
    }
    const candidates = []
    for (let i = 0; i < registered.length; i++)
      if (candidates.indexOf(registered[i]) < 0) candidates.push(registered[i])
    for (let i = 0; i < recommended.length; i++)
      if (candidates.indexOf(recommended[i]) < 0) candidates.push(recommended[i])
    return { def: def, candidates: candidates }
  }

  function applyMimeQuery(text: string): void {
    const index = model.mimeIndex
    const rows = model.appRows.slice()
    const row = rows[index]
    if (row) {
      const parsed = model.parseMimeOutput(text)
      row.def = parsed.def
      row.candidates = parsed.candidates
      row.loading = false
      model.appRows = rows
    }
    model.mimeQueue = model.mimeQueue.slice(1)
    model.queryNextMime()
  }

  // Cycle to the next installed candidate and let gio write it, then re-read the
  // row so the value is what gio reports rather than what we asked for.
  function cycleDefaultApp(index: int): void {
    const row = model.appRows[index]
    if (!row || !row.candidates || row.candidates.length === 0) return
    if (mimeSet.running || mimeQuery.running) return
    const at = row.candidates.indexOf(row.def)
    const next = row.candidates[(at + 1) % row.candidates.length]
    if (next === row.def) return
    model.appsError = ""
    // the row reads "…" until the write and the re-read are done
    const rows = model.appRows.slice()
    rows[index].loading = true
    model.appRows = rows
    model.mimeIndex = index
    mimeSet.command = ["gio", "mime", row.mime, next]
    mimeSet.running = true
  }

  // `gio mime <type>` — one query at a time, LC_ALL=C so the output parses the
  // same whatever the session locale is.
  Process {
    id: mimeQuery
    environment: ({ LC_ALL: "C" })

    stdout: StdioCollector {
      id: mimeQueryOut
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: mimeQueryErr
      waitForEnd: true
    }

    onExited: (code, status) => {
      if (code !== 0)
        model.appsError = mimeQueryErr.text.trim() || ("gio mime exited with " + code)
      model.applyMimeQuery(code === 0 ? mimeQueryOut.text : "")
    }
  }

  // `gio mime <type> <app.desktop>` — cycles a default app
  Process {
    id: mimeSet
    environment: ({ LC_ALL: "C" })

    stdout: StdioCollector { waitForEnd: true }

    stderr: StdioCollector {
      id: mimeSetErr
      waitForEnd: true
    }

    onExited: (code, status) => {
      const index = model.mimeIndex
      if (code !== 0) {
        model.appsError = mimeSetErr.text.trim() || ("gio mime exited with " + code)
        return
      }
      model.queryMimes([index])
    }
  }
}
