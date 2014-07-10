###
@package: volna
@autor: Yury Ilinikh, 2011
###

BaseRouter = require('../../../../share/base_router').BaseRouter
UnknownTransportError = require('../../../modules/network/exceptions').UnknownTransportError
Nodesocket = require('../../../modules/network/transports/nodesocket').Nodesocket

class PerfomanceNetworkRouter extends BaseRouter
    ###
    Класс, представляющий сетевой роутер. Знает о модулях, которые занимаются сетью.
    ###

    constructor: (rootRouter, url='http://localhost:8000/', @expressSessionId=null) ->
        super(rootRouter)
        @_addModule 'wave', 'nodesocket'
        @_addModule 'search', 'nodesocket'
        @_addModule 'message', 'nodesocket'
        @_callCounter = 0
        @_calls = {}
        @_transports = []
        @_initTransports(url)
        
    setExpressSessionId: (id) ->
        @expressSessionId = id

    _initTransports: (url) ->
        ###
        Инициализирует транспорты. 
        ###
        settings = {url: url}
        
        #Инициируем nodesocket
        ws = new Nodesocket settings, (response) =>
            @_onTransportReceive 'nodesocket', response
        ws.onConnect () =>
            @_sendUnsentCalls('nodesocket')
        ws.onDisconnect () =>
            @_cancelOneTimeCalls('nodesocket')
        @_transports['nodesocket'] = ws
        @_calls['nodesocket'] = {}
    
    _sendUnsentCalls: (transport) ->
        ###
        Отправляет неодноразовые вызовы, которые еще не были отправлены
        @param transport: string, обозначение транспорта, через который надо отправить
            сообщения
        ###
        calls = @_calls[transport]
        for callId, params of calls
            @_transports[transport].emit(params.procedureName, params.request, @expressSessionId)
    
    _cancelOneTimeCalls: (transport) ->
        ###
        Отменяет одноразовые вызовы
        @param transport: string, обозначение транспорта, через который надо отправить
            сообщения
        ###
        calls = @_calls[transport]
        for callId, params of calls
            continue if params.request.recallOnDisconnect
            err =
                code: 0
                error: 'client'
                message: 'network disconnected'
            params.request.callback(err, null)
            delete calls[callId]

    _reduceProcedureName: (parts) ->
        ###
        Не вырезаем имя модуля - вырежется на сервере.
        ###
        parts.join '.'

    _call: (transport, procedureName, request) ->
        ###
        Перегружаем метод вызова процедуры.
        В данном случае нужно запомнить callback и отправить запрос.
        @param transport: string
        @param procedureName: string
        @param request: request
        ###
        if not transport of @_transports
            throw new UnknownTransportError "Transport #{transport} is unknown"
        @_callCounter++;
        callId = "k#{@_callCounter}"
        @_calls[transport][callId] =
            procedureName: procedureName
            request: request

        transport = @_transports[transport]
        request.setProperty 'callId', callId
        if transport.isConnected()
            transport.emit procedureName, request, @expressSessionId

    _onTransportReceive: (transport, response) ->
        ###
        Вызывается, когда транспорту приходит ответ.
        Находим callback, которуму нужно отдать ответ.
        @param response: object
        ###
        id = response.callId
        calls = @_calls[transport]
        calls[id].request.callback(response.err, response.data)
        if not response.wait
            delete calls[id]
    
module.exports.PerfomanceNetworkRouter = PerfomanceNetworkRouter