server  = require './server'

program = server.getCommander()
program.parse process.argv

srv = new server program
srv.exitCallback = ->
    console.log 'Server was shutdown at ' + new Date().toJSON()
