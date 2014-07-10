###
    Limit middleware for jQuery form plugin based on connect limit middleware
###
Conf = require('../../conf').Conf
logger = Conf.getLogger('jqueryFormLimit')

module.exports.jqueryFormLimit = (bytes) ->
    bytes = parse(bytes) if ('string' is typeof bytes)
    throw new Error('limit() bytes required') if ('number' != typeof bytes)
    return (req, res, next) ->
        received = 0
        len = if req.headers['content-length'] then parseInt(req.headers['content-length'], 10) else null

        # deny the request
        deny = ->
            res.end('{"error": "Your file size is too large.", "res": null}')
            logger.warn 'Limit by chunked data exceeded'
            req.destroy()

        # self-awareness
        return next() if (req._limit)
        req._limit = true

        # limit by content-length
        if (len && len > bytes)
            res.end('{"error": "Your file size is too large.", "res": null}')
            logger.warn 'Limit by content-length exceeded'
            req.destroy()
            return

        # limit
        req.on 'data', (chunk) ->
            received += chunk.length
            deny() if (received > bytes)
        next()

###
 * Parse byte `size` string.
 *
 * @param {String} size
 * @return {Number}
 * @api private
###

parse = (size) ->
    parts = size.match(/^(\d+(?:\.\d+)?) *(kb|mb|gb)$/)
    n = parseFloat(parts[1])
    type = parts[2]

    map =
        kb: 1024
        mb: 1024 * 1024
        gb: 1024 * 1024 * 1024

    map[type] * n
