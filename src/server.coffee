pkg       = require '../package.json'
fs        = require 'fs'
_         = require 'underscore'
mime      = require 'mime'
http      = require 'http'
url       = require 'url'
path      = require 'path'
minimatch = require 'minimatch'


class Server
    name: pkg.name
    version: pkg.version

    defaults: ->
        port: 8000
        host: '0.0.0.0'
        logs: false
        index: 'index.html'

    constructor: (options={}, @exitCallback)->
        @options = _.extend @defaults(), options

        @_initLogs()
        @_bindCloseEvents()

        @start()

    start: ->
        @server = http
        .createServer _.bind(@request, @)
        .listen Number(@options.port), @options.host

    stop: (callback)->
        @server?.close()
        @_loger?.end()

        @exitCallback?()
        callback?()

    _bindCloseEvents: ->
        exit = =>
            process.removeAllListeners 'SIGINT'
            process.removeAllListeners 'SIGTERM'

            @stop -> process.exit()

        process.on 'SIGINT', exit
        process.on 'SIGTERM', exit

    _initLogs: ->
        if @options.logs
            if typeof @options.logs is 'string'
                @_logger = fs.createWriteStream @options.logs, flags: 'a'

            else
                @_log = console.log

    request: (req, res)->
        time = new Date()
        filePath = null

        new Promise (resolve, reject)=>
            uri = url.parse req.url
            resolve uri.pathname

        .then (pathname)=>
            filePath = pathname
            filePath = filePath.replace /\/$/, "/#{@options.index}"
            filePath = filePath.replace /^\//, ""
            filePath = path.resolve process.cwd(), @options.root or './', filePath

            return @processRequest res, filePath

        , (err)=>
            return @errorCode res, 400, "Message: #{err.message}\nURL: #{req.url}\n\n#{err.stack}"

        .catch (err)=>
            if err.code is 'ENOENT'
                return @handlerNotFound res, err.path

            else
                @log "[#{time.toJSON()}] Error: #{err.message}, Code: #{err.code}"
                return @errorCode res, 500, "Message: #{err.message}\nCode: #{err.code}\n\n#{err.stack}"

        .catch (err)=>
            @log "[#{time.toJSON()}] Error: #{err.message}"
            return @errorCode res, 500, "Message: #{err.message}\nCode: #{err.code}\n\n#{err.stack}"

        .then (code)=>
            host = path.join req.headers.host or 'localhost:'+@options.port, req.url

            log  = "[#{time.toJSON()}]"
            log += " (+#{Date.now() - time}ms):"
            log += " #{code}"
            log += " #{host}"
            log += " - #{filePath}" if filePath
            log += " (#{req.headers['user-agent']})" if req.headers['user-agent']

            @log log

    getHeaders: (filePath)->
        headers = "Server": "#{@name}/#{@version}"
        headers["Content-Type"] = mime.lookup filePath if filePath
        return headers

    processRequest: (res, filePath)->
        if handler = @handle filePath
            return handler.call @ res, filePath

        else
            return @handlerStaticFile res, filePath

    handle: (filePath)->
        handlers = _.result @, 'handlers'

        for pattern of handlers
            if minimatch filePath, pattern
                return handlers[pattern]

        return null

    handlers: -> {}

    handlerStaticFile: (res, filePath)->
        server = @

        new Promise (resolve, reject)->
            fs.createReadStream filePath
            .on 'open', ->
                res.writeHead 200, server.getHeaders filePath

            .on 'error', (err)->
                reject err

            .on 'data', (data)->
                res.write data

            .on 'end', ->
                res.end()
                resolve 200

    handlerNotFound: (res, filePath)->
        notFound = =>
            return @errorCode res, 404, "Path: #{filePath}"

        unless @options['404']
            return notFound()

        errorPath = path.resolve process.cwd(), @options['404']

        new Promise (resolve, reject)=>
            fs.createReadStream errorPath
            .on 'open', ->
                res.writeHead 404, _.extend @getHeaders(), "Content-Type": "text/html"

            .on 'error', (err)->
                reject err

            .on 'data', (data)->
                res.write data

            .on 'end', ->
                res.end()
                resolve 404

    errorCode: (res, code, text='')->
        text = "<pre>#{text}</pre>" if text

        res.writeHead code, _.extend @getHeaders(), "Content-Type": "text/html"
        res.write "<h1>#{code} #{http.STATUS_CODES[code]}</h1>" + text
        res.end()

        return code

    log: (string)->
        @_logger?.write string + '\n'
        @_log? string


module.exports = Server
