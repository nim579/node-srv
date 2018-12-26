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
    .option '-h, --host [host]', 'Sets host on which the server will work', '0.0.0.0'
    .option '-i, --index [file]', 'Sets the index file for opening like default file in directories', 'index.html'
    .option '-l, --logs [path/boolean]', 'Logs writing flag', false
    .option '-s, --https [boolean]', 'Force create https server', false
    .option '-k, --key [path]', 'Path to key file for https server', null
    .option '-c, --cert [path]', 'Path to certificate file for https server', null
    .option '--404 [path]', 'Path to 404 error page', null
    .parse process.argv

srv = new server program, ->
    console.log 'Server was shutdown at ' + new Date().toJSON()

host = 'localhost'

if program.host and program.host isnt '0.0.0.0'
    host = program.host

if program.https
    console.log "Secure server node-srv running at\n => https://#{host}:#{program.port}\n"

else
    console.log "Server node-srv running at\n => http://#{host}:#{program.port}\n"

if program.logs
    console.log "Logs are on."

else
    console.log "Logs are off."
