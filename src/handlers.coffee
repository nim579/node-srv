_ = require('lodash')
fs = require('fs')
http = require('http')
path = require('path')
util = require('util')
stat = util.promisify fs.stat



file = (params, resolve, reject, stream)->
    return reject handler: 'serverError' unless params.file

    Promise.resolve()
    .then ->
        stat params.file

    .then (stats)=>
        range = @_range params.headers['range'], stats.size
        code = if range then 206 else 200

        headers = 'Accept-Ranges': 'bytes'

        if range
            headers['Content-Range']  = "bytes #{range.start}-#{range.end}/#{stats.size}"
            headers['Content-Length'] = 1 + range.end - range.start

        else
            headers['Content-Length'] = stats.size

        return {code, headers, range}

    .then ({code, headers, range})->
        return {code, headers} if params.method is 'HEAD'

        new Promise (resolve, reject)->
            readStream = fs.createReadStream params.file, range
            .on 'open', ->
                stream.start code, headers

            .on 'error', (error)->
                reject {error}
                readStream.close()

            .on 'data', (chunk)->
                stream.write chunk

            .on 'end', ->
                stream.end {code, headers}
                resolve    {code, headers}
                readStream.close()

    .then (result)->
        resolve result

    .catch (error)->
        if error.code is 'ENOENT'
            reject handler: 'notFound'

        else
            reject {error}


notFound = (params, resolve)->
    code = params.code or 404
    headers = 'Content-Type': 'text/html'

    std = ->
        return """
            <h1>#{code} #{http.STATUS_CODES[code]}</h1>
            <pre>#{params.method} #{params.uri}</pre>
        """

    unless @options.notFound
        body = std()
        resolve {code, headers, body}

    else
        filePath = path.resolve process.cwd(), @options.notFound

        fs.readFile filePath, (error, data)->
            body = if error or not data then std() else data
            resolve {code, headers, body}


serverError = (params, resolve)->
    text = "#{params.method} #{params.uri}"
    text += "\nMessage: #{params.error.message}" if params.error

    code = params.code or 500

    headers = 'Content-Type': 'text/html'

    body = """
        <h1>#{code} #{http.STATUS_CODES[code]}</h1>
        <pre>#{text}</pre>
    """

    resolve {code, headers, body}

timeout = (params, resolve)->
    code = params.code or 504

    headers = 'Content-Type': 'text/html'

    body = """
        <h1>#{code} #{http.STATUS_CODES[code]}</h1>
        <pre>#{params.method} #{params.uri}</pre>
    """

    resolve {code, headers, body}


options = (params, resolve)->
    resolve code: 204


module.exports = {file, notFound, serverError, timeout, options}
