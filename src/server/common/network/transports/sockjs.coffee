Conf = require('../../../conf').Conf
Anonymous = require('../../../user/anonymous')
Request = require('../../../../share/communication').Request
AuthUtils = require('../../../utils/auth_utils').AuthUtils

class SockJS
    ###
    Серверная реализация транспорта SockJS
    ###
    constructor: (@_rootRouter, app) ->
        @_init(app)
        logDepth = Conf.getLoggerConf().logRequest
        @_needLog = !!logDepth
        @_logger = Conf.getLogger('request')
        @_inspect = (arg) ->
            return require('util').inspect(arg, false, logDepth)

    _init: (app) ->
        sockjs = require 'sockjs'
        server = sockjs.createServer(Conf.get('sockjs'))
        server.on('connection', @_processClientConnection)
        server.installHandlers(app, prefix: '[/]rizzoma')

    _processClientConnection: (connection) =>
        ###
        Обрабатывает подключение нового клиента,
        @param connection: object, объект соединения с клиентом
        ###

        # Sometimes connection is null, so there is no way to process such a connection
        if not connection
            console.warn("Got bad sockjs connection:", connection)
            return
        connection.id = Math.random()
        connection.on 'data', (data) =>
            data = JSON.parse(data)
            @_sendToRouter connection, data
        connection.on 'close', =>
            request = new Request(null, ->)
            request.setProperty('sessionId', connection.id)
            @_rootRouter.handleBroadcast('disconnect', request)

    _sendToRouter: (connection, data) ->
        ###
        Разбирает пришедшие данные и отправляет роутеру.
        @param connection: object, объект соединения с клиентом
        @param data: object, полученные данные
        ###
        procedureName = data.procedureName
        callId = data.request.callId
        perf =
            startTime: Date.now()
        request = new Request data.request.args, (response) =>
            @_sendResponseToClient(connection, response, procedureName, callId, perf)
        request.setProperty('callId', callId)
        request.setProperty('sessionId', connection.id)
        AuthUtils.authByToken(data.expressSessionId, (err, user, session) =>
            request.setProperty('user', user)
            request.setProperty('session', session)
            @_logger.debug(
                ">#{procedureName} (#{callId}, #{request.user?.id}): Args: #{@_inspect(request.args)}",
                {
                    method: procedureName
                    callId: callId
                    userId: request.user?.id
                    args: request.args
                    ip: connection.remoteAddress
                    transport: connection.protocol
                }
            ) if @_needLog
            process.nextTick(() =>
                #@see: AuthUtils.authByToken - при получении данных из сессии срабатывает незапланированный try-catch.
                # nextTick разорвет поток выполнения.
                try
                    @_rootRouter.handle(procedureName, request)
                catch err
                    console.error('Error while processing client request (sockjs)', err)
            )
        )

    _sendResponseToClient: (connection, response, procedureName, callId, perf) ->
        ###
        Отправляет клиенту ответ на запрос
        @param connection: object, объект соединения с клиентом
        @param response: Response, объект ответа
        @param callId: string, идентификатор запроса
        ###
        response.setProperty('callId', callId)
        response.setProperty('procedureName', procedureName)

        # add ts (timing.server) value to response
        if perf.startTime
            response.setProperty('perf', { ts: Date.now()-perf.startTime })
            perf.startTime = null # unset startTime, do not measure subsequent responses for subscription requests
        @_sendToClient(connection, response)

    _sendToClient: (connection, response) ->
        ###
        Отправляет клиенту результат выполнения процедуры.
        ###
        connection.write(JSON.stringify(response.serialize()))

module.exports = SockJS
