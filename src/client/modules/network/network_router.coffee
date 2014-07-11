###
@package: volna
@autor: quark, 2011
###

BaseRouter = require('../../../share/base_router').BaseRouter
BaseModule = require('../../../share/base_module').BaseModule
SockJS = require('./transports/sockjs').SockJS
rest = require('./transports/rest')

# Время, после которого будет показан disconnect, ms
BUSY_DISCONNECT_STATUS_TIMEOUT = 10000
IDLE_DISCONNECT_STATUS_TIMEOUT = 30000

class RemoteModule extends BaseModule
    ###
    Класс, вызывающий удаленно методы, которых нет у себя.

    Обращение к методам происходит через транспорты:
    - SockJS - с у становлением и поддержанием соединения (когда не установлено соединение накапливает обращения
      к методам, при установлении соединения делает вызовы, при реконнекте вызывает незавершившиеся методы)
    - HTTP REST - методы вызываются без предварительного установления соединения (считаем, что транспорт всегда доступен)

    При вызове методов у запроса могут быть указаны свойства:
    - recallOnDisconnect - повторять ли запрос после дисконнекта или сетевых ошибок (для транспорта SockJS).
      Значением recallOnDisconnect может быть:
      1) false (при проблемах с соединением будет возвращена ошибка),
      2) true (при дисконнекте/сетевых ошибках запрос будет ожидать в очереди и будет повторно отправлен после реконнекта)
      3) или функция (то же, что и true. Функция будет вызвана при повторной отправке, она должна создать и вернуть
      новый request. Применяется в WaveProcessor.subscribeForWaveData() для указания актуальных версий документов,
      на которые происходит повторная подписка).
    - wait - устанавливается у подписок, на один такой запрос может придти несколько ответов.
    - close-confirm - предупреждать пользователя при закрытии вкладки браузера если ответ на данный запрос ещё не получен.
    - callId - идентификатор запроса для определения на какой запрос получен ответ (устанавливается автоматически,
      используется для транспорта SockJS).
    ###
    constructor: (args...) ->
        super(args...)
        @_callCounter = 0
        @_calls = {}
        @_initTransport()
        @_showingDisconnected = false
        @_hasFirstConnect = false
        # _flushedCallback устанавливается при отключении и вызывается, когда
        # все вызовы, требующие подтверждения пользователя при закрытии
        # страницы будут завершены
        @_flushedCallback = null

    _hasNoWaitCalls: ->
        for callId, call of @_calls
            return true if not call.request.wait
        return false

    _getRemoteProcedureName: (moduleName, procedureName) ->
        "#{moduleName}.#{procedureName}"

    _sendMessage: (moduleName, procedureName, request)->
        ###
        Отправляет сообщение на сервер
        @param moduleName: string
        @param procedureName: string
        @param request: Request
        ###
        remoteName = @_getRemoteProcedureName(moduleName, procedureName)
        @_callCounter++
        callId = "k#{@_callCounter}"
        @_calls[callId] =
            procedureName: remoteName
            request: request
        request.setProperty 'callId', callId
        transport = @_getTransport(remoteName, request)
        if transport.isConnected()
            transport.emit remoteName, request
        else
            transport.needEmit?()
            # Обновим время до показа Disconnected
            @_processDisconnectedStatus() if @_hasFirstConnect

    _getTransport: (remoteName, request) ->
        ###
        Select transport based on remoteName and request parameters
        ###
        throw "method '_getTransport' is not implemented"

    _deleteCall: (id) ->
        ###
        Удаляет данные о вызове из списка вызовов и вызывает _flushedCallback,
        если такой установлен и нет вызовов, требующих подтверждения
        пользователя при закрытии
        ###
        hadConfirm = @_calls[id].request['close-confirm']
        delete @_calls[id]
        return if not @_flushedCallback
        return if not hadConfirm
        return if @hasCallsToConfirm()
        @_flushedCallback()

    _onTransportReceive: (response) =>
        ###
        Вызывается, когда транспорту приходит ответ.
        Находим callback, которуму нужно отдать ответ.
        @param response: object
        ###
        id = response.callId
        if not @_calls[id]
            return console.warn "Got response for #{id}, but it is not present", response
        @_calls[id].request.callback(response.err, response.data)
        @_deleteCall(id) if not @_calls[id].request.wait

    _sendUnsentCalls: =>
        ###
        Отправляет неодноразовые вызовы, которые еще не были отправлены
        ###
        for callId, params of @_calls
            transport = @_getTransport(params.procedureName, params.request)
            transport.emit params.procedureName, params.request

    _processDisconnect: ->
        ###
        Отменяет одноразовые вызовы, обновляет повторяющиеся
        ###
        for own callId, params of @_calls
            if params.request.recallOnDisconnect
                params.request = @_refreshCall(params.request)
            else
                @_cancelCall(params.request)
                @_deleteCall(callId)

    _cancelCall: (request) ->
        ###
        Отменяет вызов, вызывает callback с ошибкой
        ###
        err =
            code: 0
            error: 'client'
            message: 'network disconnected'
        request.callback(err, null)

    _refreshCall: (request) ->
        ###
        Обновляет вызов для повторной отправки на сервер
        Значением recallOnDisconnect может быть true, false или метод,
        который должен вернуть новый запрос (применяется в WaveProcessor.subscribeForWaveData())
        ###
        return request if request.recallOnDisconnect is true
        res = request.recallOnDisconnect()
        res.setProperty('callId', request.callId)
        return res

    _getSyncBoard: ->
        if !@_syncBoard?
            @_syncBoard = require('./sync_board').syncBoardInstance
            @_syncBoard.renderAndInitInContainer(document.body)
            @_syncBoard.getReconnectLink().click(@_reconnectNow)
        @_syncBoard

    _getReconnectionTime: ->
        throw "method '_getReconnectionTime' is not implemented"

    _reconnectNow: ->
        @_getSyncBoard().setReconnectingText()
        clearInterval(@_synchronizingTimer)
        @_synchronizingTimer = setInterval(@_updateSynchTimer, 1000)

    _updateSynchTimer: =>
        secondsLeft = Math.round((@_getReconnectionTime() - Date.now())/1000)
        @_getSyncBoard().setSecondsLeft(secondsLeft)
        if secondsLeft <= 0
            @_getSyncBoard().setReconnectingText()
        else
            @_getSyncBoard().setTimerText()

    _showDisconnected: =>
        @_getSyncBoard().show()
        @_updateSynchTimer()
        @_synchronizingTimer = setInterval(@_updateSynchTimer, 1000)
        @_statusTimeoutHandler = null
        @_showingDisconnected = true

    _hideDisconnected: =>
        @_getSyncBoard().hide()
        clearInterval(@_synchronizingTimer)
        @_showingDisconnected = false
        @_flushedCallback = null

    _processDisconnectedStatus: ->
        return if @_showingDisconnected
        timeout = if @_hasNoWaitCalls() then BUSY_DISCONNECT_STATUS_TIMEOUT else IDLE_DISCONNECT_STATUS_TIMEOUT
        disconnectionShowTime = Date.now() + timeout
        # Не будем обновлять таймер на показ Disconnected, если он будет показан раньше расчитанного нами времени
        return if @_statusTimeoutHandler and disconnectionShowTime > @_disconnectionShowTime
        window.clearTimeout(@_statusTimeoutHandler)
        @_statusTimeoutHandler = window.setTimeout(@_showDisconnected, timeout)
        @_disconnectionShowTime = disconnectionShowTime

    _processConnectedStatus: ->
        if @_statusTimeoutHandler?
            window.clearTimeout(@_statusTimeoutHandler)
            @_statusTimeoutHandler = null
        return if not @_showingDisconnected
        if @hasCallsToConfirm()
            @_flushedCallback = @_hideDisconnected
        else
            @_hideDisconnected()

    handle: (moduleName, procedureName, request) ->
        ###
        Обрабатывает запрос на выполнение процедуры.
        @param moduleName: string
        @param procedureName: string
        @param request: Request
        ###
        return if not @_callMethod(procedureName, request)
        @_sendMessage(moduleName, procedureName, request)

    hasCallsToConfirm: ->
        ###
        Возвращает true, если у этого транспорта есть неотправленные сообщения,
        которые требуют подтверждения пользователя при закрытии
        ###
        for callId, call of @_calls
            return true if call.request['close-confirm']
        return false

    removeCall: (request) ->
        ###
        Отменяет указанный вызов
        @param request.args.callId: string
        ###
        callId = request.args.callId
        if not @_calls[callId]?
            err = new Error "Call #{callId} is cancelled but it was not called"
            return request.callback(err)
        @_deleteCall(callId)
        request.callback()


