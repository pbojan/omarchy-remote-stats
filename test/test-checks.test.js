// Run: node test/test-checks.test.js
const assert = require('node:assert/strict')
const TestChecks = require('./load')('TestChecks')
const fixture = require('./fixtures/servers.json')

// The add-server test, from ssh-keygen and poll results.
const T = 'deploy@192.168.2.20:22'
const states = (checks) => checks.map((c) => c.status).join(' ')
const run = (keyResult, pollResult) => TestChecks.checks(T, keyResult, pollResult)
const keyOk = { exitCode: 0, stderr: '' }
const poll = (exitCode, stderr, stdout = '') => ({ exitCode, stderr, stdout })

assert.equal(states(TestChecks.checks('-oProxyCommand=x', null, null)), 'fail skip skip skip skip')
assert.equal(states(run(null, null)), 'ok run skip skip skip')
assert.equal(states(run(keyOk, null)), 'ok ok run skip skip')

const passphrase = run({ exitCode: 255, stderr: 'Load key "/home/me/.ssh/id_ed25519": incorrect passphrase supplied to decrypt private key\n' }, null)
assert.equal(states(passphrase), 'ok fail skip skip skip')
assert.match(passphrase[1].detail, /incorrect passphrase/)

const passed = run(keyOk, poll(0, '', JSON.stringify(fixture.servers[0].snapshot)))
assert.equal(states(passed), 'ok ok ok ok ok')
assert.equal(passed[2].detail, '192.168.2.20:22')
assert.equal(passed[4].hostname, 'web1')
assert.equal(passed[4].cpu, 12)

const refused = run(keyOk, poll(255, 'ssh: connect to host 192.168.2.20 port 22: Connection refused\n'))
assert.equal(states(refused), 'ok ok fail skip skip')
assert.equal(refused[2].kind, 'server')

const changed = run(keyOk, poll(255, '@@@@\n@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @\n@@@@\nHost key verification failed.\n'))
assert.equal(states(changed), 'ok ok fail skip skip')
assert.equal(changed[2].kind, 'hostkey')

const denied = run(keyOk, poll(255, 'deploy@192.168.2.20: Permission denied (publickey).\n'))
assert.equal(states(denied), 'ok ok ok fail skip')
assert.equal(denied[3].detail, 'deploy@192.168.2.20: Permission denied (publickey).')

const missing = run(keyOk, poll(127, 'sh: 1: glances: not found\n'))
assert.equal(states(missing), 'ok ok ok ok fail')
assert.equal(missing[4].kind, 'glances-missing')
assert.equal(run(keyOk, poll(0, '', 'not json'))[4].kind, 'glances')
const timedOut = run(keyOk, poll(124, ''))
assert.equal(states(timedOut), 'ok ok ok ok fail')
assert.equal(timedOut[4].kind, 'timeout')

console.log('test-checks tests passed')
