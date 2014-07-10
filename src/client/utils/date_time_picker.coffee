{formatAsClientDate} = require('../../share/utils/date_converter')
{KeyCodes} = require('./key_codes')
ck = window.CoffeeKup
MicroEvent = require('./microevent')

calendricalDateRegexp = /\d{1,2}\/\d{1,2}\/\d{4}/
dateRegexp = /\d{1,2}\.\d{1,2}\.\d{4}/
timeRegexp = /\d{1,2}:\d{1,2}/
universalRegexps = [
    {name: 'datetime_with_year',    regexp: /\d{1,2}\.\d{1,2}\.\d{2,4}\s+\d{1,2}:\d{1,2}/}
    {name: 'datetime',              regexp: /\d{1,2}\.\d{1,2}\s+\d{1,2}:\d{1,2}/}
    {name: 'time',                  regexp: /\d{1,2}:\d{1,2}/}
]

universalDateRegexps = [
    {name: 'date_with_year',        regexp: /\d{1,2}\.\d{1,2}\.\d{2,4}/}
    {name: 'date',                  regexp: /\d{1,2}\.\d{1,2}/}
    {name: 'calendrical_date',      regexp: /\d{1,2}\/\d{1,2}\/\d{4}/}
    {name: 'add_days',              regexp: /\+\d{1,2}/}
    {name: 'day',                   regexp: /\d{1,2}/}
]

allUniversalRegexps = universalRegexps.concat(universalDateRegexps)

class DateTimePicker
    init: (@_dateInput, @_timeInput, positionInBody=false) ->
        $date = $(@_dateInput)
        $date.calendricalDate({positionInBody})
        $date.change => @_processDateChange($date.val(), $time.val())
        $time = $(@_timeInput)
        $time.calendricalTime({isoTime: true, positionInBody})
        $time.change => @_processTimeChange($date.val(), $time.val())

    initUniversalInput: (@_universalInput, positionInBody=false) ->
        $input = $(@_universalInput)
        $input.calendricalDate({positionInBody})
        processInput = =>
            res = @_parseUniversalInput($input.val(), allUniversalRegexps)
            if res
                [date, time] = res
                @emit('universal-change', null, date, time)
            else
                @emit('universal-change', true)
        $input.change(processInput)
        $input.keypress (e) ->
            return if e.keyCode isnt KeyCodes.KEY_ENTER
            e.stopPropagation()
            e.preventDefault()
            processInput()

    _findFormat: (str, regexps) ->
        return ['empty'] if not str
        for {name, regexp} in regexps
            res = str.match(regexp)
            return [name, res[0]] if res
        return ['wrong']

    _parseDate: (date, curYear, divider='.') ->
        ###
        @param date: строка даты в формате dd.mm или dd.mm.yy или dd.mm.yyyy
        @param today: текущее время
        @return: [year, month, day]
        ###
        curYear += ''
        elems = date.split(divider)
        count = elems.length
        if count == 2
            year = curYear
        else
            year = elems[2]
            if year.length == 2
                year = curYear[0..1] + year
        return formatAsClientDate(new Date(year, elems[1] - 1, elems[0]))

    _parseUniversalInput: (str, regexps) ->
        ###
        @param tag_datetime_str: строка даты может содержать:
        - 5 день (если текущий день месяца больше указанного дня,
          то возвращаем указанный день следующего месяца);
        - +5 количество прибавляемых дней;
        - 20.06 день, месяц;
        - 20.06.11/2011 день, месяц, год;
        - 20.06 15:00 день, месяц, время;
        - 20.06.11/2011 15:00 день, месяц, год, время;
        - 15:00 время
        Возвращаем объект datetime.datetime, время серверное,
        если вермя не указано то время 00:00:00.
        Если tag_datetime_str неудовлетворяет условиям постановки даты
        возвращаем None
        ###
        now = new Date()
        curYear = now.getFullYear()
        curMonth = now.getMonth()
        curDay = now.getDate()
        [formatName, matchedString] = @_findFormat(str, regexps)
        switch formatName
            when 'empty'
                return [null]
            when 'day'
                res = new Date(curYear, curMonth, matchedString)
                startOfDay = new Date(now).clearTime()
                res.addMonths(1) if res < startOfDay
                return [formatAsClientDate(res)]
            when 'add_days'
                res = new Date(now)
                res.addDays(matchedString - 0)
                return [formatAsClientDate(res)]
            when 'date'
                return [@_parseDate(matchedString, curYear)]
            when 'calendrical_date'
                return [@_parseDate(matchedString, curYear, '/')]
            when 'date_with_year'
                return [@_parseDate(matchedString, curYear)]
            when 'datetime'
                [date, time] = matchedString.split(' ')
                return [@_parseDate(date, curYear), time]
            when 'datetime_with_year'
                [date, time] = matchedString.split(' ')
                return [@_parseDate(date, curYear), time]
            when 'time'
                return [formatAsClientDate(now), matchedString]
        return null

    _processDateChange: (date, time) ->
        if !date
            time = ''
        else
            res = @_parseUniversalInput(date, universalDateRegexps)
            [date] = res if res
        $(@_dateInput).val(date)
        $(@_timeInput).val(time)
        @emit('change', date, time)

    _processTimeChange: (date, time) ->
        if !!time && !date
            date = formatAsClientDate(new Date())
            $(@_dateInput).val(date)
        @emit('change', date, time)

    validate: (date, time) ->
        [@_dateIsValid(date), @_timeIsValid(date, time)]

    get: ->
        [$(@_dateInput).val(), $(@_timeInput).val()]

    _dateIsValid: (date) ->
        return true if not date? or date is ''
        return false if not date.match(dateRegexp)
        return true

    _timeIsValid: (date, time) ->
        return true if not time? or time is ''
        return false if not time.match(timeRegexp)
        return true

    destroy: ->
        $('.calendricalDatePopup,.calendricalDatePopup').remove()
        @removeListeners('change')

MicroEvent.mixin(DateTimePicker)
module.exports = {DateTimePicker}