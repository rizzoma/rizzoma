util = require('util')
winston = require('winston')
Graylog2 = require('winston-graylog2').Graylog2
compress = require('compress-buffer').compress
stringify = require('./utils').stringify

class Graylog2Logger extends Graylog2

    constructor: (options) ->
        super(options)
        @appInfo = options.appInfo
        if @appInfo
            @facilityApp = options.facilityApp
            @facilityCategory = options.facilityCategory
            @facilityPid = options.facilityPid
        @name = 'Graylog2Logger'

    log: (level, msg, meta, callback) ->
        message = {}

        return callback(null, true) if @silent

        # Must be in this format: https://github.com/Graylog2/graylog2-docs/wiki/GELF
        message.version = "1.0"
        message.timestamp = Date.now() / 1000
        message.host = @graylogHostname
        message.facility = @graylogFacility
        message.short_message = stringify(msg)
        message.full_message = if meta then stringify(meta) else {}
        if @appInfo
            message['_facility_app'] = @facilityApp
            message['_facility_category'] = @facilityCategory
            message['_facility_pid'] = @facilityPid
        message.level = @_getMessageLevel(level)
        @_putMeta(meta, message)

        compressedMessage = compress(new Buffer(JSON.stringify(message)))

        if compressedMessage.length > 8192
            return callback(new Error("Log message size > 8192 bytes not supported."), null)

        @udpClient.send(compressedMessage, 0, compressedMessage.length, @graylogPort, @graylogHost, (err, bytes) ->
            return callback(err, null) if err
            callback(null, true)
        )

    _putMeta: (meta, message) ->
        if meta and typeof meta == 'object'
            if meta.stack
                message['_stacktrace'] = meta.stack
            else
                for key, v of meta
                    message['_'+key] = stringify(v) if key != 'id'

    _getMessageLevel: (winstonLevel) ->
        switch winstonLevel
            when 'silly' then return 7
            when 'debug' then return 7
            when 'verbose' then return 6
            when 'data' then return 6
            when 'prompt' then return 6
            when 'input' then return 6
            when 'info' then return 6
            when 'help' then return 5
            when 'notice' then return 5
            when 'warn' then return 4
            when 'warning' then return 4
            when 'error' then return 3
            when 'crit' then return 2
            when 'alert' then return 1
            when 'emerg' then return 0
            else return 6

module.exports.Graylog2Logger = Graylog2Logger