_ = require('underscore')
Conf = require('../../conf').Conf
amqp = require('amqp')
events = require('events')
async = require('async')

class AmqpAdapter
    ###
    Коннектится
    умеет подписываться на очередь
    умеет постить в exchange
    ###
    constructor: (@_options = {}) ->
        @_exchange = null
        @_connection = null
        @_logger = Conf.getLogger(@_options.logger || 'amqp')
        @_exchangeName = @_options.exchangeName || 'rizzoma'
        @_connectionOptions = {}
        @_connectionOptions = _.extend(@_connectionOptions, Conf.getAmqpConf(), @_options)
        _.extend(@_connectionOptions.implOptions, @_options.implOptions || {})
        @_emitter = new events.EventEmitter()
        @_connected = false
        @_initIsConnected()

    connect: (callback) ->
        try
            @_connection = amqp.createConnection(@_connectionOptions, @_connectionOptions.implOptions)
        catch e
            @_logger.error(e)
        @_connection.on('error', (err) =>
            @_logger.error('AMQP connection error', { listenRoutingKeys: @_listenRoutingKeys, err: err })
            @_options.onError?(err)
        )
        @_connection.on('close', () =>
            @_logger.info('AMQP connection closed', { listenRoutingKeys: @_listenRoutingKeys })
            @_emitter.emit('close')
        )
        @_connection.on('ready', () =>
            @_logger.info('AMQP is ready', { listenRoutingKeys: @_listenRoutingKeys })
            @_createExchange(callback)
        )

    on: (event, listener) ->
        ###
            Подписывает на нужные события
            Используется для события коннект
        ###
        @_emitter.on(event, listener)

    _initIsConnected: () ->
        @_connected = false
        @on('close', () =>
            @_connected = false
        )
        @on('exchange-ready', () =>
            @_connected = true
        )

    _createExchange: (callback) ->
        options =
            type: "direct"
            durable: true
            autoDelete: false
            confirm: true
        @_exchange = @_connection.exchange(@_exchangeName, options, (ex) =>
            @_emitter.emit("exchange-ready")
            callback?(null)
        )

    subscribe: (listenRoutingKey, listenCallback, ops, callback) ->
        ops = ops || { autoDelete: true, ack: false }
        options =
            durable: true
            autoDelete: ops.autoDelete
        queueName = ops.queueName or listenRoutingKey
        @_connection.queue(queueName, options, (q) =>
            @_logger.info("AMQP start listening queue #{queueName}, routing key #{listenRoutingKey}")
            q.bind(@_exchangeName, listenRoutingKey)
            @_subscribe(q, listenCallback, ops.ack)
            callback?(null)
        )

    _subscribe: (q, listenCallback, ack) ->
        q.subscribe({ ack: ack }, (rawMessage, headers, deliveryInfo) =>
            listenCallback(rawMessage, headers, deliveryInfo, (err, done) =>
                if ack
                    q.shift()
            )
        )

    publish: (routingKey, msg, options, callback) ->
        @_exchange.publish(routingKey, msg, options, callback)

    isConnected: () ->
        return @_connected


class AmqpQueueListener extends AmqpAdapter
    ###
    Коннектится и слушает указанную очередь.
    ###
    constructor: (options) ->
        super(options)
        rkey = options.listenRoutingKey
        @_listenRoutingKeys = if _.isArray(rkey) then rkey else [rkey]
        @_listenCallback = options.listenCallback
        @_queueName = options.queueName
        @_listenQueueAutoDelete = true
        if typeof options.listenQueueAutoDelete != 'undefined'
            @_listenQueueAutoDelete = options.listenQueueAutoDelete
        @_listenQueueAck = options.listenQueueAck || false

    _createExchange: (callback) ->
        super((err) =>
            return callback?(err) if err
            ops = {}
            ops['autoDelete'] = @_listenQueueAutoDelete
            ops['ack'] = @_listenQueueAck
            ops['queueName'] = @_queueName

            iterator = (rkey, cb) =>
                @subscribe(rkey, @_listenCallback, ops, cb)
            finish = (err) =>
                @_emitter.emit("queue-subscribed") if not err
                callback?(err)
            async.forEach(@_listenRoutingKeys, iterator, finish)
        )

    _initIsConnected: () ->
        @_connected = false
        @on('close', () =>
            @_connected = false
        )
        @on('queue-subscribed', () =>
            @_connected = true
        )

module.exports =
    AmqpAdapter: AmqpAdapter
    AmqpQueueListener: AmqpQueueListener