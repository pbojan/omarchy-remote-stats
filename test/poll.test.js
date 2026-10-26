// Run: node test/poll.test.js
const assert = require('node:assert/strict')
const Poll = require('./load')('Poll')
const fixture = require('./fixtures/servers.json')

const snapshot = fixture.servers[0].snapshot
const T = 'deploy@192.168.2.20:22'

// The command ends after 20 s, uses the given key, only that key, and keeps
// the target behind `--`.
const cmd = Poll.command({ target: T, key: '~/.ssh/k' }, '/home/me', '/run/user/1000/remote-stats')
assert.deepEqual(cmd.slice(0, 3), ['timeout', '20', 'ssh'])
assert.equal(cmd[cmd.indexOf('-i') + 1], '/home/me/.ssh/k')
assert.equal(cmd[cmd.indexOf('-F') + 1], 'none')
assert.ok(cmd.includes('IdentitiesOnly=yes') && cmd.includes('IdentityAgent=none'))
assert.equal(cmd[cmd.indexOf('--') + 1], 'ssh://' + T)
assert.ok(cmd.includes('ControlPath=/run/user/1000/remote-stats/%C'))
const noKey = Poll.command({ target: T }, '/home/me', '/run')
assert.equal(noKey[noKey.indexOf('-i') + 1], '/home/me/.ssh/remote_stats_ed25519')

// Without a control folder, ssh logs in anew: no shared connection.
const fresh = Poll.command({ target: T }, '/home/me', '')
assert.ok(fresh.includes('ControlPath=none'))
assert.ok(!fresh.some((a) => a.startsWith('ControlMaster') || a.startsWith('ControlPersist')))

assert.equal(Poll.parseSnapshot(JSON.stringify(snapshot)).cpu.total, 12)
assert.equal(Poll.parseSnapshot('Web console: https://mini:9090/'), null)
assert.equal(Poll.parseSnapshot('{"mem": {}}'), null)
assert.equal(Poll.lastLine('one\ntwo\n'), 'two')

// A good poll.
const ok = Poll.result(null, 0, JSON.stringify(snapshot), '', 1000)
assert.deepEqual([ok.lastPollMs, ok.lastOkMs, ok.error], [1000, 1000, null])
assert.equal(ok.snapshot.cpu.total, 12)

// A failed poll keeps the last snapshot and when it came.
const down = Poll.result(ok, 255, '', 'ssh: connect to host web1 port 22: Connection refused\n', 2000)
assert.deepEqual([down.lastPollMs, down.lastOkMs], [2000, 1000])
assert.deepEqual(down.error, { kind: 'ssh', message: 'ssh: connect to host web1 port 22: Connection refused' })
assert.equal(down.snapshot, ok.snapshot)

// The first poll fails: nothing to keep.
const missing = Poll.result(null, 127, '', 'sh: 1: glances: not found\n', 3000)
assert.deepEqual([missing.lastOkMs, missing.snapshot, missing.error.kind], [0, null, 'glances-missing'])

// Only 255 is ssh. Every other failure happened on the server: Glances
// missing, Glances failed, or the poll ran out of time.
const kind = (exitCode) => Poll.failure(exitCode, '').kind
assert.deepEqual([255, 127, 124, 1, 0].map(kind), ['ssh', 'glances-missing', 'timeout', 'glances', 'glances'])
const traceback = Poll.result(null, 1, '', 'Traceback (most recent call last):\nKeyError: fs\n', 4000)
assert.deepEqual(traceback.error, { kind: 'glances', message: 'KeyError: fs' })
// Exit 0 without a snapshot: Glances printed something else.
assert.deepEqual(Poll.result(null, 0, 'Web console', '', 4000).error, { kind: 'glances', message: '' })

console.log('poll tests passed')
