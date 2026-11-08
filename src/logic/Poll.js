.pragma library
.import "Config.js" as Config
.import "Target.js" as Target

// One poll: one ssh call that prints one Glances snapshot (ADR-002), and
// the poll result it leaves for the server.
//
// A poll result:
//   lastPollMs  when the last poll finished; 0 before the first
//   lastOkMs    when the last good poll finished; 0 if none
//   error       null, or { kind, message } (failure())
//   snapshot    the last good Glances snapshot, or null

var NO_RESULT = { lastPollMs: 0, lastOkMs: 0, error: null, snapshot: null }

// `timeout` ends a poll after this many seconds and exits with 124. Without
// it, a Glances that hangs on the server would keep its poll running for
// good. The Glances process stays on the server until it finishes: sshd
// does not stop a command that has no terminal.
var DEADLINE_SECONDS = 20
var TIMED_OUT = 124

// Only the Remote Stats key may log in (ADR-005). `-F none` skips
// ~/.ssh/config, because a key named there would be tried when the server
// refuses ours, and no -o option can remove it. IdentityAgent=none keeps the
// agent's keys out. `remote-stats setup` tests with the same options;
// test/cli.test.sh checks that they match.
var KEY_ONLY_OPTIONS = ["-F", "none", "-o", "IdentitiesOnly=yes", "-o", "IdentityAgent=none", "-o", "BatchMode=yes"]

// The server's forced command runs Glances with these arguments
// (server/setup.sh); test/cli.test.sh checks that they match.
// --disable-check-update: without it, Glances asks PyPI for a newer version
// and prints a notice on stdout after the snapshot.
var GLANCES_ARGS = [
  "--disable-check-update",
  "--disable-plugin", "all", "--enable-plugin", "system,cpu,mem,load,fs",
  "--stdout-json", "system,cpu,mem,load,fs"
]

// The arguments are a list, never a shell string; `--` stops a target from
// passing as an option.
//
// With a controlDir, polls of one target share one connection (ADR-006).
// Without one, ssh logs in anew. The add-server test needs that: a shared
// connection would answer without ever offering the key in the form.
function command(entry, home, controlDir) {
  var connection = controlDir
    ? ["-o", "ControlMaster=auto", "-o", "ControlPersist=300", "-o", "ControlPath=" + controlDir + "/%C"]
    : ["-o", "ControlPath=none"]
  return ["timeout", String(DEADLINE_SECONDS), "ssh"].concat(KEY_ONLY_OPTIONS, [
    "-T", "-i", Target.expandHome(entry.key || Config.DEFAULT_KEY, home),
    "-o", "ConnectTimeout=5",
    "-o", "StrictHostKeyChecking=accept-new"
  ], connection, [
    "-o", "ServerAliveInterval=15",
    "-o", "ServerAliveCountMax=2",
    "--", "ssh://" + entry.target,
    // The forced command replaces this. Sent anyway, so a server without
    // one works too.
    "glances"
  ], GLANCES_ARGS)
}

// The snapshot from a poll's stdout, or null when it is not one. The
// snapshot is the first line. Glances may print more after it, such as a
// notice about a newer version on a server set up without
// --disable-check-update.
function parseSnapshot(stdout) {
  var snapshot
  try { snapshot = JSON.parse(String(stdout || "").split("\n")[0]) } catch (e) { return null }
  return snapshot && snapshot.cpu ? snapshot : null
}

function lastLine(text) {
  var lines = String(text || "").trim().split("\n")
  return lines[lines.length - 1].trim()
}

// The error of a poll that brought no snapshot, from its exit code. The
// panel and the add-server test both use it.
//   255         ssh's own errors: refused, timed out, denied, changed host
//               key. The status is Offline; all others are Issue.
//   127         the shell on the server: no glances command
//   124         `timeout` ended the poll
//   any other   Glances ran but printed no snapshot, also with exit code 0
// The message is the last line of stderr, as is; it may be empty.
function failure(exitCode, stderr) {
  var kind = exitCode === 255 ? "ssh"
    : exitCode === 127 ? "glances-missing"
    : exitCode === TIMED_OUT ? "timeout"
    : "glances"
  return { kind: kind, message: lastLine(stderr) }
}

// The poll result after a poll exits. A failed poll keeps the last snapshot
// and lastOkMs, so the panel can tell when the server last answered.
function result(previous, exitCode, stdout, stderr, nowMs) {
  var snapshot = exitCode === 0 ? parseSnapshot(stdout) : null
  if (snapshot) return { lastPollMs: nowMs, lastOkMs: nowMs, error: null, snapshot: snapshot }

  var last = previous || NO_RESULT
  return { lastPollMs: nowMs, lastOkMs: last.lastOkMs, error: failure(exitCode, stderr), snapshot: last.snapshot }
}
