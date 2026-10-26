// Run: node test/format.test.js
const assert = require('node:assert/strict')
const Format = require('./load')('Format')
const fixture = require('./fixtures/servers.json')

assert.equal(Format.percent(40.6), '41%')
assert.equal(Format.usedTotal(41875931136, 103079215104), '39.0 / 96.0 GiB')
assert.equal(Format.usedTotal(1968125813719, 2089072092774), '1.8 / 1.9 TiB')
assert.equal(Format.loadAverage(fixture.servers[0].snapshot.load), '0.42 · 0.38 · 0.31')
assert.equal(Format.loadAverage(null), '–')
assert.equal(Format.diskLabel({ mnt_point: '/mnt/hdd1', fs_type: 'ext4' }), '/mnt/hdd1 (ext4)')
assert.equal(Format.diskLabel({ mnt_point: '/' }), '/')
assert.equal(Format.distroName({ system: { os_name: 'Linux', linux_distro: 'Linux Mint 22' } }), 'Linux Mint 22')
assert.equal(Format.distroName({ system: { os_name: 'Linux' } }), 'Linux')
assert.equal(Format.distroName(null), '')

// The shell's formatter gets the value and the decimals.
const comma = (v, d) => (d === undefined ? String(v) : Number(v).toFixed(d)).replace('.', ',')
assert.equal(Format.usedTotal(41875931136, 103079215104, comma), '39,0 / 96,0 GiB')

const at = new Date(2026, 9, 25, 9, 5, 7).getTime()
assert.equal(Format.clock(at, true), '09:05:07')
assert.equal(Format.clock(at, false), '09:05')

console.log('format tests passed')
