// Run: node test/config.test.js
const assert = require('node:assert/strict')
const Config = require('./load')('Config')

const text = (file) => JSON.stringify(file)

// Not valid JSON: no file to edit, the defaults, no servers.
const broken = Config.read('{"servers": [')
assert.equal(broken.file, null)
assert.deepEqual(broken.settings, { interval: 30, showDisks: true })
assert.deepEqual(broken.servers, [])
assert.equal(Config.read('[]').file, null)

// Settings: missing and bad values get the defaults; the interval is at least 5 s.
assert.deepEqual(Config.read(text({ settings: { interval: 10, showDisks: false } })).settings, { interval: 10, showDisks: false })
assert.equal(Config.read(text({ settings: { interval: 2 } })).settings.interval, 5)
assert.equal(Config.read(text({ settings: { interval: 'soon' } })).settings.interval, 30)
assert.equal(Config.read(text({})).settings.showDisks, true)

// Entries: a bad target, a missing name and a repeated name are skipped.
const read = Config.read(text({
  servers: [
    { name: 'web1', target: 'deploy@web1' },
    { name: 'web1', target: 'deploy@other' },
    { name: 'bad', target: '-oProxyCommand=x' },
    { target: 'deploy@noname' },
    null,
    { name: 'db1', target: 'db1:2222', open: true }
  ]
}))
assert.deepEqual(read.servers.map((s) => s.name), ['web1', 'db1'])
// Each skipped entry says where it is and why, for the panel and the log.
assert.deepEqual(read.skipped, [
  { index: 2, name: 'web1', reason: 'duplicate' },
  { index: 3, name: 'bad', reason: 'target' },
  { index: 4, name: '', reason: 'name' },
  { index: 5, name: '', reason: 'name' }
])

// The edits return a new file and keep everything else in it.
const file = { version: 1, settings: { interval: 7 }, servers: [{ name: 'web1', target: 'web1' }] }
const added = Config.withServer(file, { name: 'db1', target: 'db1' })
assert.deepEqual(added.servers.map((s) => s.name), ['web1', 'db1'])
assert.deepEqual(added.settings, { interval: 7 })
assert.equal(file.servers.length, 1)

assert.deepEqual(Config.withoutServer(added, 'web1').servers.map((s) => s.name), ['db1'])

const opened = Config.withOpen(added, 'db1', true)
assert.equal(opened.servers[1].open, true)
assert.equal('open' in opened.servers[0], false)
assert.equal('open' in Config.withOpen(opened, 'db1', false).servers[1], false)

assert.deepEqual(Config.defaultFile(), { version: 1, settings: { interval: 30, showDisks: true }, servers: [] })

console.log('config tests passed')
