Model = require('../common/model').Model
DateUtils = require('../utils/date_utils').DateUtils

TEAM_STATES = require('./constants').TEAM_STATES

ACTION_DELETE_FROM_TOPIC = require('../wave/constants').ACTION_DELETE_FROM_TOPIC
MINIMAL_INTERVAL = 15 * 60
ONE_DAY = 3600 * 24
BLOCKING_TIMEOUT = ONE_DAY * 7
TRIAL_PERIOD  = ONE_DAY * 30



class TeamModel extends Model
    constructor: (@_topic) ->
        super('topicPlugin')

    setBalance: (value, lastWriteOffDate, debtSince, notificationSent, isTrial=no) ->
        balance = @getBalance()
        balance.value = value
        balance.lastWriteOffDate = lastWriteOffDate
        balance.debtSince = debtSince
        balance.notificationSent = notificationSent
        balance.isTrial = isTrial

    setTrialBalance: (user) ->
        trialEndDate = user.getOrCreateTrialStartDate() + TRIAL_PERIOD
        now = DateUtils.getCurrentDate()
        trialEndDate = now if trialEndDate <= now
        @setBalance(0, trialEndDate, null, false, yes)

    getBalance: () ->
        return @_topic._balance

    isNotificationSent: () ->
        return !!@getBalance().notificationSent

    markAsSent: () ->
        @getBalance().notificationSent = true

    calculateTopicBalance: () ->
        now = DateUtils.getCurrentDate()
        balance = @getBalance()
        state = @_getState()
        return if state == TEAM_STATES.TEAM_STATE_TRIAL
        return if state == TEAM_STATES.TEAM_STATE_BLOCKED
        if state == TEAM_STATES.TEAM_STATE_SHOULD_BE_BLOCKED
            @_blockAfterTrial()
            return true
        value = 0
        for participant in @_topic.participants
            value += @_getParticipantDayCount(balance.lastWriteOffDate, now, participant)
        #Если value == 0, значит в топике ничего не изменилось. Например, из-за того, что рассчет сегодня уже запускался.
        return if value == 0
        balance.value -= value
        balance.lastWriteOffDate = now
        balance.debtSince = now if balance.value <= 0 and not balance.debtSince
        return true

    _blockAfterTrial: () ->
        lastWriteOffDate = @getBalance().lastWriteOffDate - BLOCKING_TIMEOUT
        @setBalance(0, lastWriteOffDate, lastWriteOffDate, no ,no)

    _getParticipantDayCount: (start, end, participant) ->
        ###
        Вычисляет количество суток, которое участник провел в топике в интервале [start..end]
        ###
        return 0 if start >= end
        actionLog = participant.actionLog
        intervals = []
        len = actionLog.length-1
        if len < 0
            console.warn("Bugcheck. Team topic without action log #{@_topic.id}")
            return 0
        for i in [0..len]
            #если на текущем интервале участник удален их топика, не берем его в рассмотрение
            continue if actionLog[i].action == ACTION_DELETE_FROM_TOPIC
            #end нхоодится либо внутри интервала, либо вне его
            localEnd = if i == len then end else Math.min(end, actionLog[i+1].date)
            #мы еще не дошли до интервала, который нам интересен
            continue if start > localEnd
            #start находится внури интервала
            localStart = Math.max(actionLog[i].date, start)
            #Не обрабатываем лог-записи, которые были добавлены после end.
            continue if localStart > localEnd
            @_alignIntervals(intervals, localStart, localEnd)
            #дальше следуют более поздние интервалы, которые нас не интересуют, выйдем
            break if localEnd == end
        return 0 if not intervals.length
        #Проверяем длину интервала для последних суток. Т.к. в _alignIntervals она не проверится.
        lastInterval = intervals.slice(-1)[0]
        intervals.splice(-1, 1) if lastInterval.duration < MINIMAL_INTERVAL
        return intervals.length

    _alignIntervals: (intervals, start, end) ->
        ###
        Выравнивание: если пользователь за сутки находился в топике > 15 мин. то округляем до суток.
        Один интервал - это одни сутки.
        В итоге intervals будет иметь длину, равную кол-ву суток, проведенных пользователем в топике в интервале [start..end]
        ###
        addInterval = () ->
            duration = end - start
            shiftedStart = start
            while duration > ONE_DAY
                intervals.push({start: shiftedStart, duration: ONE_DAY})
                shiftedStart += ONE_DAY
                duration -= ONE_DAY
            intervals.push({start: shiftedStart, duration: duration})
        isDatesEqual = (x, y) ->
            x = DateUtils.getDateByTimestampWithoutMS(x)
            y = DateUtils.getDateByTimestampWithoutMS(y)
            return x.getTime() == y.getTime()
        return addInterval() if not intervals.length
        lastInterval = intervals.slice(-1)[0]
        if not isDatesEqual(lastInterval.start, start)
            #Удалим последний интервал, т.к. за предыдущие сутки пользователь провел в топике времени меньше MINIMAL_INTERVAL
            intervals.splice(-1, 1) if lastInterval.duration < MINIMAL_INTERVAL
            return addInterval()
        lastInterval.duration += end - start

    getNextAmount: (user, monthCount=1) ->
        @_topic.getParticipantsWithRole(true).length * monthCount * user.getMonthTeamTopicTax()

    processSuccessPayment: (monthCount=1) ->
        balance = @getBalance()
        dayCount = @_getDayCountBeforeNextPayment(monthCount)
        balance.value += dayCount * @_topic.getParticipantsWithRole(true).length
        balance.lastWriteOffDate =  DateUtils.getCurrentDate()
        balance.debtSince = null
        balance.notificationSent = false

    _getDayCountBeforeNextPayment: (monthCount=1) ->
        now = new Date()
        nextPaymentDate = new Date()
        nextPaymentDate.setMonth(now.getMonth() + monthCount)
        return Math.round((nextPaymentDate.getTime() - now.getTime()) / (ONE_DAY * 1000))

    _getState: () ->
        now  = DateUtils.getCurrentDate()
        balance = @getBalance()
        debtSince = balance.debtSince
        if debtSince
            return if debtSince + BLOCKING_TIMEOUT > now then TEAM_STATES.TEAM_STATE_DEBT else TEAM_STATES.TEAM_STATE_BLOCKED
        if balance.isTrial
            return TEAM_STATES.TEAM_STATE_TRIAL if balance.lastWriteOffDate >= now and balance.value == 0
            return TEAM_STATES.TEAM_STATE_SHOULD_BE_BLOCKED
        else
            return TEAM_STATES.TEAM_STATE_PAYED

    getState: () ->
        state = @_getState()
        return if state==TEAM_STATES.TEAM_STATE_SHOULD_BE_BLOCKED then TEAM_STATES.TEAM_STATE_BLOCKED else state

    getPaidTill: () ->
        return if @getState() != TEAM_STATES.TEAM_STATE_PAYED
        now  = DateUtils.getCurrentDate()
        balance = @getBalance()
        return now + ONE_DAY * Math.floor(balance.value / @_topic.getParticipantsWithRole(true).length)

    getTrialTill: () ->
        return if @getState() != TEAM_STATES.TEAM_STATE_TRIAL
        return @getBalance().lastWriteOffDate

    getBlockingDate: () ->
        return if @getState() != TEAM_STATES.TEAM_STATE_DEBT
        balance = @getBalance()
        return balance.debtSince + BLOCKING_TIMEOUT

    isBlocked: () ->
        return @getState() == TEAM_STATES.TEAM_STATE_BLOCKED

module.exports.TeamModel = TeamModel
