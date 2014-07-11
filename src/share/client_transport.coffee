###
@package: volna
@autor: quark, 2011
###

NotImplementedError = require('./exceptions').NotImplementedError

class ClientTransport
    ###
    Базовый класс транспорта для клиента.
    ###
    constructor: () ->
        @transportName

    emit: () ->
        ###
        Отправляет данные.
        ###
        throw new NotImplementedError("Method emit of transport #{@transportName} is not implemented")

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
        throw new NotImplementedError("Method isConnected of transport #{@transportName} is not implemented")

    needEmit: ->
        ###
        Оповещает отключенный транспорт о том, что нужно отправить данные.
        Заставляет переподключиться как можно быстрее.
        ###
        throw new NotImplementedError("Method needEmit of transport #{@transportName} is not implemented")

    getReconnectionTime: ->
        throw new NotImplementedError("Method getReconnectionTime of transport #{@transportName} is not implemented")

    reconnectNow: ->
        throw new NotImplementedError("Method reconnectNow of transport #{@transportName} is not implemented")


module.exports.ClientTransport = ClientTransport