winston = require('winston')
colors = require('colors')
stringify = require('./utils').stringify


class CategoriedStdoutLogger extends winston.transports.Console
    ###
    транспорт для winston, который выводит категорию и сообщение в stdout
    ###
    constructor: (options) ->
        options = options or {}
        super(options)
        @name = 'StdoutCategoriedLogger'
        @level = options.level or 'info'
        @category = options.category or 'system'
        # писать ли мету
        @meta = options.meta != false

        @ISO8601_FORMAT = "yyyy-MM-dd hh:mm:ss.SSS"
        @_colors =
            debug: 'cyan'
            info: 'green'
            notice: 'blue'
            warning: 'yellow'
            error: 'red'
            crit: 'magenta'
            alert: 'yellow'
            emerg: 'red'

    log: (level, msg, meta, callback) ->
        return callback(null, true) if @silent
        output = "[#{@_formatDate(new Date())}] [#{level.toUpperCase()}] #{@category} - "
        output = colors[@_colors[level]](output) if @colorize
        output += stringify(msg)
        output += @_logMeta(meta)
        process.stdout.write(output + "\n")
        @emit('logged');
        callback(null, true)

    _logMeta: (meta) ->
        output = ''
        if meta and @meta
            output += ' ' + stringify(meta)
        return output

    _formatDate: (date) ->
        ###
        @param [format {String}]
        @param [date {Date}]
        return {String}
        ###
        format = @ISO8601_FORMAT
        if typeof(date) == "string"
            format = arguments[0]
            date = arguments[1]

        vDay = @_addZero(date.getDate())
        vMonth = @_addZero(date.getMonth()+1)
        vYearLong = @_addZero(date.getFullYear())
        vYearShort = @_addZero(date.getFullYear().toString().substring(3,4))
        vYear = if format.indexOf("yyyy") > -1 then vYearLong else vYearShort
        vHour  = @_addZero(date.getHours())
        vMinute = @_addZero(date.getMinutes())
        vSecond = @_addZero(date.getSeconds())
        vMillisecond = @_padWithZeros(date.getMilliseconds(), 3)
        vTimeZone = @_offset(date)
        formatted = format
            .replace(/dd/g, vDay)
            .replace(/MM/g, vMonth)
            .replace(/y{1,4}/g, vYear)
            .replace(/hh/g, vHour)
            .replace(/mm/g, vMinute)
            .replace(/ss/g, vSecond)
            .replace(/SSS/g, vMillisecond)
            .replace(/O/g, vTimeZone)
        return formatted

    _padWithZeros: (vNumber, width) ->
        numAsString = vNumber + ""
        while numAsString.length < width
            numAsString = "0" + numAsString
        return numAsString

    _addZero: (vNumber) ->
        return @_padWithZeros(vNumber, 2)

    _offset: (date) ->
        # Difference to Greenwich time (GMT) in hours
        os = Math.abs(date.getTimezoneOffset())
        h = String(Math.floor(os/60))
        m = String(os%60)
        h = "0" + h if h.length == 1
        m = "0" + m if m.length == 1
        return if date.getTimezoneOffset() < 0 then "+"+h+m else "-"+h+m


module.exports.CategoriedStdoutLogger = CategoriedStdoutLogger
