_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
AmqpHelper = require('./amqp_helper').AmqpHelper

{
    OT_OP_BROADCAST_ROUTING_KEY
    FRONTEND_QUEUE_PREFIX
    BACKEND_QUEUE_PREFIX
} = require('./constants')

class AmqpBackendHelper extends AmqpHelper

    constructor: () ->
        conf = Conf.getOtConf() or {}
        return if not conf.isBackend # variable is set in wave_backend app role
        @_backends = []
        @_logger = Conf.getLogger('ot-backend')
        if not conf.backendIdRange or not conf.backendIdRange.length
            throw new Error("OT backend can work only with AMQP. Specify BACKEND_ID_RANGE environment var")
        routingKeys = ("#{BACKEND_QUEUE_PREFIX}_#{id}" for id in conf.backendIdRange)
        options =
            listenRoutingKey: routingKeys
            listenCallback: @_onMessageGot
            listenQueueAutoDelete: false
            listenQueueAck: true
        super(_.extend({}, conf, options))

    addBackend: (backend) ->
        @_backends.push(backend)

    _onMessageGot: (rawMessage, headers, deliveryInfo, callback) =>
        sendAck = () ->
            callback(null, true)
        @_parseRawMessage(rawMessage, (err, msg) =>
            return sendAck() if err
            {method, args} = msg
            backend = _.find(@_backends, (backend) -> backend[method])
            backend[method](args, (err, channelId, doc, op, oldOps, alreadyApplied) =>
                @_onBackendDone(deliveryInfo, err, channelId, doc, op, oldOps, alreadyApplied, (notError, err) =>
                    err = _.compact(err)
                    sendAck()
                    return if not err.length
                    @_logger.error("Error while ot method result sending", {err})
                )
            )
        )

    _onBackendDone: (deliveryInfo, err, channelId, doc, op, oldOps, alreadyApplied, callback) ->
        tasks = [
            (done) =>
                return done() if err or not op or alreadyApplied
                msg = JSON.stringify({channelId, op})
                routingKey = OT_OP_BROADCAST_ROUTING_KEY
                callback = (err) -> done(null, err)
                @_sendingQueue.push({msg, routingKey, callback})
            (done) =>
                msg = JSON.stringify({err, channelId, doc, op, oldOps})
                routingKey = deliveryInfo.replyTo
                options = {correlationId: deliveryInfo.correlationId}
                callback = (err) -> done(null, err)
                @_sendingQueue.push({msg, routingKey, options, callback})
        ]
        async.series(tasks, callback)


module.exports.AmqpBackendHelper = new AmqpBackendHelper()
