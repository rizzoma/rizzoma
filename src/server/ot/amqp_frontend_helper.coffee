_ = require('underscore')
Conf = require('../conf').Conf
EventEmitter = require('events').EventEmitter
OtProcessorFrontend = require('../ot/processor_frontend').OtProcessorFrontend
AmqpHelper = require('./amqp_helper').AmqpHelper

{
    OT_OP_BROADCAST_ROUTING_KEY
    FRONTEND_QUEUE_PREFIX
    BACKEND_QUEUE_PREFIX
} = require('./constants')

class AmqpFrontendHelper extends AmqpHelper
    constructor: () ->
        @_callbackRegistry = new EventEmitter()
        conf = Conf.getOtConf() or {}
        #return if conf.isBackend
        @_logger = Conf.getLogger('ot-frontend')
        # build queue and binding options for AMQP responses
        options =
            listenCallback: @_onMessageGot
            listenQueueAck: true
        if conf.frontendQueueSuffix
            # use persistent queue, listen for ot ops broadcast: OT_OP_BROADCAST_ROUTING_KEY
            @_responseRoutingKey = "#{FRONTEND_QUEUE_PREFIX}_#{conf.frontendQueueSuffix}"
            options.listenRoutingKey = [@_responseRoutingKey, OT_OP_BROADCAST_ROUTING_KEY]
            options.listenQueueAutoDelete = false
        else
            # use auto-delete queue, no ot broadcast messages required
            @_responseRoutingKey = "#{FRONTEND_QUEUE_PREFIX}_auto_#{process.pid}_#{Date.now()}"
            options.listenRoutingKey = [@_responseRoutingKey]
            options.listenQueueAutoDelete = true
            @_logger.info("No FRONTEND_QUEUE_SUFFIX env var provided: using non-persistent queue #{@_responseRoutingKey}, OT document subscriptions are disabled for this application instance")
        options.queueName = @_responseRoutingKey
        super(_.extend({}, conf, options))

    callMethod: (method, id, args) ->
        correlationId = @_registerCallback(args)
        options =
            replyTo: @_responseRoutingKey
            correlationId: correlationId
        routingKey = "#{BACKEND_QUEUE_PREFIX}_#{id}"
        msg = JSON.stringify({method, args})
        callback = (err) =>
            return if not err
            @_callbackRegistry.removeAllListeners(correlationId)
            @_logger("Error while ot method call", {err})
        @_sendingQueue.push({msg, routingKey, options, callback})

    _registerCallback: (args) ->
        documentCallback = args.documentCallback
        opResponseCallback = args.opResponseCallback
        delete args.documentCallback
        delete args.opResponseCallback
        correlationId = ((new Date).getTime()+Math.random()).toString()
        callback = (err, channelId, doc, op, oldOps) =>
            listenerId = args.listenerId
            OtProcessorFrontend.sendOpsToSelf(channelId, listenerId, oldOps) if oldOps and oldOps.length and listenerId
            @_callOpResponseCallback(err, op, opResponseCallback, channelId)
            documentCallback?(err, doc)
        @_callbackRegistry.once(correlationId, callback)
        return correlationId

    _callOpResponseCallback: (err, op, opResponseCallback, channelId) ->
        return if not opResponseCallback
        return opResponseCallback(err) if err
        return if not op
        op.callback = opResponseCallback
        OtProcessorFrontend.onOpReceive(channelId, op)

    _onMessageGot: (rawMessage, headers, deliveryInfo, callback) =>
        sendAck = () ->
            callback(null, true)
        @_parseRawMessage(rawMessage, (err, msg) =>
            return sendAck() if err
            if deliveryInfo.routingKey == @_responseRoutingKey
                @_onMethodResponse(deliveryInfo.correlationId, msg)
            else if deliveryInfo.routingKey == OT_OP_BROADCAST_ROUTING_KEY
                @_onOpReceive(msg)
            sendAck()
        )

    _onMethodResponse: (correlationId, msg) ->
        {err, channelId, doc, op, oldOps} = msg
        @_callbackRegistry.emit(correlationId, err, channelId, doc, op, oldOps)

    _onOpReceive: (msg) ->
        {channelId, op} = msg
        if not channelId or not op
            return @_logger.error("AMQP invalid op params", {channelId, op})
        OtProcessorFrontend.onOpReceive(channelId, op)


module.exports.AmqpFrontendHelper = new AmqpFrontendHelper()
