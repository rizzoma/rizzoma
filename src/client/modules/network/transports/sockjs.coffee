ClientTransport = require('../../../../share/client_transport').ClientTransport
Response = require('../../../../share/communication').Response

RECONNECT_TIMEOUT = 60 * 1000 # 1 minute
INACTIVE_THRESHOLD = 10 * 60 * 1000 # 10 minutes
DATA_RECEIVE_CHECK_TIME_INTERVAL = 10 * 1000 # 10 seconds

class SockJS extends ClientTransport
    ###
    Реализация клиентского транспорта websocket
    ###
    constructor: (@_settings, @_onmessage)->
        @transportName = 'sockjs'
        @_lastSendTime = 0
        @_init()
        window.setInterval =>
            return if Date.now() - @_lastDataReceiveTime < window.HEARTBEAT_INTERVAL * 2
            return if not @isConnected()
            @_sockjs.close()
        , DATA_RECEIVE_CHECK_TIME_INTERVAL

    _init: ->
        @_sockjs = new window.SockJS @_settings.url
        @_sockjs.onmessage = (message) =>
            data = JSON.parse(message.data)
            response = new Response(data.err, data.data)
            response.setProperty 'callId', data.callId
            _gaq.push(['_trackEvent', 'Error', 'Server error', data.err.code]) if data.err and data.err.code != 'wave_anonymous_permission_denied'
            @_onmessage(response)
            @_updateDataReceiveTime()

        @_sockjs.onclose = =>
            console.log("Network disconnected", new Date())
            @_disconnectCallback?()
            @_reconnect()

        @_sockjs.onopen = =>
            @_connectCallback?()
            @_updateDataReceiveTime()

        @_sockjs.onheartbeat = @_updateDataReceiveTime

    _updateDataReceiveTime: =>
        @_lastDataReceiveTime = Date.now()

    _performReconnect: =>
        # Выполняет непосредственное переподключение
        console.log "Reconnecting right now.", new Date()
        window.clearTimeout(@_reconnectHandler)
        delete @_reconnectHandler
        @_init()

    _reconnect: ->
        return if @_sockjs.readyState isnt window.SockJS.CLOSED
        timeout = @_generateReconnectionTime()
        if @_reconnectHandler
            delta = Date.now() + timeout - @_reconnectionTime
            # Не переносим переподключение на позднее время
            return if delta > 0
            window.clearTimeout(@_reconnectHandler)
            delete @_reconnectHandler
        @_reconnectionTime = Date.now() + timeout
        console.log "Reconnecting in #{timeout}"
        @_reconnectHandler = window.setTimeout(@_performReconnect, timeout)

    _generateReconnectionTime: ->
        ###
        Возвращает рекомендуемое время переподключения. Если пользователь
        не проявлял активности в течение INACTIVE_THRESHOLD, то переподключится
        в промежутке от RECONNECT_TIMEOUT + 5 cек. до RECONNECT_TIMEOUT*2, иначе - в
        течение времени от 5 сек. до RECONNECT_TIMEOUT + 5 сек.
        ###
        timeout = Math.random() * RECONNECT_TIMEOUT + 5000
        delta = Date.now() - @_lastSendTime
        timeout += RECONNECT_TIMEOUT if delta > INACTIVE_THRESHOLD
        return timeout

    onConnect: (callback) ->
        ###
        Устанавливает callback, который будет вызываться при каждом подключении к серверу
        ###
        @_connectCallback = callback

    onDisconnect: (callback) ->
        ###
        Устанавливает callback, который будет вызываться при каждом отключении от сервера
        ###
        @_disconnectCallback = callback

    isConnected: ->
        ###
        Возвращает true, если транспорт подключен к серверу
        ###
        return @_sockjs.readyState is window.SockJS.OPEN

    emit: (procedureName, request) ->
        ###
        Отсылает запрос на сервер.
        @param procedureName: string, имя вызываемой процедуры на сервере
        @param request: Request
        ###
        data =
            procedureName: procedureName
            request: request.serialize()
            expressSessionId: window.expressSession.id
        @_lastSendTime = Date.now()
        @_sockjs.send(JSON.stringify(data))

    needEmit: ->
        ###
        Оповещает отключенный транспорт о том, что нужно отправить данные.
        Заставляет переподключиться как можно быстрее.
        ###
        @_lastSendTime = Date.now()
        @_reconnect()

    getReconnectionTime: -> @_reconnectionTime

    reconnectNow: ->
        @_reconnectionTime = Date.now()
        @_performReconnect()


module.exports.SockJS = SockJS
