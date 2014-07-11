util = require('util')

connectLogger = (thislogger, options) ->
    ###
    Возвращает мидлварь для express логгера
    ###
    if 'object' == typeof options
        options = options or {}
    else if options
        options = { format: options }
    else
        options = {}

    level = options.level or 'info'
    fmt = options.format or ':remote-addr - - ":method :url HTTP/:http-version" :status :content-length ":referrer" ":user-agent"'

    format = (str, req, res) ->
        return str
            .replace(':url', req.originalUrl)
            .replace(':method', req.method)
            .replace(':status', res.__statusCode or res.statusCode)
            .replace(':response-time', res.responseTime)
            .replace(':date', new Date().toUTCString())
            .replace(':referrer', req.headers['referer'] or req.headers['referrer'] or '')
            .replace(':http-version', req.httpVersionMajor + '.' + req.httpVersionMinor)
            .replace(':remote-addr', req.socket && (req.socket.remoteAddress or (req.socket.socket && req.socket.socket.remoteAddress)))
            .replace(':user-agent', req.headers['user-agent'] or '')
            .replace(':content-length', (res._headers && res._headers['content-length']) or (res.__headers && res.__headers['Content-Length']) or '-')
            .replace(/:req\[([^\]]+)\]/g, (_, field) -> return req.headers[field.toLowerCase()])
            .replace(/:res\[([^\]]+)\]/g, (_, field) ->
                return if res._headers then res._headers[field.toLowerCase()] or res.__headers[field] else res.__headers and res.__headers[field]
            )

    getMeta = (req, res) ->
        return {
        "url": req.originalUrl
        "method": req.method
        "status": res.__statusCode or res.statusCode
        "response-time": res.responseTime
        "date": new Date().toUTCString()
        "referrer": req.headers['referer'] or req.headers['referrer'] or ''
        "http-version": req.httpVersionMajor + '.' + req.httpVersionMinor
        "remote-addr": req.socket && (req.socket.remoteAddress or (req.socket.socket && req.socket.socket.remoteAddress))
        "user-agent": req.headers['user-agent'] or ''
        "content-length": (res._headers && res._headers['content-length']) or (res.__headers && res.__headers['Content-Length']) or '-'
        }

    return (req, res, next) ->
        # mount safety
        return next() if (req._logging)

        start = +new Date
        statusCode = null
        writeHead = res.writeHead
        end = res.end
        url = req.originalUrl

        # flag as logging
        req._logging = true

        # proxy for statusCode.
        res.writeHead = (code, headers) ->
            res.writeHead = writeHead
            res.writeHead(code, headers)
            res.__statusCode = statusCode = code
            res.__headers = headers or {}

        # proxy end to output a line to the provided logger.
        res.end = (chunk, encoding) ->
            res.end = end
            res.end(chunk, encoding)
            res.responseTime = +new Date - start
            if 'function' == typeof fmt
                line = fmt(req, res, (str) -> return format(str, req, res))
                thislogger.log(level, line, getMeta(req, res)) if line
            else
                thislogger.log(level, format(fmt, req, res), getMeta(req, res))
        #ensure next gets always called
        next()

originalConsoleFunctions =
    log: console.log,
    debug: console.debug,
    info: console.info,
    warn: console.warn,
    error: console.error


replaceConsole = (logger) ->
    replaceWith = (fnName) ->
        return (args...) ->
            args = args[0] if args.length == 1
            logger[fnName](args)
    ['log','debug','info','warn','error'].forEach((item) ->
        console[item] = replaceWith(if item == 'log' then 'info' else item)
    )

restoreConsole = () ->
    ['log', 'debug', 'info', 'warn', 'error'].forEach((item) ->
        console[item] = originalConsoleFunctions[item]
    )

stringify = (msg, logDepth = 6) ->
    if msg and msg.stack
        output = msg.stack;
    else if typeof msg == 'string'
        output = msg
    else
        output = util.inspect(msg, false, logDepth)
    return output

module.exports =
    connectLogger: connectLogger
    replaceConsole: replaceConsole
    restoreConsole: restoreConsole
    stringify: stringify
