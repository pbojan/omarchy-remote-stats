// Run: node test/target.test.js
const assert = require('node:assert/strict')
const Target = require('./load')('Target')

// Target parsing follows the add-server rules in the design spec.
const t = (s) => Target.parseTarget(s)
assert.deepEqual(t('deploy@192.168.2.20:22'), { err: '', user: 'deploy', host: '192.168.2.20', port: 22 })
assert.deepEqual(t('web1'), { err: '', user: '', host: 'web1', port: 22 })
assert.deepEqual(t('root@[fe80::1]:2222'), { err: '', user: 'root', host: 'fe80::1', port: 2222 })
assert.equal(t('').err, 'required')
assert.equal(t('-oProxyCommand=x').err, 'hostDash')
assert.equal(t('deploy@').err, 'hostMissing')
assert.equal(t('deploy@host:99999').err, 'port')
assert.equal(t('deploy@host name').err, 'hostChars')
assert.equal(t('fe80::1').err, 'ipv6Brackets')
assert.equal(t('[zz::1]').err, 'ipv6Invalid')
assert.equal(t('bad user@host').err, 'user')

assert.equal(Target.effectiveName('', 'root@[fe80::1]:2222'), 'fe80::1')
assert.equal(Target.effectiveName('  web1 ', 'deploy@host'), 'web1')
assert.equal(Target.effectiveName('', 'not a target'), '')

assert.equal(Target.expandHome('~/.ssh/k', '/home/me'), '/home/me/.ssh/k')
assert.equal(Target.expandHome('/etc/k', '/home/me'), '/etc/k')

console.log('target tests passed')
