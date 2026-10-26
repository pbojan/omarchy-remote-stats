.pragma library

// Display text for the panel. QML passes the shell's number formatter
// (Commons.I18n.formatNumber) as `fmt`; Node tests leave it out and get
// plain English digits.

var GIB = 1024 * 1024 * 1024
var TIB = GIB * 1024

function formatter(fmt) {
  return typeof fmt === "function" ? fmt : function(v, d) { return d === undefined ? String(v) : Number(v).toFixed(d) }
}

// "41%"
function percent(value, fmt) {
  return formatter(fmt)(Math.round(Number(value) || 0)) + "%"
}

// "39.0 / 96.0 GiB": both sizes in the unit of the total.
function usedTotal(used, total, fmt) {
  var f = formatter(fmt)
  var unit = Number(total) >= TIB ? TIB : GIB
  var label = unit === TIB ? "TiB" : "GiB"
  return f(Number(used) / unit, 1) + " / " + f(Number(total) / unit, 1) + " " + label
}

// "0.42 · 0.38 · 0.31"
function loadAverage(load, fmt) {
  var f = formatter(fmt)
  if (!load) return "–"
  return [load.min1, load.min5, load.min15].map(function(v) { return f(Number(v) || 0, 2) }).join(" · ")
}

// "/mnt/hdd1 (ext4)", or the mount point alone when Glances has no type.
function diskLabel(disk) {
  return disk.fs_type ? disk.mnt_point + " (" + disk.fs_type + ")" : disk.mnt_point
}

// "Linux Mint 22", or "" when the snapshot has no system data.
function distroName(snapshot) {
  var system = snapshot && snapshot.system
  return system ? system.linux_distro || system.os_name || "" : ""
}

// "14:27:31", or "14:27" without seconds. A clock time, never a relative
// time (design rule).
function clock(ms, withSeconds) {
  var date = new Date(ms)
  var parts = [date.getHours(), date.getMinutes()]
  if (withSeconds) parts.push(date.getSeconds())
  return parts.map(function(n) { return n < 10 ? "0" + n : String(n) }).join(":")
}
