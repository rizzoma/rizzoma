ClientTransport = require('../../../../share/client_transport').ClientTransport
Response = require('../../../../share/communication').Response


RECONNECT_TIMEOUT = 60 * 1000 # 1 minute
INACTIVE_THRESHOLD = 10 * 60 * 1000 # 10 minutes
DATA_RECEIVE_CHECK_TIME_INTERVAL = 10 * 1000 # 10 seconds

class Rest extends ClientTransport
    ###
    Реализация клиентского транспорта websocket
    ###
    constructor: (@_settings, @_onmessage)->
        @_apiUrl = "/api/rest/1/"

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
        return true

    _stringifyArgs: (args) ->
        res = {}
        for arg, val of args
            defVal = if typeof val == 'number' then 0 else ""
            res[arg] = val or defVal
        return res

    emit: (procedureName, request) =>
        ###
        Отсылает запрос на сервер.
        @param procedureName: string, имя вызываемой процедуры на сервере
        @param request: Request
        ###
        url = @_getProcedureUrl(procedureName)
        args = $.extend({ "ACCESS_TOKEN": window.expressSession.id or "" }, @_stringifyArgs(request.serialize().args))
        $.get(url, args, (data, textStatus, jqXHR) =>
            response = new Response(data.err, data.data)
            response.setProperty 'callId', request.callId
            _gaq.push(['_trackEvent', 'Error', 'Server error', data.err.code]) if data.err and data.err.code != 'wave_anonymous_permission_denied'
            @_onmessage(response)
        , "json").error( (jqXHR, textStatus, errorThrown) =>
            response = new Response(new Error(errorThrown), null)
            response.setProperty 'callId', request.callId
            @_onmessage(response)
        )


    needEmit: ->
        ###
        Оповещает отключенный транспорт о том, что нужно отправить данные.
        Заставляет переподключиться как можно быстрее.
        ###
        return

    getReconnectionTime: ->
        return Date.now() + RECONNECT_TIMEOUT

    reconnectNow: ->
        return

    _getProcedureUrl: (procedureName) ->
        return "#{@_apiUrl}#{procedureName.replace('.', '/')}/"

class RestPost extends Rest
    emit: (procedureName, request) =>
        ###
        Отсылает запрос на сервер.
        @param procedureName: string, имя вызываемой процедуры на сервере
        @param request: Request
        ###
        url = @_getProcedureUrl(procedureName)
        url += """?ACCESS_TOKEN=#{encodeURIComponent(window.expressSession.id) or ""}"""
        args = @_stringifyArgs(request.serialize().args)
        $.ajax
            'type': 'POST'
            'url': url
            'contentType': 'application/json'
            'data': JSON.stringify(args)
            'dataType': 'json'
            'success': (data, textStatus, jqXHR) =>
                response = new Response(data.err, data.data)
                response.setProperty 'callId', request.callId
                _gaq.push(['_trackEvent', 'Error', 'Server error', data.err.code]) if data.err and data.err.code != 'wave_anonymous_permission_denied'
                @_onmessage(response)
            'error': (jqXHR, textStatus, errorThrown) =>
                response = new Response(new Error(errorThrown), null)
                response.setProperty 'callId', request.callId
                @_onmessage(response)

module.exports = {Rest, RestPost}