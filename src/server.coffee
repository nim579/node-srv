pkg       = require '../package.json'
fs        = require 'fs'
_         = require 'underscore'
mime      = require 'mime'
http      = require 'http'
https     = require 'https'
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
        https: false
        key: false
        cert: false

    constructor: (options = {}, @exitCallback)->
        @options = _.extend @defaults(), options

        @_initLogs()
        @_bindCloseEvents()

        @start()

    start: ->
        return @startHTTPS() if @options.https
        return @startHTTP()

    startHTTP: ->
        @server = http
        .createServer _.bind(@request, @)
        .listen Number(@options.port), @options.host

    startHTTPS: ->
        certificateChecked = true
        certOptions = {}

        if _.isEmpty @options.key
            @log "Path to key file demanded for running HTTPS server: --key=/path/to/server.key"
            certificateChecked = false

        if _.isEmpty @options.cert
            @log "Path to certificate file demanded for running HTTPS server: --key=/path/to/server.cert"
            certificateChecked = false


        if certificateChecked
            try
                certOptions.key = fs.readFileSync path.resolve @options.key
            catch error
                if error.code is 'ENOENT'
                    console.log "Can't open key file", @options.key, ' (ENOENT)'
                else
                    console.log error
                certificateChecked = false

            try
                certOptions.cert = fs.readFileSync path.resolve @options.cert
            catch error
                if error.code is 'ENOENT'
                    console.log "Can't open certificate file", @options.cert, ' (ENOENT)'
                else
                    console.log error
                certificateChecked = false

        if not certificateChecked
            console.log "Can't start HTTPS server without valid certificate"
            process.exit(1)

        @server = https
        .createServer certOptions, _.bind(@request, @)
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
        method   = null
        headers  = null

        new Promise (resolve, reject)->
            uri = url.parse req.url
            resolve uri.pathname

        .then (pathname)=>
            rootPath = path.resolve process.cwd(), @options.root or './'

            filePath = pathname
            filePath = filePath.replace /\/$/, "/#{@options.index}"
            filePath = filePath.replace /^\//, ""
            filePath = path.join rootPath, filePath

            throw code: 400, message: "Bad URL: #{pathname}" if filePath.indexOf(rootPath) isnt 0

            method  = req.method
            headers = req.headers

            return @processRequest res, filePath, method, headers

        , (err)=>
            return @errorCode res, 400, "Message: #{err.message}\nURL: #{req.url}\n\n#{err.stack}"

        .catch (err)=>
            if err.code is 'ENOENT'
                return @handlerNotFound res, err.path, method, headers

            else if err.code in [400, 405]
                @log "[#{time.toJSON()}] Error: #{err.message}, Code: #{err.code}"
                return @errorCode res, 405, "Message: #{err.message}\nCode: #{err.code}"

            else
                @log "[#{time.toJSON()}] Error: #{err.message}, Code: #{err.code}"
                return @errorCode res, 500, "Message: #{err.message}\nCode: #{err.code}\n\n#{err.stack}"

        .catch (err)=>
            @log "[#{time.toJSON()}] Error: #{err.message}"
            return @errorCode res, 500, "Message: #{err.message}\nCode: #{err.code}\n\n#{err.stack}"

        .then (code)=>
            host = path.join req.headers.host or 'localhost:' + @options.port, req.url

            log  = "[#{time.toJSON()}]"
            log += " (+#{Date.now() - time}ms):"
            log += " #{code}"
            log += " #{method}"
            log += " #{host}"
            log += " - #{filePath}" if filePath
            log += " (#{req.headers['user-agent']})" if req.headers['user-agent']

            @log log

    getHeaders: (filePath)->
        headers = "Server": "#{@name}/#{@version}"

        if filePath
            headers["Content-Type"] = mime.lookup filePath

        return headers

    _parseRange: (range = '', size = 0)->
        return null unless String(range).indexOf('bytes=') is 0

        firstRangeStr = range.replace('bytes=', '').split(',')[0]
        return null unless firstRangeStr.indexOf('-') > -1

        [start, end] = firstRangeStr.split('-')
        start = parseInt start, 10
        end   = parseInt end,   10

        if _.isNaN(start)
            start = size - end
            end   = size - 1

        else if _.isNaN(end)
            end   = size - 1

        if end > size - 1
            end   = size - 1

        return null if _.isNaN(start) or _.isNaN(end) or start > end or start < 0
        return {start, end}

    fileStats: (path)->
        new Promise (resolve, reject)->
            fs.stat path, (err, stats)->
                return reject err if err
                return resolve stats

    processRequest: (res, filePath, method, headers)->
        if handler = @handle filePath
            return handler.call @, res, filePath, method, headers

        else
            return @handlerStaticFile res, filePath, method, headers

    handle: (filePath)->
        handlers = _.result @, 'handlers'

        for pattern of handlers
            if minimatch filePath, pattern
                return handlers[pattern]

        return null

    handlers: -> {}

    handlerStaticFile: (res, filePath, method, reqHeaders)->
        load = (range, headers, successCode)->
            new Promise (resolve, reject)->
                fs.createReadStream filePath, range
                .on 'open', ->
                    res.writeHead successCode, headers

                .on 'error', (err)->
                    reject err

                .on 'data', (data)->
                    res.write data

                .on 'end', ->
                    res.end()
                    resolve successCode

        Promise.resolve()
        .then =>
            @fileStats filePath

        .then (stats)=>
            range = @_parseRange reqHeaders['range'], stats.size
            code = if range then 206 else 200

            headers = @getHeaders filePath
            headers["Accept-Ranges"] = 'bytes'

            if range
                headers['Content-Range']  = "#{range.start}-#{range.end}/#{stats.size}"
                headers['Content-Length'] = range.end - range.start

            else
                headers['Content-Length'] = stats.size

            if method is 'HEAD'
                res.writeHead code, headers
                res.end()
                return code

            else if method is 'GET'
                return load range, headers, code

            else
                throw code: 405, message: "#{method} method not allowed"

    handlerNotFound: (res, filePath, method, headers)->
        code = 404

        notFound = =>
            return @errorCode res, code, "Path: #{filePath}"

        unless @options[code]
            return notFound()

        errorPath = path.resolve process.cwd(), @options[code]
        headers = _.extend @getHeaders(), "Content-Type": "text/html"

        if method is 'HEAD'
            res.writeHead code, headers
            res.end()
            return code

        else if method is 'GET'
            new Promise (resolve, reject) ->
                fs.createReadStream errorPath
                .on 'open', ->
                    res.writeHead code, headers

                .on 'error', (err)->
                    reject err

                .on 'data', (data)->
                    res.write data

                .on 'end', ->
                    res.end()
                    resolve code
        else
            throw code: 405, message: "#{method} method not allowed"

    errorCode: (res, code, text = '')->
        text = "<pre>#{text}</pre>" if text

        res.writeHead code, _.extend @getHeaders(), "Content-Type": "text/html"
        res.write "<h1>#{code} #{http.STATUS_CODES[code]}</h1>" + text
        res.end()

        return code

    log: (string)->
        @_logger?.write string + '\n'
        @_log? string


module.exports = Server
