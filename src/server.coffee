_ = require('lodash')
fs = require('fs')
pkg = require('../package.json')
url = require('url')
path = require('path')
mime = require('mime')
http = require('http')
https = require('https')
minimatch = require('minimatch')

defaultHandlers = require('./handlers')


class Server
    server = null

    @module: pkg.name
    @version: pkg.version

    defaults: ->
        port: 8000
        host: '0.0.0.0'
        logs: false
        index: 'index.html'
        https: false
        key: null
        cert: null
        cors: false
        timeout: 30000

    routes: -> []
    handlers: -> {}

    constructor: (userOptions = {}, userRoutes, userHandlers, exitCallback)->
        options = {}
        handlers = {}
        routes = []

        Object.defineProperty @, 'module',
            enumerable: true
            get: => @constructor.module

        Object.defineProperty @, 'version',
            enumerable: true
            get: => @constructor.version

        Object.defineProperty @, 'exitCallback',
            get: -> exitCallback

        Object.defineProperty @, 'options',
            enumerable: true

            get: -> options

            set: (newOptions)=>
                options = _.assign options, _.result(@, 'defaults'), newOptions
                @restart()

        Object.defineProperty @, '_routes',
            get: ->
                return _.concat routes,
                    pattern: '**'
                    handler: 'file'

            set: (newRoutes)->
                if _.isObject newRoutes
                    newRoutes = _.map newRoutes, (val, key)-> pattern: key, handler: val

                newRoutes = _.chain newRoutes
                .filter 'pattern'
                .filter 'handler'
                .value()

                routes = _.unionBy routes, newRoutes, 'pattern'

        Object.defineProperty @, '_handlers',
            get: -> handlers

            set: (newHandlers)->
                handlers = _.assign handlers, defaultHandlers, newHandlers

        Object.defineProperty @, '_server',
            get: -> server

        @_routes   = _.result @, 'routes'
        @_handlers = _.result @, 'handlers'

        @_routes   = userRoutes
        @_handlers = userHandlers
        @options   = userOptions

    start: ->
        if @options.https
            server = @_startHTTP()

        else
            server = @_startHTTP()

        return @

    restart: ->
        @_stopLogs()
        @_startLogs()

        @_server?.close()
        @start()

        return @

    stop: (callback)->
        @_server?.close()
        @_loger?.end()

        @exitCallback?()
        callback?()

        return @

    log: (string)->
        @_logger?.write string + '\n'
        @_log? string

        return @

    request: (req, res)->
        time = new Date()
        req_params = null
        req_handler = null

        Promise.resolve()
        .then =>
            @_requestData req

        .then (data)=>
            @_navigate req, data

        .then (params)=>
            req_params = params
            req_handler = params.handler

            @_handle params.handler, params, req, res

        .catch (params)->
            return params if params.handler or params.body or params.streamed
            throw  params

        .then (params)=>
            if params.handler
                error_params = _.assign {}, req_params, params
                return @_handle params.handler, error_params, req, res

            return params

        .then (params)=>
            @response res, params, req_params

        .catch (error)=>
            @log "[#{time.toJSON()}] Error: #{error.message or 'none'}"

            error_params = _.assign {}, req_params, error

            @_handle 'serverError', error_params, req, res
            .then (result)=>
                return @response res, result, req_params

        .then (params)=>
            host = path.join req.headers.host or 'localhost:' + @options.port

            log  = "[#{time.toJSON()}]"
            log += " (+#{Date.now() - time}ms):"
            log += " #{params.code}"
            log += "\t#{host}"
            log += " #{req_params.method}"
            log += " #{req_params.uri}"
            log += "\t#{req_params.file}" if req_params.file
            log += "\t(#{req.headers['user-agent']})" if req.headers['user-agent']

            @log log

    response: (res, params, req_params)->
        if params.streamed
            res.end()

        else
            res.writeHead(
                params.code or if params.body then 200 else 204,
                @_responseHeaders params, req_params
            )

            res.write params.body or ''

            res.end()

        return params

    _startHTTP: ->
        return http
        .createServer (req, res)=> @request req, res
        .listen @options.port, @options.host

    _startHTTPS: ->
        cert = @_getCert()

        return https
        .createServer cert, (req, res)=> @request req, res
        .listen @options.port, @options.host

    _getCert: ->
        if _.isEmpty @options.key
            throw new Error "Path to key file demanded for running HTTPS server: --key=/path/to/server.key"

        if _.isEmpty @options.cert
            throw new Error "Path to certificate file demanded for running HTTPS server: --key=/path/to/server.cert"

        try
            key = fs.readFileSync path.resolve @options.key

        catch error
            throw new Error "Can't open key file #{@options.key} (error.code)"

        try
            cert = fs.readFileSync path.resolve @options.cert

        catch error
            throw new Error "Can't open cert file #{@options.cert} (error.code)"

        return {key, cert}

    _stopLogs: ->
        @_logger?.end()

        delete @_logger
        delete @_log

    _startLogs: ->
        return unless @options.logs

        if typeof @options.logs is 'string'
            @_logger = fs.createWriteStream @options.logs, flags: 'a'

        else
            @_log = console.log

    _requestData: (req)->
        new Promise (resolve, reject)->
            data = []

            req.on 'data', (chunk)-> data.push chunk

            req.on 'end', -> resolve Buffer.concat data

            req.on 'error', (error)-> reject error

    _responseHeaders: (response, request)->
        srvName = "#{@module}/#{@version}"

        headers =
            'Server': srvName
            'X-Server': srvName

        headers['Content-Type'] = mime.getType request.file if request.file

        if @options.cors
            allowHeaders = request.headers?['access-control-request-headers']?.split(/,\s*/) or []
            requestHeaders = _.keys request.headers or {}
            requestHeaders = _.union requestHeaders, allowHeaders

            allowMethod = request.headers?['access-control-request-method']
            requestMethods = [request.method or 'GET']
            requestMethods = _.compact _.uniq [request.method, allowMethod]

            headers['Access-Control-Allow-Origin']  = if @options.cors is true then '*' else @options.cors
            headers['Access-Control-Allow-Headers'] = requestHeaders.join(',')
            headers['Access-Control-Allow-Methods'] = requestMethods.join(',')

        return _.defaults response.headers, headers

    _range: (range = '', size = 0)->
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

    _cookie: (cookie)->
        return {} unless cookie

        cookieArr = cookie.split ';'
        cookieObj = {}

        for el in cookieArr
            elSplit = el.split '='

            if elSplit.length >= 2
                cookieObj[elSplit[0].trim()] = elSplit.slice(1).join('=').trim()

        return cookieObj

    _navigate: (req, data)->
        method = req.method
        headers = req.headers
        client_ip = headers['x-forwarded-for'] or req.connection?.remoteAddress
        cookie = @_cookie headers['cookie']
        range = @_range headers['range']

        params = {uri: req.url, method, headers, client_ip, cookie, range, data}

        try
            {pathname, query, search, hash} = url.parse req.url, true

        catch
            return _.assign params, handler: 'notFound', query: {}, search: null, hash: null

        params = _.assign params, {pathname, query, search, hash}

        if method is 'OPTIONS'
            return _.assign params, handler: 'options'

        root = path.resolve process.cwd(), @options.root or './'

        file = pathname
        file = file.replace /\/$/, "/#{@options.index}"
        file = file.replace /^\//, ""
        file = path.join root, file

        params.file = file
        params.handler = @_getHandler(pathname) or 'notFound'

        return params

    _getHandler: (pathname)->
        found = _.find @_routes, ({pattern, handler})=>
            minimatch(pathname, pattern, matchBase: true) and
            (_.isFunction(handler) or _.isFunction(@_handlers[handler]))

        return found?.handler or ''

    _handle: (handler, params, req, res)->
        new Promise (resolve, reject)=>
            start = (code, headers)=>
                res.writeHead code, @_responseHeaders headers, params

            write = (chunk)->
                res.write chunk

            end = (res_params)->
                resolve _.assign res_params, streamed: true

            stream = {start, write, end}

            setTimeout ->
                reject _.assign params, handler: 'timeout'
            , @options.timeout

            try
                if _.isFunction handler
                    handler.call @, params, resolve, reject, stream

                else
                    @_handlers[handler].call @, params, resolve, reject, stream

            catch error
                reject _.assign params, handler: 'serverError', error: error


module.exports = Server
