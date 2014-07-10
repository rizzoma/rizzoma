# класс не используется, оставил до реализации отправки ot-операций по rpc
Conf = require('../conf').Conf
_ = require('underscore')
AmqpQueueListener = require('../common/amqp').AmqpQueueListener
OtError= require('./exceptions').OtError

OT_CALLS_ROUTING_KEY = "ot_calls"

class QueueOtProcessorClient
    ###
    Класс-декоратор  Ot-процессора.
    Позволяет отправлять операции для документа во внешний процесс (RPC с использованием AMQP).
    Работу с подписками, каналами пока не реализует.
    Таймауты для запросов, отправленных серверу, не устанавливаются и не обрабатываются - непонятно,
    какие таймауты устанавливать и что делать в случае таймаутов.
    ###
    constructor: (@_processorName) ->
        ###
        @param _processorName: string 'WaveProcessor' or 'BlipProcessor', prepended before remote method name
        ###
        @_logger = Conf.getLogger('ot')
        @_options = Conf.getOtConf() || {}
        @_nextCorrelationId = 0
        @_responseCallbacks = {}
        @_connected = false

        @_requestRoutingKey = OT_CALLS_ROUTING_KEY
        @_responseRoutingKey = "#{OT_CALLS_ROUTING_KEY}_responses_#{process.pid}_#{Date.now()}_#{Math.random().toString().slice(3, 8)}"
        options =
            listenRoutingKey: @_responseRoutingKey
            listenCallback: @_processAmqpResponse
            listenQueueAutoDelete: true
            listenQueueAck: false
        amqpDefaultOptions = Conf.getAmqpConf() || {}
        amqpOtOptions = @_options.amqpOptions || {}
        _.extend(options, amqpDefaultOptions, amqpOtOptions)
        @_amqp = new AmqpQueueListener(options)
        @_amqp.on 'close', () =>
            @_connected = false
        @_amqp.on 'queue-subscribed', () =>
            @_connected = true
        @_amqp.connect (err) =>
            return @_logger.error(err) if err

    _call: (method, params, callback) ->
        ###
        Отправляет запрос к методу на сервере
        ###
        correlationId = Date.now() + '_' + (@_nextCorrelationId++)
        if not @_connected
            @_logger.error("AMQP is not connected #{@_responseRoutingKey}_#{correlationId}", { method, params })
            return callback(new OtError("Ot temporary not available"))
        @_responseCallbacks[correlationId] = { callback: callback }
        @_sendAmqpRequest(correlationId, method, params)

    _sendAmqpRequest: (correlationId, method, params) ->
        ###
        Занимается непосредственной отправкой сообщения по AMQP.
        @param correlationId: string
        @param method: string
        @param args: Object
        ###
        msg = JSON.stringify({ method, params })
        @_logger.debug("Send ot request #{@_responseRoutingKey}_#{correlationId}", { msg })
        #throw new Error()
        @_amqp.publish(@_requestRoutingKey, msg, {
            replyTo: @_responseRoutingKey
            correlationId: correlationId
        })

    _processAmqpResponse: (rawMessage, headers, deliveryInfo) =>
        id = "#{@_responseRoutingKey}_#{deliveryInfo.correlationId}"
        @_logger.debug "Got result for #{id}"
        respCallback = @_responseCallbacks[deliveryInfo.correlationId]
        if not respCallback
            @_logger.warn("Has no callback for #{id}")
            return
        delete @_responseCallbacks[deliveryInfo.correlationId]
        callback = respCallback.callback
        try
            msg = JSON.parse rawMessage.data.toString()
        catch e
            @_logger.error("AMQP response JSON parse error #{id}, rawMessage: #{rawMessage}", {err: e})
            return callback(new OtError("Ot internal error (parse response)"))
        callback(msg.err, msg.res)

    applyOp: (docId, op, onOpApplied, callback) =>
        ###
        @param docId: string
        @param op: OperationModel
        @param onOpApplied: function
        @param callback: function
        Добавляет операцию в очередь.
        ###
        if onOpApplied
            @_logger.error("Bugcheck: onOpApplied should have no value for QueueOtProcessorClient, docId=#{docId}", {docId, op})
            return callback(new OtError('Ot internal error (onOpApplied)'))
        @_call("#{@_processorName}.applyOp", {docId, op, onOpApplied}, callback)

module.exports =
    QueueOtProcessorClient: QueueOtProcessorClient
