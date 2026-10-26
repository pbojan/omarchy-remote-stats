.pragma library
.import "Target.js" as Target

// config.json (ADR-008): a "settings" object and the server entries. The
// file is user input, so read() checks every part of it. The edits take the
// parsed file and return a new one; they never change their input.
//
// bin/remote-stats writes the same defaults; test/cli.test.sh checks that
// they match.

var DEFAULT_SETTINGS = { interval: 30, showDisks: true }
// A poll takes about 2.5 s, so a shorter interval would overlap polls.
var MIN_INTERVAL = 5
var DEFAULT_KEY = "~/.ssh/remote_stats_ed25519"

function defaultFile() {
  return { version: 1, settings: Object.assign({}, DEFAULT_SETTINGS), servers: [] }
}

// The text of config.json as:
//   file      the parsed JSON object, or null when the text is not one. Edit
//             nothing then: the user may be in the middle of an edit.
//   settings  { interval, showDisks }, with the defaults for missing or bad
//             values
//   servers   the entries with a name, a unique name and a valid target, in
//             file order
//   skipped   the other entries: { index (from 1), name, reason }, with the
//             reason "name", "duplicate" or "target"
function read(text) {
  var file
  try { file = JSON.parse(text) } catch (e) { file = null }
  if (!file || typeof file !== "object" || Array.isArray(file)) file = null

  var settings = (file && file.settings) || {}
  var names = {}
  var skipped = []
  var servers = entriesOf(file || {}).filter(function(entry, i) {
    var reason = !entry || !entry.name ? "name"
      : names[entry.name] ? "duplicate"
      : Target.parseTarget(entry.target).err ? "target"
      : ""
    if (reason) {
      skipped.push({ index: i + 1, name: (entry && entry.name) || "", reason: reason })
      return false
    }
    names[entry.name] = true
    return true
  })

  return {
    file: file,
    settings: {
      interval: Math.max(MIN_INTERVAL, Number(settings.interval) || DEFAULT_SETTINGS.interval),
      showDisks: settings.showDisks !== false
    },
    servers: servers,
    skipped: skipped
  }
}

function entriesOf(file) {
  return Array.isArray(file.servers) ? file.servers : []
}

function withServer(file, entry) {
  return Object.assign({}, file, { servers: entriesOf(file).concat([entry]) })
}

function withoutServer(file, name) {
  return Object.assign({}, file, {
    servers: entriesOf(file).filter(function(entry) { return entry.name !== name })
  })
}

// An open row is saved as "open": true on its entry; a closed row has no
// "open" key.
function withOpen(file, name, open) {
  return Object.assign({}, file, {
    servers: entriesOf(file).map(function(entry) {
      if (entry.name !== name) return entry
      var changed = Object.assign({}, entry)
      if (open) changed.open = true
      else delete changed.open
      return changed
    })
  })
}
