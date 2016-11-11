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
            try
                uri = url.parse req.url
                resolve uri.pathname

            catch e
                e.url = req.url
                reject e

        .then (pathname)=>
            filePath = pathname
            filePath = filePath.replace /\/$/, "/#{@options.index}"
            filePath = filePath.replace /^\//, ""
            filePath = path.resolve process.cwd(), @options.root or './', filePath

            return @processRequest filePath

        , (err)=>
            return @errorCode 400, "Message: #{err.message}\nURL: #{err.url}\n\n#{err.stack}"

        .catch (err)=>
            if err.code is 'ENOENT'
                return @processNotFound err.path

            else
                @log "[#{time.toJSON()}] Error: #{err.message}, Code: #{err.code}"
                return @errorCode 500, "Message: #{err.message}\nCode: #{err.code}\n\n#{err.stack}"

        .catch (err)=>
            @log "[#{time.toJSON()}] Error: #{err.message}"
            return @errorCode 500, "Message: #{err.message}\n\n#{err.stack}"

        .then (data)=>
            return @response res, data

        .then (data)=>
            host = path.join req.headers.host or 'localhost:'+@options.port, req.url

            log  = "[#{time.toJSON()}]"
            log += " (+#{Date.now() - time}ms):"
            log += " #{data.code}"
            log += " #{host}"
            log += " - #{filePath}" if filePath
            log += " (#{req.headers['user-agent']})" if req.headers['user-agent']

            @log log

    response: (res, data)->
        new Promise (resolve)->
            headers = _.extend "Server": "#{@name}/#{@version}", data.headers

            res.writeHead data.code, headers
            res.write data.body, if data.bodyType then data.bodyType

            res.end -> resolve data

    processRequest: (filePath)->
        if handler = @handle filePath
            return handler filePath

        else
            return @loadFile filePath

    processNotFound: (filePath)->
        notFound = =>
            return @errorCode 404, "Path: #{filePath}"

        unless @options['404']
            return notFound()

        errorPath = path.resolve process.cwd(), @options['404']

        new Promise (resolve)=>
            fs.readFile errorPath, 'binary', (err, data)->
                if err
                    return resolve notFound()

                resolve
                    code: 404
                    body: data
                    bodyType: "binary"
                    headers: "Content-Type": "text/html"

    handle: (filePath)->
        for pattern of @handlers
            if minimatch filePath, pattern
                return @handlers[pattern]

        return null

    loadFile: (filePath)->
        new Promise (resolve, reject)->
            fs.readFile filePath, 'binary', (err, data)->
                if err
                    return reject err

                resolve
                    code: 200
                    body: data
                    bodyType: "binary"
                    headers: "Content-Type": mime.lookup filePath

    errorCode: (code, text='')->
        text = "<pre>#{text}</pre>" if text

        return {
            code: code
            body: "<h1>#{code} #{http.STATUS_CODES[code]}</h1>" + text
            headers: "Content-Type": "text/html"
        }

    log: (string)->
        @_logger?.write string + '\n'
        @_log? string


module.exports = Server
