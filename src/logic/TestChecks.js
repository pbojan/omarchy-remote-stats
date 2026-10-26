.pragma library
.import "Poll.js" as Poll
.import "Target.js" as Target

// The add-server test as five checks: target, key, server, auth, glances.

var CHECKS = ["target", "key", "server", "auth", "glances"]

// The checks from what has run so far:
//   keyResult  - ssh-keygen -y on the key: {exitCode, stderr}, or null while it runs
//   pollResult - one poll: {exitCode, stdout, stderr}, or null while it runs
// Each check is ok, fail, run or skip. A failed check stops the test; the
// checks after it stay "skip".
function checks(target, keyResult, pollResult) {
  var parsed = Target.parseTarget(target)
  var list = CHECKS.map(function(check) { return { check: check, status: "skip", kind: "", detail: "" } })
  var ok = function(i, detail) { list[i].status = "ok"; list[i].detail = detail || "" }
  var fail = function(i, kind, detail) { list[i].status = "fail"; list[i].kind = kind; list[i].detail = detail || "" }

  if (parsed.err) { fail(0, "target"); return list }
  ok(0)

  if (!keyResult) { list[1].status = "run"; return list }
  if (keyResult.exitCode !== 0) { fail(1, "key", Poll.lastLine(keyResult.stderr)); return list }
  ok(1)

  if (!pollResult) { list[2].status = "run"; return list }
  var stderr = String(pollResult.stderr || "")
  var hostPort = parsed.host + ":" + parsed.port

  // ssh exits with 255 on its own errors (see docs/research/ssh-tests.md).
  if (pollResult.exitCode === 255) {
    if (/REMOTE HOST IDENTIFICATION HAS CHANGED|Host key verification failed/.test(stderr)) {
      fail(2, "hostkey", "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!")
    } else if (/Permission denied/.test(stderr)) {
      ok(2, hostPort)
      fail(3, "auth", Poll.lastLine(stderr))
    } else {
      fail(2, "server", Poll.lastLine(stderr))
    }
    return list
  }
  ok(2, hostPort)
  ok(3)

  // The same reading of the exit code as the panel's (Poll.failure).
  var snapshot = pollResult.exitCode === 0 ? Poll.parseSnapshot(pollResult.stdout) : null
  if (!snapshot) {
    var error = Poll.failure(pollResult.exitCode, stderr)
    fail(4, error.kind, error.message)
    return list
  }
  ok(4)
  list[4].hostname = snapshot.system && snapshot.system.hostname ? snapshot.system.hostname : parsed.host
  list[4].cpu = snapshot.cpu.total
  return list
}
