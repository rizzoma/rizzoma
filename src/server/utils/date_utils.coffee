class DateUtils
    ###
    Вспомогательный класс для работы с датами/временем.
    ###
    getCurrentTimestamp: () ->
        ###
        Возвращает текущий таймстамп без миллисекунд.
        @return int
        ###
        return @withoutMilliseconds(Date.now())

    withoutMilliseconds: (ts) ->
        ###
        Возвращает таймстамп без миллисекунд.
        @param ts: number - таймстамп с миллисекундами.
        ###
        return Math.round(ts / 1000)

    getTimestamp: (str) ->
        ###
        Пытается распарсить строку с датой и возвращает таймстамп без миллисекунд.
        @param str: string - строка с датой
        @returns: int
        ###
        return @withoutMilliseconds(Date.parse(str))

    getTimestampWithUTCOffset: (ts, offset=0) ->
        return ts + offset * 3600

    getDatetimeByTimestampWithoutMS: (ts) ->
        return new Date(ts * 1000)

    getDateByTimestampWithoutMS: (ts) ->
        date = @getDatetimeByTimestampWithoutMS(ts)
        return new Date(date.getFullYear(), date.getMonth(), date.getDate())

    getCurrentDate: () ->
        date =  @getDateByTimestampWithoutMS(@getCurrentTimestamp()).getTime()
        return Math.round(date / 1000)

module.exports.DateUtils = new DateUtils()
