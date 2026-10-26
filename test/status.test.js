// Run: node test/status.test.js
const assert = require('node:assert/strict')
const Status = require('./load')('Status')
const fixture = require('./fixtures/servers.json')

const byName = Object.fromEntries(fixture.servers.map((s) => [s.name, s]))
// At a 10 s interval, data is stale after 50 s.
const status = (name) => Status.serverStatus(byName[name], fixture.now, 10 * 1000)

assert.equal(status('web1'), 'connected')
assert.equal(status('db1'), 'critical')
assert.equal(status('nas'), 'stale')
assert.equal(status('build'), 'issue')
assert.equal(status('backup'), 'offline')
assert.equal(status('staging'), 'connecting')
assert.equal(Status.serverStatus(null, fixture.now, 10 * 1000), 'connecting')
// Only an ssh error is Offline; a failure on the server is an Issue, even
// with an old snapshot.
const failed = (kind) => Status.serverStatus({ ...byName.web1, error: { kind, message: '' } }, fixture.now, 10 * 1000)
assert.deepEqual(['ssh', 'glances-missing', 'glances', 'timeout'].map(failed), ['offline', 'issue', 'issue', 'issue'])
// nas answered 72 s ago: stale at a 10 s interval, fine at 30 s (150 s).
assert.equal(Status.serverStatus(byName.nas, fixture.now, 30 * 1000), 'connected')

assert.equal(Status.needsAttention('critical'), true)
assert.equal(Status.needsAttention('stale'), false)
assert.equal(Status.hasData('stale'), true)
assert.equal(Status.hasData('offline'), false)

// btrfs subvolume /home shares /dev/sda2 with / and is dropped.
const fs = [
  { device_name: '/dev/sda2', mnt_point: '/home', percent: 40 },
  { device_name: '/dev/sda2', mnt_point: '/', percent: 40 },
  { device_name: '/dev/sdb1', mnt_point: '/var/lib/docker', percent: 78 }
]
assert.deepEqual(Status.uniqueDisks(fs).map((d) => d.mnt_point), ['/', '/var/lib/docker'])
// A Qt list from the service is array-like, not an Array.
const qtList = Object.assign({ length: fs.length }, fs)
assert.equal(Status.uniqueDisks(qtList).length, 2)
assert.deepEqual(Status.uniqueDisks(undefined), [])

// db1's /data disk is at 94.2 %: a disk alone makes a server critical.
assert.equal(Status.worstPercent(byName.db1.snapshot), 94.2)

console.log('status tests passed')