class CombinedRemoteModule extends RemoteModule
    _initTransport: ->
        settings = {url: '/rizzoma'}
        @_sockjs = new SockJS settings, @_onTransportReceive
        @_sockjs.onConnect =>
            @_hasFirstConnect = true
            @_sendUnsentCalls()
            @_processConnectedStatus()
        @_sockjs.onDisconnect =>
            @_processDisconnect()
            @_processDisconnectedStatus()
        @_restGet = new rest.Rest({}, @_onTransportReceive)
        @_restPost = new rest.RestPost({}, @_onTransportReceive)

    _getReconnectionTime: ->
        @_sockjs.getReconnectionTime()

    _reconnectNow: =>
        @_sockjs.reconnectNow()
        super()

    _getTransport: (remoteName, request) ->
        ###
        Select transport based on remoteName and request parameters
        ###
        restGetProcedureList = [
            'wave.searchBlipContent'
            'user.getUserContacts'
            'gtag.getGTagList'
            'message.searchMessageContent'
            'wave.searchBlipContentInPublicWaves'
            'store.getVisibleItemList'
            'team.getTeamTopics'
            'task.searchByRecipient'
            'task.searchBySender'
            'wave.getWaveWithBlips'
        ]
        restPostProcedureList = [
            'user.getUsersInfo'
        ]
        return @_restGet if remoteName in restGetProcedureList
        return @_restPost if remoteName in restPostProcedureList
        return @_sockjs


class NetworkRouter extends BaseRouter
    ###
    Класс, представляющий сетевой роутер. Знает о модулях, которые занимаются сетью.
    ###

    constructor: (args...) ->
        super(args...)
        combined = new CombinedRemoteModule(@_rootRouter)
        @_transports = [combined]
        @_addModule(name, [name, combined]) for name in ['wave', 'search', 'message', 'file', 'gtag', 'task', 'user', 'export', 'store', 'team', 'messaging']
        @_initCloseCheck()

    _initCloseCheck: ->
        ###
        Инициализирует проверки при закрытии страницы. Предупреждает пользователя,
        если есть неотправленные данные
        ###
        window.addEventListener 'beforeunload', (e) =>
            return if not @_hasCallsToConfirm()
            msg = 'One or more topics has unsent data'
            e = e || window.event
            e.returnValue = msg if e
            return msg

    _call: (modulePair, procedureName, request) ->
        [name, module] = modulePair
        module.handle(name, procedureName, request)

    _hasCallsToConfirm: ->
        for transport in @_transports
            return true if transport.hasCallsToConfirm()
        return false

    isConnected: () ->
        return  @_transports[0]._sockjs.isConnected()

module.exports.NetworkRouter = NetworkRouter
