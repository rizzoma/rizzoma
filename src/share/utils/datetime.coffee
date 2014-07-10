###
Функции для работы с датой и временем

В коде Datetime - формат времени, приходящий с сервера (кол-во секунд от начала unix timestamp),
DateTime - "дата и время"
###
if typeof(module) != 'undefined' and module.exports
    Globalize = require('globalize')
    require('globalize/globalize.culture.en-US')

{convertDatetime} = require('./date_converter')

init = exports.init = (culture) ->
    Globalize.culture(culture)

_TIME_SHORT = exports._TIME_SHORT = "t"
_DATE_SHORT = exports._DATE_SHORT = "d MMM"
_DATE_WITH_YEAR = "d MMM yyyy"
_DATE_TIME_SHORT = "d MMM h:mm tt"
_DATE_TIME_WITH_YEAR = "d MMM yyyy h:mm tt"
_DATE = exports._DATE = "MMM yyyy"
LONG_DATE_SHORT_TIME = "f"
_LONG_DATE = 'dddd, MMMM dd, yyyy'
_ISO_DATE = 'S'
_EXPORT_TIMESTAMP = 'yyyy-MM-dd(hh-mmtt)'

_getFormat = exports._getFormat = (serverDate, clientToday) ->
    ###
    @param serverDate: Date - дата пришедшая с сревера;
    @param clientToday: Date - текущая дата на клиенте;
    Приватная функция, экспортируется для тестов
    ###
    return _TIME_SHORT if serverDate > clientToday
    if serverDate.getDate() == clientToday.getDate() and serverDate.getMonth() == clientToday.getMonth() and serverDate.getYear() == clientToday.getYear()
        return _TIME_SHORT
    if (clientToday - serverDate) < 2*60*60*1000
        return _TIME_SHORT
    if (clientToday - serverDate) < 60*24*60*60*1000
        return _DATE_SHORT
    if serverDate.getYear() == clientToday.getYear()
        return _DATE_SHORT
    return _DATE

formatDate = exports.formatDate = (ts, full=false) ->
    ###
    Форматирует timestamp в читаемую дату
    @param ts: int, unix timestamp
    @return: string
    ###
    serverDate = convertDatetime(ts)
    return Globalize.format(serverDate, LONG_DATE_SHORT_TIME) if full
    clientToday = new Date()
    format = _getFormat(serverDate, clientToday)
    return Globalize.format(serverDate, format)

exports.formatAsShortDate = (date) ->
    Globalize.format(date, _DATE_SHORT)

exports.formatAsShortTime = (date) ->
    Globalize.format(date, _TIME_SHORT)

exports.formatFullDate = (date) ->
    Globalize.format(date, _LONG_DATE)

exports.formatAsShortenedDate = (date) ->
    if date.getYear() == (new Date).getYear()
        format = _DATE_SHORT
    else
        format = _DATE_WITH_YEAR
    return Globalize.format(date, format)

exports.formatAsShortenedDateTime = (date) ->
    if date.getYear() == (new Date).getYear()
        format = _DATE_TIME_SHORT
    else
        format = _DATE_TIME_WITH_YEAR
    return Globalize.format(date, format)

exports.formatAsISODate = (ts) ->
    return Globalize.format(new Date(ts*1000), _ISO_DATE)
    
exports.formatAsExportTimestamp = (date) ->
    return Globalize.format(date, _EXPORT_TIMESTAMP)
