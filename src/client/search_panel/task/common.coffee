{convertDate, convertDatetime} = require('../../../share/utils/date_converter')

getComparableDateString = (task) ->
    date = task.deadline?.date
    datetime = task.deadline?.datetime
    return (convertDate(date)).addDays(1).toISOString() if date?
    return (convertDatetime(datetime)).toISOString() if datetime?
    return '9999' + convertDatetime(task.changeDate)

exports.compareTasks = (first, second) ->
    first = getComparableDateString(first)
    second = getComparableDateString(second)
    return 0 if first is second
    return if first < second then -1 else 1
