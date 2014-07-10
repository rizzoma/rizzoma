_ = require('underscore')
Conf = require('../conf').Conf
SphinxSearch = require('./transport').SphinxSearch
SphinxTimeoutError = require('./exceptions').SphinxTimeoutError
SphinxFatalError = require('./exceptions').SphinxFatalError
SPHINX_TIMEOUT_ERROR = require('./exceptions').SPHINX_TIMEOUT_ERROR
AmqpQueueListener = require('../common/amqp').AmqpQueueListener

class Searcher
    ###
    Listens for search requests, executes searches and replies with search results.
    Works via AMQP, use "searcher" app role to start. Many processes with this role can be started
    to spread load or improve search availability.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('search')
        @_options = Conf.getSearchConf() || {}
        amqpConnectOptions = Conf.getAmqpConf() || {}
        amqpOptions = @_options.amqpOptions || {}
        @_queriesRoutingKey = amqpOptions.queriesRoutingKey || 'search_queries'
        @_searchTimeout = @_options.searchTimeout || 30
        @_sphinxTimeout = @_options.sphinxTimeout || 10
        amqpQueueListenerOptions =
            listenRoutingKey: @_queriesRoutingKey
            listenCallback: @_processRequest
            listenQueueAutoDelete: false
            listenQueueAck: true
        _.extend(amqpQueueListenerOptions, amqpConnectOptions, amqpOptions)
        @_amqp = new AmqpQueueListener(amqpQueueListenerOptions)
    
    run: () ->
        if @_options.searchType != 'amqp'
            throw new Error("Search type in settings.coffee must be 'amqp'")
        @_connect()
    
    _connect: () ->
        @_searcher = new SphinxSearch()
        @_amqp.connect()

    _processRequest: (rawMessage, headers, deliveryInfo, callback) =>
        responseRoutingKey = deliveryInfo.replyTo
        id = "#{responseRoutingKey}_#{deliveryInfo.correlationId}"
        try
            objMessage = JSON.parse rawMessage.data.toString()
        catch e
            @_sendResponse(responseRoutingKey, deliveryInfo.correlationId, e, null)
            return callback(null, true)
        @_logger.debug 'AMQP search recieve msg ', objMessage
        timeNow = Math.round(Date.now() / 1000)
        if objMessage.timeStamp and objMessage.timeStamp < timeNow - @_searchTimeout
            @_logger.warn("Search time exceeded, skipping query #{id}")
            return callback(null, true)
        @_processSearch(id, objMessage.query, (err, res) =>
            @_logger.error("Error while searching for #{id} (query: '#{objMessage.query}')", {correlationId: id, err: err.stack or err}) if err
            @_sendResponse(responseRoutingKey, deliveryInfo.correlationId, err, res)
            @_logger.debug("Search result for #{id} (query: '#{objMessage.query}') is #{res.length} rows", {correlationId: id, rows: res.length}) if not err
            if err and (err instanceof SphinxTimeoutError or err instanceof SphinxFatalError)
                # ждем секундочку чтобы успела отправиться ошибка
                return setTimeout(() ->
                    process.exit(0)
                , 1000 + 5000 * Math.random())
            callback(null, true)
        )
        
    _sendResponse: (responseRoutingKey, correlationId, err, res) ->
        options =
            correlationId: correlationId
        @_amqp.publish(responseRoutingKey, JSON.stringify({err: err, res: res}), options)
        
    _processSearch: (id, query, callback) ->
        exitTimeout = setTimeout(() =>
            callback(new SphinxTimeoutError("Sphinx query #{id} took too long, restarting process", SPHINX_TIMEOUT_ERROR), null)
        , @_sphinxTimeout * 1000)
        @_searcher.executeQuery(query, (err, res) =>
            clearTimeout(exitTimeout)
            callback(err, res)
        )

module.exports.Searcher = new Searcher()
