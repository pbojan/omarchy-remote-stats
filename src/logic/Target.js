.pragma library

// Targets as the user types them: "user@host:port", the user and the port
// optional. ssh gets them as "ssh://<target>" (ADR-005).

// Splits a target into its parts. IPv6 hosts go in brackets. On failure
// `err` names the rule that broke, so QML can show the matching string; the
// host never starts with "-", so it cannot pass as an ssh option.
function parseTarget(text) {
  var t = String(text || "").trim()
  if (t === "") return { err: "required" }
  var afterUser = t.indexOf("@") >= 0 ? t.slice(t.lastIndexOf("@") + 1) : t
  if (afterUser[0] !== "[" && afterUser.split(":").length > 2) return { err: "ipv6Brackets" }
  var m = t.match(/^(?:([^@]*)@)?(\[[^\]]*\]|[^:@\[\]]*)(?::(.*))?$/)
  if (!m) return { err: "format" }
  var user = m[1], raw = m[2], port = m[3]
  if (user !== undefined && !/^[A-Za-z0-9._][A-Za-z0-9._-]*$/.test(user)) return { err: "user" }
  if (!raw) return { err: "hostMissing" }
  if (raw[0] === "-") return { err: "hostDash" }
  var host = raw
  if (raw[0] === "[") {
    host = raw.slice(1, -1)
    if (!/^[0-9A-Fa-f:.]+$/.test(host) || host.indexOf(":") < 0) return { err: "ipv6Invalid" }
  } else if (!/^[A-Za-z0-9._-]+$/.test(raw)) {
    return { err: "hostChars" }
  }
  if (port !== undefined && (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535)) return { err: "port" }
  return { err: "", user: user || "", host: host, port: port === undefined ? 22 : Number(port) }
}

// The name a new server gets: the typed name, or the host part of the
// target. `remote-stats add` uses the same rule.
function effectiveName(name, target) {
  var typed = String(name || "").trim()
  if (typed !== "") return typed
  var parsed = parseTarget(target)
  return parsed.err ? "" : parsed.host
}

// "~/.ssh/key" -> "/home/me/.ssh/key". Process runs no shell, so nothing
// else expands the tilde.
function expandHome(path, home) {
  return String(path || "").replace(/^~\//, home + "/")
}
