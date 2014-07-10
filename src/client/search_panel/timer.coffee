MicroEvent = require('../utils/microevent')

class Timer
    ###
    Класс, объект которого следит за автообновлением вкладок
    со списками топиков/сообщений через @_refreshInterval
    ###

    VISIBILITY_STATE = {
        visible: 'visible'
        hidden: 'hidden'
    }

    constructor: (@_params) ->
        @_lastEventTime = new Date().getTime()
        @_pageVisibilityState = Visibility.state()
        @_tabVisibilityState = if @_params.isVisible then VISIBILITY_STATE.visible else VISIBILITY_STATE.hidden
        @_setVisibilityBrowserTabEvent()
        @_resetTimeout()
    
    _setTimeout: (timeout=null) ->
        ###
        @param timeout: количество миллисекунд, через которые выполнится функция _processEvent
        Задает таймаут выполнения function
        ###
        timeout = @_getUpdateInterval() if not timeout
        return @_clearTimeout() if not timeout
        @_eventTimeout = setTimeout(
            @_processEvent,
            timeout
        )

    _getUpdateInterval: ->
        # получаем интервал для обновления в зависимости от видимости
        # таба (страницы) в браузере и таба на странице
        if @_pageVisibilityState == VISIBILITY_STATE.visible
            return @_params.visibleUpdateInterval if @_tabVisibilityState == VISIBILITY_STATE.visible and @_params.visibleUpdateInterval
            return @_params.hiddenUpdateInterval if @_tabVisibilityState == VISIBILITY_STATE.hidden and @_params.hiddenUpdateInterval
        if @_pageVisibilityState == VISIBILITY_STATE.hidden and @_params.unvisibleBrowserTabUpdateInterval
            return @_params.unvisibleBrowserTabUpdateInterval
        null

    _clearTimeout: ->
        @_eventTimeout = clearTimeout(@_eventTimeout)
    
    _resetTimeout: (timeout=null) ->
        @_clearTimeout()
        @_setTimeout(timeout)
    
    _processEvent: (scrollIntoView=false) =>
        ###
        @param scrollIntoView: Boolean скроллировать ли к активной волне список
        Вызывает событие об истечении интервала (intervalExpired) если 
        со времени @_lastEventTime прошло @_refreshInterval
        иначе задает таймаут на оставшееся время
        ###
        updateInterval = @_getUpdateInterval()
        return unless updateInterval
        time_left = updateInterval - (new Date().getTime() - @_lastEventTime)
        if time_left <= 0
            @emit('intervalExpired', scrollIntoView)
            @_lastEventTime = new Date().getTime()
            @_resetTimeout()
        else
            @_resetTimeout(time_left)
    
    _setVisibilityBrowserTabEvent: ->
        ###
        Обрабатывает изменение состояния вкладки
        в браузере visible/hidden
        ###
        Visibility.change((e, state) =>
            switch state
                when 'visible'
                    @_pageVisibilityState = VISIBILITY_STATE.visible
                    @_processEvent(true)
                when 'hidden'
                    @_pageVisibilityState = VISIBILITY_STATE.hidden
                    @_resetTimeout()
        )

    resetTimeout: ->
        ###
        Сбрасывает таймаут для начала отсчета от текущего момента
        ###
        @_lastEventTime = new Date().getTime()
        @_resetTimeout()

    setTabAsVisible: ->
        @_tabVisibilityState = VISIBILITY_STATE.visible
        @_processEvent()

    setTabAsHidden: ->
        @_tabVisibilityState = VISIBILITY_STATE.hidden
        @_processEvent()


MicroEvent.mixin Timer
module.exports.Timer = Timer