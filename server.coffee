pkg    = require './package.json'
mime   = require 'mime'
path   = require 'path'
http   = require 'http'
url    = require 'url'
fs     = require 'fs'
events = require('events').EventEmitter
_      = require 'underscore'


defaultOptions =
    port: 8000
    logs: false
    index: 'index.html'


class serverClass
    constructor: (options)->
        @options = _.extend defaultOptions, options
        @parseLogsPath()

        @ev = new events()
        @stack = []

        @on 'request', @startResponse, @
        @on 'response', @startResponse

        @bindCloseEvents()

        @startServer()

    name: pkg.name
    version: pkg.version

    on:(event, foo, context)->
        @ev.on event, =>
            foo.apply context or @, arguments

    startServer: ()->
        @server = http.createServer (request, response)=>
            @addRequest request, response

        @server.listen Number @options.port
        process.stdout.write "Node.js server running at\n => http://localhost:#{@options.port}/\n"

    stop: (callback)->
        @stack = []
        @server.close() if @server?

    bindCloseEvents: ()->
        exit = =>
            process.removeAllListeners 'SIGINT'
            process.removeAllListeners 'SIGTERM'
            @stop()

            @exitCallback.apply @ if typeof @exitCallback is 'function'

            process.exit()

        process.on 'SIGINT', exit
        process.on 'SIGTERM', exit

    done: (callback, context)->
        if typeof callback is 'function'
            @resolve = ->
                callback.apply context or @, arguments

    response: (resObj)->
        @accessLog resObj

        headers = _.extend "Server": @name + '/' + @version, resObj.mime
        
        resObj.response.writeHead resObj.status, headers
        resObj.response.write resObj.body, if resObj.bodyType? then resObj.bodyType
        resObj.response.end();

    addRequest: (req, res)->
        reqObj =
            request: req
            response: res
            uid: Math.floor Math.random()*10000000
            startTime: new Date()
            uri: decodeURI url.parse(req.url).pathname.replace(/^\//, '').replace(/\/$/, '/'+@options.index)
            body: ''

        
        reqObj.uri = @options.index if reqObj.uri.length is 0
        reqObj.filename = path.resolve process.cwd(),  @options.root or '', reqObj.uri

        @stack.push reqObj
        @ev.emit 'request'

    startResponse: ()->
        if @stack.length > 0
            reqObj = @stack[0]
            @stack = _.without @stack, reqObj

            @responseFile reqObj, (err, resObj)=>
                @response resObj

    responseFile: (reqObj, callback)->
        filePath = reqObj.filename

        handlerCallback = (err, requestObj)=>
            if err
                @response500 reqObj, err, callback
                return false

            callback null, requestObj

        if fs.existsSync filePath
            if handler = @selectHandler filePath
                handler.method reqObj, handlerCallback

            else
                @responseStatic reqObj, handlerCallback

        else
            @response404 reqObj, callback

    responseStatic: (reqObj, callback)->
        filePath = reqObj.filename

        reqObj.mime =  "Content-Type": mime.lookup(filePath)
        reqObj.status = 200
        fs.readFile filePath, "binary", (err, file)=>
            if err
                @response500 reqObj, err, callback
                @errorLog reqObj, 'Error 500: ' + JSON.stringify err
                return false;

            reqObj.body = file
            reqObj.bodyType = "binary"

            callback null, reqObj

    response500: (reqObj, e, callback)->
        body = "Error 500. #{http.STATUS_CODES['500']}. #{JSON.stringify(e)}"

        if fs.existsSync @options['500']
            body = fs.readFileSync @options['500']

        reqObj = _.extend reqObj,
            status: 500
            mime: "Content-Type": 'text/html'
            body: body

        callback 'Error 500', reqObj

    response404: (reqObj, callback)->
        body = "Error 404. #{http.STATUS_CODES['404']}"

        if fs.existsSync @options['404']
            body = fs.readFileSync @options['404']

        reqObj = _.extend reqObj,
            status: 404
            mime: "Content-Type": 'text/html'
            body: body

        callback 'Error 404', reqObj

    writeLog: (message)->
        if @options.logs
            if typeof @options.logs is 'string'
                fs.appendFileSync @options.logs, message

            else
                process.stdout.write message

    parseLogsPath: ()->
        if typeof @options.logs is 'string'
            logPath = path.resolve process.cwd(), @options.logs or ''

            if fs.existsSync logPath
                logPath = path.join logPath, 'node-srv.log' if fs.statSync(logPath).isDirectory()

            @options.logs = logPath

    accessLog: (resObj)->
        data =
            date: resObj.startTime.toJSON()
            time: new Date() - resObj.startTime
            path: path.join(resObj.request.headers.host, resObj.uri)
            filename: resObj.filename
            code: resObj.status
            ua: resObj.request.headers['user-agent']

        tmpl = _.template "[<%= date %>]  (+<%= time %>ms):  <%= path %>  — (<%= filename %>)  Status code: <%= code %> (<%= ua %>)\n"

        @writeLog tmpl data

    errorLog: (resObj, error)->
        data =
            date: resObj.startTime.toJSON()
            time: new Date() - resObj.startTime
            error: error
            path: path.join(resObj.request.headers.host, resObj.uri)
            code: resObj.status
            ua: resObj.request.headers['user-agent']

        tmpl = _.template "[<%= date %>]  (+<%= time %>ms):  Error: <%= error %>  <%= path %>  Status code: <%= code %> (<%= ua %>)\n"

        @writeLog tmpl data

    selectHandler: (filepath)->
        handler = _.find @constructor.fileHandlers, (handlers)->
            if _.isArray handlers.extnames
                return _.contains handlers.extnames, path.extname(filepath).toLowerCase()

            else
                return handlers.extnames is path.extname(filepath).toLowerCase()

        if handler and handler.method
            return handler

        else
            return false


serverClass.fileHandlers = []

serverClass.extendHandlers = (handler)->
    if _.isArray handler
        serverClass.fileHandlers = _.union serverClass.fileHandlers, handler

    else if _.isObject handler
        serverClass.fileHandlers.push handler

    return @

serverClass.extend = (protoProps, staticProps)->
    parent = @

    if  protoProps and _.has protoProps, 'constructor'
        child = protoProps.constructor

    else
        child = -> return parent.apply @, arguments

    _.extend child, parent, staticProps
    _.extend child.prototype, parent.prototype, protoProps

    return child


module.exports = serverClass;