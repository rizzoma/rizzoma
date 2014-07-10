ClientTransport = require('../../../../share/client_transport').ClientTransport
Response = require('../../../../share/communication').Response
io = require('socket.io-client')

class Nodesocket extends ClientTransport
    ###
    Реализация клиентского транспорта nodesocket
    ###
    constructor: (settings, callback)->
        @transportName = 'nodesocket'
        @_init settings, callback
    
    _init: (settings, callback) ->
        options =
            reconnect: false
            'force new connection': true
        @_socket = io.connect settings.url, options
        @_socket.on 'message', (data) ->
            response = new Response(data.err, data.data)
            response.setProperty 'callId', data.callId
            response.setProperty 'wait', data.wait
            callback response
        
        @_socket.on 'disconnect', =>
            @_disconnectCallback() if @_disconnectCallback
            @_init(settings, callback)
        
        @_socket.on 'connect', =>
            @_connectCallback() if @_connectCallback
    
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
        return @_socket.socket.connected
    
    emit: (procedureName, request, expressSessionId=null) -> 
        ###
        Отсылает запрос на сервер.
        ###
        data =    
            procedureName: procedureName
            request: request.serialize()
            expressSessionId: expressSessionId
        @_socket.emit 'message', data

module.exports.Nodesocket = Nodesocket


#settings = {url: 'http://localhost:8000/'}

#Инициируем nodesocket
###
ws = new Nodesocket settings, (response) =>
    console.log('resp', response)
ws.onConnect () =>
    console.log('connected')
    #   ws.emit('wave.getWave', {serialize: ()->})
ws.onDisconnect () =>
    console.log('disconnected')
###