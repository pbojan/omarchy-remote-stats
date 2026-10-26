.pragma library

// The status of a server from its poll result (Poll.js): connecting,
// connected, critical, stale, issue or offline. The service computes it
// once per server; the panel only reads it.

var CRITICAL_PERCENT = 90
var STALE_AFTER_POLLS = 5

function isCritical(percent) {
  return Number(percent) >= CRITICAL_PERCENT
}

// Glances lists every mount. btrfs subvolumes and bind mounts repeat the same
// device with the same numbers, so keep one entry per device: the one with
// the shortest mount point (ADR-003).
//
// A snapshot read from the service arrives in the widget as a Qt list, for
// which Array.isArray() is false, so copy it into a plain array.
function uniqueDisks(fs) {
  var byDevice = {}
  var order = []
  var list = fs && fs.length !== undefined ? Array.from(fs) : []
  for (var i = 0; i < list.length; i++) {
    var disk = list[i]
    if (!disk || !disk.mnt_point) continue
    var key = disk.device_name || disk.mnt_point
    var kept = byDevice[key]
    if (!kept) {
      byDevice[key] = disk
      order.push(key)
    } else if (disk.mnt_point.length < kept.mnt_point.length) {
      byDevice[key] = disk
    }
  }
  return order.map(function(key) { return byDevice[key] })
}

// The highest of CPU, memory and every disk. A disk counts even when the
// panel hides the disks (settings.showDisks).
function worstPercent(snapshot) {
  if (!snapshot) return 0
  var values = [
    snapshot.cpu ? snapshot.cpu.total : 0,
    snapshot.mem ? snapshot.mem.percent : 0
  ]
  uniqueDisks(snapshot.fs).forEach(function(disk) { values.push(disk.percent) })
  return Math.max.apply(null, values.map(function(v) { return Number(v) || 0 }))
}

// Errors win over data, so an unreachable server never shows old values as
// current. Data is stale when 5 poll intervals passed without a good poll.
function serverStatus(result, nowMs, intervalMs) {
  if (!result) return "connecting"
  if (result.error) return result.error.kind === "ssh" ? "offline" : "issue"
  if (!result.snapshot) return "connecting"
  if (result.lastOkMs && nowMs - result.lastOkMs > STALE_AFTER_POLLS * intervalMs) return "stale"
  if (isCritical(worstPercent(result.snapshot))) return "critical"
  return "connected"
}

// The bar dot shows while any server needs attention.
function needsAttention(status) {
  return status === "critical" || status === "offline" || status === "issue"
}

// The statuses whose open row shows the data points.
function hasData(status) {
  return status === "connected" || status === "critical" || status === "stale"
}
