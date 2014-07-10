formatAsExportTimestamp = require('../../share/utils/datetime').formatAsExportTimestamp

getFileNameTimestamp = (offset) ->
    now = new Date((new Date()).getTime() + offset * 1000)
    return formatAsExportTimestamp(now)
exports.getFileNameTimestamp = getFileNameTimestamp

exports.getFileName = (title, type, offset) ->
    title = title.replace(/[\/\\\n\r\t\0\f`?*<>|":]+/g, '')
    timestamp = getFileNameTimestamp(offset)
    return "#{title.slice(0, 50)}.#{timestamp}.#{type}"
