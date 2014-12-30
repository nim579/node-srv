pkg     = require '../package.json'
server  = require './server'
program = require 'commander'
_       = require 'underscore'
root    = ''

try
    root = _.without(JSON.parse(process.env.npm_config_argv).original, 'start', 'node-srv', 'run-script', 'npm')[0]

catch e
    root = process.cwd()

program.version pkg.version
    .option '-p, --port [number]', 'Sets port on which the server will work', process.env.PORT or '8000'
    .option '-r, --root [path]', 'Sets the root from which the server will run', root
    .option '-h, --host [host]', 'Sets hots on which the server will work', '0.0.0.0'
    .option '-i, --index [file]', 'Sets the index file for opening like default file in directories', 'index.html'
    .option '-l, --logs [path/boolean]', 'Logs writing flag', false
    .option '--404 [path]', 'Path to 404 error page', null
    .option '--500 [path]', 'Path to 500 error page', null
    .parse process.argv

srv = new server program
srv.exitCallback = ->
    console.log 'Server was shutdown at ' + new Date().toJSON()
