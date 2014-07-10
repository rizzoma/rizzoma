_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
AmqpQueueListener = require('../common/amqp').AmqpQueueListener
DateUtils = require('../utils/date_utils').DateUtils

# ывремя которое будем ждать ответ от рассыльщика (sec)
RESPONSE_TIMEOUT = 3 * 60

class PluginAutosendManager
    constructor: (processors) ->
        @_logger = Conf.getLogger('plugin-autosender-manager')
        @_responseCallback = null
        @_responseTimeout = null
        connectOptions = Conf.getAmqpConf() or {}
        @_responseRoutingKey = "plugin_autosender_responses_#{process.pid}_#{DateUtils.getCurrentTimestamp()}"
        @_queriesRoutingKey = "plugin_autosender_queries"
        listenerSettings =
            listenRoutingKey: @_responseRoutingKey
            listenCallback: @_processResponse
            listenQueueAutoDelete: true
            listenQueueAck: false
        _.extend(listenerSettings, connectOptions)
        @_amqp = new AmqpQueueListener(listenerSettings)

    _processResponse: (rawMessage, headers, deliveryInfo) =>
        @_logger.debug "Got result for #{@_responseRoutingKey}_#{deliveryInfo.correlationId}"
        err = null
        try
            objMessage = JSON.parse(rawMessage.data.toString())
            err = objMessage.err
        catch e
            err = e
        if @_responseTimeout
            clearTimeout(@_responseTimeout)
            @_responseTimeout = null
        @_logger.debug("finished")
        @_responseCallback?(null)
        @_responseCallback = null

    run: (callback) ->
        @_logger.debug("started")
        tasks = [
            async.apply(@_connect)
            async.apply(@_sendStartMessage)
            (callback) =>
                @_responseCallback = callback
                @_responseTimeout = setTimeout(() =>
                    @_logger.error(new Error('Response timeout error'))
                    @_responseCallback?(null)
                    @_responseCallback = null
                , RESPONSE_TIMEOUT * 1000)
        ]
        async.waterfall(tasks, callback)

    _connect: (callback) =>
        onSuccess = () ->
            callback(null)
        @_amqp.connect((err) =>
            return callback(err) if err
            setTimeout(onSuccess, 2000)
        )

    _sendStartMessage: (callback) =>
        correlationId = Date.now() + '_' + Math.random().toString().slice(3, 8)
        options =
            replyTo: @_responseRoutingKey
            correlationId: correlationId
        @_amqp.publish(@_queriesRoutingKey, 'start-autosending', options)
        callback(null)

module.exports.PluginAutosendManager = new PluginAutosendManager()