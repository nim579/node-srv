pkg     = require '../package.json'
Server  = require './server'
program = require 'commander'
_       = require 'lodash'
path    = require 'path'

try
    root = _.head _.without JSON.parse(process.env.npm_config_argv).original, 'start', 'node-srv', 'run-script', 'npm'

catch e
    root = process.cwd()


program
.version pkg.version
.name pkg.name
.usage '[root] [options]'
.option '-p, --port [number]', 'Sets port on which the server will work', process.env.PORT or '8000'
.option '-h, --host [host]', 'Sets host on which the server will work', '0.0.0.0'
.option '-i, --index [file]', 'Sets the index file for opening like default file in directories', 'index.html'
.option '-l, --logs [path/boolean]', 'Logs writing flag', false
.option '-t, --timeout [ms]', 'Requset timeout', 30000
.option '-s, --https [boolean]', 'Force create https server', false
.option '--key [path]', 'Path to key file for https server', null
.option '--cert [path]', 'Path to certificate file for https server', null
.option '--cors [hosts]', 'Enable CORS. If empty uses * for host', false
.option '--not-found [path]', 'Path to 404 error page', null
.parse process.argv


{port, host, logs, root, index, https, key, cert, cors, notFound, timeout} = program
root = path.resolve _.head(program.args) if _.head(program.args)

srv = new Server {port, host, logs, root, index, https, key, cert, cors, notFound, timeout}, null, ->
    console.log 'Server was shutdown at ' + new Date().toJSON()

process.on 'SIGINT',  -> srv.stop -> process.exit()
process.on 'SIGTERM', -> srv.stop -> process.exit()


# log

host = if program.host and program.host isnt '0.0.0.0' then program.host else 'localhost'

if program.https
    console.log "Secure server node-srv running at\n => https://#{host}:#{program.port}\n"

else
    console.log "Server node-srv running at\n => http://#{host}:#{program.port}\n"

if program.logs
    console.log "Logs are on."

else
    console.log "Logs are off."
