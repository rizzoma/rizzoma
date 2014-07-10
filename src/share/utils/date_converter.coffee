if typeof(module) != 'undefined' and module.exports
    require('date-utils')

###
Утилиты для конвертирования и форматирования дат, которыми обмениваются клиент и сервер.
Сервер хранит либо время timestamp'ом, либо дату iso-строкой
###

dateRegexp = /(\d{4})-(\d{2})-(\d{2})/

convertDate = exports.convertDate = (date) ->
    # Если отдавать парсить строку, то он считает, что строка в UTC, а нам нужна локальная timezone
    [year, month, date] = date.match(dateRegexp)[1..3]
    new Date(year, month-1, date)

convertDatetime = exports.convertDatetime = (datetime) ->
    new Date(datetime * 1000)

exports.convertCalendricalDate = (date) ->
    [day, month, year] = date.split('/')
    new Date(year, month-1, day)

formatAsClientDate = exports.formatAsClientDate = (date) ->
    date.toFormat('DD.MM.YYYY')

formatAsClientTime = exports.formatAsClientTime = (date) ->
    date.toFormat('HH24:MI')

exports.convertDateTimeToClient = (date, datetime) ->
    if datetime
        serverTime = convertDatetime(datetime)
        return [formatAsClientDate(serverTime), formatAsClientTime(serverTime)]
    else if date
        return [formatAsClientDate(convertDate(date))]
    else return []

exports.convertDateTimeToServer = (date, time) ->
    return [] if not date and not time
    [day, month, year] = date.split('.')
    month -= 1
    if date and time
        [hour, minute] = time.split(':')
        localtime = new Date(year, month, day, hour, minute)
        return [undefined, Math.floor(localtime.getTime()/1000)]
    else if date
        localtime = new Date(year, month, day)
        return [localtime.toYMD()]
