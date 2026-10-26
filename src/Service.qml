import QtQuick
import Quickshell
import Quickshell.Io
import "logic/Config.js" as Config
import "logic/Poll.js" as Poll
import "logic/Status.js" as Status

// Polls every server in config.json, once for the whole shell.
//
// Omarchy builds a bar per monitor. If the widget polled, each screen would
// poll each server again (ADR-009). The widgets read `servers` from here and
// add or remove servers through it.
//
// This file does the I/O: it reads and writes config.json and runs the
// polls. What the file means and what a poll means is in Config.js, Poll.js
// and Status.js.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/omarchy/remote-stats"
  readonly property string controlDir: Quickshell.env("XDG_RUNTIME_DIR") + "/remote-stats"

  // config.json as parsed (Config.read). `file` is null while the file is
  // not valid JSON, so no edit writes over a file the user is editing.
  property var file: null
  property var settings: Config.DEFAULT_SETTINGS
  property var serverEntries: []
  // While config.json is not valid JSON, the service keeps the last good
  // settings and servers and keeps polling. The panel shows both problems.
  property bool configInvalid: false
  property var skipped: []
  property bool configLoaded: false

  // What the pollers need from each server entry: name, target and key.
  // Kept apart from serverEntries, so a change that touches no connection,
  // such as opening a row, does not restart the polls.
  property var connections: []
  property string connectionsKey: ""

  // name -> poll result (Poll.js)
  property var results: ({})
  property real now: Date.now()

  // What the panel shows: one server per entry, in file order, with its
  // poll result and status.
  readonly property var servers: serverEntries.map(function(entry) {
    var result = results[entry.name] || Poll.NO_RESULT
    return {
      name: entry.name,
      open: !!entry.open,
      lastPollMs: result.lastPollMs,
      lastOkMs: result.lastOkMs,
      error: result.error,
      snapshot: result.snapshot,
      status: Status.serverStatus(result, now, settings.interval * 1000)
    }
  })

  function loadConfig(text) {
    var config = Config.read(text)
    configLoaded = true
    file = config.file
    configInvalid = !config.file
    if (configInvalid) {
      console.warn("pbojan.remote-stats: config.json is not valid JSON; keeping the last good version")
      return
    }
    settings = config.settings
    serverEntries = config.servers
    skipped = config.skipped
    config.skipped.forEach(function(s) {
      console.warn("pbojan.remote-stats: config.json: skipped server " + s.index + " (" + JSON.stringify(s.name) + "): " + s.reason)
    })

    var next = config.servers.map(function(entry) { return { name: entry.name, target: entry.target, key: entry.key } })
    var key = settings.interval + " " + JSON.stringify(next)
    if (key === connectionsKey) return
    connectionsKey = key
    connections = next

    console.log("pbojan.remote-stats: polling " + next.length + " servers every " + settings.interval + " s")
    Qt.callLater(pollAll)
  }

  function writeConfig(next) {
    var text = JSON.stringify(next, null, 2) + "\n"
    configFile.setText(text)
    loadConfig(text)
  }

  // Applies one Config.js edit. Returns false when config.json is not valid
  // JSON; the file stays as it is.
  function edit(change) {
    if (!file) return false
    writeConfig(change(file))
    return true
  }

  function addServer(entry) {
    return edit(function(f) { return Config.withServer(f, entry) })
  }

  // Removes the server from the panel only. Its key line stays on the server;
  // `remote-stats remove` removes both.
  function removeServer(name) {
    return edit(function(f) { return Config.withoutServer(f, name) })
  }

  function setOpen(name, open) {
    return edit(function(f) { return Config.withOpen(f, name, open) })
  }

  function pollCommand(entry) {
    return Poll.command(entry, home, controlDir)
  }

  // The add-server test: the same poll, but always a new login, so it tries
  // the key in the form.
  function testCommand(entry) {
    return Poll.command(entry, home, "")
  }

  // Starts a poll for every server that is not polling already.
  function pollAll() {
    now = Date.now()
    if (!folders.done) return
    for (var i = 0; i < pollers.count; i++) {
      var poller = pollers.objectAt(i)
      if (poller && !poller.running) poller.running = true
    }
  }

  function finishPoll(entry, exitCode, stdout, stderr) {
    now = Date.now()
    var next = Object.assign({}, results)
    next[entry.name] = Poll.result(results[entry.name], exitCode, stdout, stderr, now)
    results = next
  }

  // ssh does not create the ControlPath folder, and FileView cannot watch a
  // file in a folder that does not exist.
  Process {
    id: folders
    property bool done: false
    running: true
    command: ["mkdir", "-p", "-m", "700", root.controlDir, root.configDir]
    onExited: done = true
  }

  // A file missing at start gets the defaults written, so the watch has a
  // file to follow when `remote-stats add` changes it later. A file missing
  // later is left alone: Vim and Neovim save by renaming the file away and
  // writing a new one, and the defaults would replace the user's file.
  FileView {
    id: configFile
    path: folders.done ? root.configDir + "/config.json" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadConfig(text())
    onLoadFailed: if (!root.configLoaded) root.writeConfig(Config.defaultFile())
  }

  Instantiator {
    id: pollers
    model: root.connections

    delegate: Process {
      id: poller
      required property var modelData
      command: root.pollCommand(modelData)
      stdout: StdioCollector { id: out }
      stderr: StdioCollector { id: err }
      onExited: function(exitCode) { root.finishPoll(poller.modelData, exitCode, out.text, err.text) }
    }
  }

  Timer {
    interval: root.settings.interval * 1000
    running: true
    repeat: true
    onTriggered: root.pollAll()
  }
}
