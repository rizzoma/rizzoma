_ = require('underscore')
Conf = require('../../conf').Conf
SphinxIndexer = require('./transport').SphinxIndexer
AmqpQueueListener = require('../../common/amqp').AmqpQueueListener

class Indexer
    constructor: () ->
        @_logger = Conf.getLogger('search')
        @_options = Conf.getSearchIndexerConf() || {}
        amqpConnectOptions = Conf.getAmqpConf() || {}
        amqpOptions = @_options.amqpOptions || {}
        @_exchangeName = amqpOptions.exchangeName || 'rizzoma'
        @_queriesRoutingKey = amqpOptions.queriesRoutingKey || 'indexer'
        amqpQueueListenerOptions =
            listenRoutingKey: @_queriesRoutingKey
            listenCallback: @_processRequest
            listenQueueAutoDelete: false
            listenQueueAck: false
        _.extend(amqpQueueListenerOptions, amqpConnectOptions, amqpOptions)
        @_amqp = new AmqpQueueListener(amqpQueueListenerOptions)
        @_indexer = new SphinxIndexer()

    run: () ->
        if @_options.indexerType != 'amqp'
            throw new Error("Indexer type in settings.coffee must be 'amqp'")
        @_connect()

    _connect: () ->
        @_amqp.connect()

    _processRequest: (message, headers, deliveryInfo, callback) =>
        if message.data.toString() != 'makeIndexer'
            logger.error "Received unknown message '#{message.data.toString()}', not 'makeIndexer'"
            return callback(null, true)
        @_logger.debug "AMQP indexer recieve msg #{message.data.toString()}"
        @_indexer.makeIndexSource(callback)


module.exports.Indexer = new Indexer()