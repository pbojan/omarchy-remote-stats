// Loads a JavaScript file from src/logic/ in Node, the way QML loads it.
//
// The files start with `.pragma library` and `.import "X.js" as X` lines,
// which Node cannot read. The loader removes them, loads X first and passes
// it in as X. It returns every top-level function and var of the file.
//
//   const Status = require('./load')('Status')

const fs = require('node:fs')
const path = require('node:path')

const SRC = path.join(__dirname, '..', 'src', 'logic')

function load(name) {
  const deps = {}
  const code = fs.readFileSync(path.join(SRC, name + '.js'), 'utf8')
    .replace(/^\.pragma library$/m, '')
    .replace(/^\.import "(\w+)\.js" as (\w+)$/gm, (line, file, alias) => {
      deps[alias] = load(file)
      return ''
    })
  const names = [...code.matchAll(/^(?:function|var) (\w+)/gm)].map((m) => m[1])
  const body = code + '\nreturn { ' + names.join(', ') + ' }'
  return new Function(...Object.keys(deps), body)(...Object.values(deps))
}

module.exports = load
