###
Кастомный фильтры для swig.
###

_ = require('underscore')

WORDS_DELIMITER = ' '
truncatewords = (str, wordsCount) ->
    ###
    Аналог Django-truncatewords воозвращает первые wordsCount слов из строки.
    @param str: string
    @param wordsCount: int
    @returns: string
    ###
    return str.split(WORDS_DELIMITER).slice(0, wordsCount).join(WORDS_DELIMITER)

truncatewords_with_dots = (str, wordsCount) ->
    ###
    Аналог Django-truncatewords воозвращает первые wordsCount слов из строки. +три точки если нужно
    @param str: string
    @param wordsCount: int
    @returns: string
    ###
    arr = str.split(WORDS_DELIMITER)
    str = arr.slice(0, wordsCount).join(WORDS_DELIMITER)
    str = str + "..." if arr.length > wordsCount
    return str

nl2br = (str) ->
    return str.replace(/\n/g, '<br />')

strconcat = (str1, str2) ->
    ###
    склеивает 2 строки
    ###
    return str1 + str2

getTimestampWithUTCOffset = require('../../utils/date_utils').DateUtils.getTimestampWithUTCOffset
convertDatetime = require('../../../share/utils/date_converter').convertDatetime
convertDate = require('../../../share/utils/date_converter').convertDate
formatFullDate = require('../../../share/utils/datetime').formatFullDate
formatAsShortTime = require('../../../share/utils/datetime').formatAsShortTime
formatAsShortenedDate = require('../../../share/utils/datetime').formatAsShortenedDate

convertTimestamp = (datetime, UTCOffset) ->
    datetime = getTimestampWithUTCOffset(datetime, UTCOffset)
    return convertDatetime(datetime)

formated_date = (date, UTCOffset) ->
    return formatFullDate(convertDate(date)) if _.isString(date)
    return _formatFromTimestamp(date, UTCOffset, formatFullDate)

formated_short_date = (date, UTCOffset) ->
    return formatAsShortenedDate(convertDate(date)) if _.isString(date)
    return _formatFromTimestamp(date, UTCOffset, formatAsShortenedDate)

formated_time = (datetime, UTCOffset) ->
    return _formatFromTimestamp(datetime, UTCOffset, formatAsShortTime)

_formatFromTimestamp = (timestamp, UTCOffset, format) ->
    if _.isNumber(timestamp)
        timestamp = convertTimestamp(timestamp, UTCOffset)
        return format(timestamp)
    return ''

contains_semicolon = (string) ->
    return string.indexOf(';') != -1


swig_escape = require('swig/lib/filters').escape
escape_and_nl2br = (string) ->
    nl2br(swig_escape(string))

USER_SIZES = ['b', 'Kb', 'Mb', 'Gb']
SIZE_MULTIPLIER = 1024
format_size = (size) ->
    multiplierIndex = 0
    while USER_SIZES[multiplierIndex] and size > SIZE_MULTIPLIER
        multiplierIndex++
        size /= SIZE_MULTIPLIER
    size = Math.round(size * 10) / 10
    return "#{size} #{USER_SIZES[multiplierIndex]}"

percent = (a, b) ->
    try
        return Math.round(a / b * 100) || 0
    catch e
        return 0


# Helpers for json_script_encode. Using "SockJS-Node" source code (MIT licensed).
# @todo: propose this addition to upstream version of Swig as json_encode('js') filter
# Replace:
#  1. values from https://github.com/sockjs/sockjs-node/blob/e3d36959cb42b1b6f9931cf0939c6f4b6ccc07cc/src/utils.coffee#L87
#  2. "<" for "</script>" case
#  3. ">" for "-->" case
escapable = /[\x00-\x1f\ud800-\udfff\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufff0-\uffff<>]/g

unroll_lookup = (escapable) ->
    unrolled = {}
    c = for i in [0...65536]
        String.fromCharCode(i)
    escapable.lastIndex = 0
    c.join('').replace escapable, (a) ->
        unrolled[ a ] = '\\u' + ('0000' + a.charCodeAt(0).toString(16)).slice(-4)
    return unrolled

lookup = unroll_lookup(escapable)

json_script_encode = (input, indent) ->
    ###
    Version of "json_encode" safe for embedding result into HTML <script> tag contents.
    Usage: <script>var v = {{ v|json_script_encode|raw }};</script>
    ###
    quoted = JSON.stringify(input, null, indent || 0)

    # In most cases normal json encoding fast and enough
    escapable.lastIndex = 0
    if not escapable.test(quoted)
        return quoted

    return quoted.replace escapable, (a) ->
        return lookup[a]

module.exports = {
    truncatewords
    truncatewords_with_dots
    nl2br
    strconcat
    formated_date
    formated_short_date
    formated_time
    contains_semicolon
    escape_and_nl2br
    format_size
    percent
    json_script_encode
}
