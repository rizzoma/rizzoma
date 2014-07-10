_ = require('underscore')
async = require('async')
mysql = require('mysql')
Conf = require('../conf').Conf
SearchTemporaryNotAvailableError = require('./exceptions').SearchTemporaryNotAvailableError
SearchTimeoutError = require('./exceptions').SearchTimeoutError
SearchQueryError = require('./exceptions').SearchQueryError
SphinxFatalError = require('./exceptions').SphinxFatalError
AmqpQueueListener = require('../common/amqp').AmqpQueueListener

QUERY_SYNTAX_ERROR = require('./exceptions').QUERY_SYNTAX_ERROR
MAX_RECONNECT_COUNT = 10
RECONNECT_TIMEOUT = 2000

class BaseSearch
    ###
    Базовый класс для поисковых процессоров.
    ###
    constructor: () ->

    executeQuery: (query, callback) ->
        throw new Error("Method is not emplemented")

class SphinxSearch extends BaseSearch
    ###
    Отправляет Sphinx'y запросы на поиск.
    ###
    constructor: () ->
        @_connection = null
        @_requestQueue = null
        @_reconnectCount = 0
        @_logger = Conf.getLogger('search')

    executeQuery: (query, callback) =>
        @_requestQueue ||= async.queue(@_executeQuery, 1)
        @_requestQueue.push(query, callback)

    _executeQuery: (query, callback) =>
        return callback(new SphinxFatalError('SphinxSearch reconnect count exceeded')) if @_reconnectCount >= MAX_RECONNECT_COUNT
        @_connect()
        @_connection.query(query, (err, rows) =>
            if err and err.fatal
                @_disconnect()
                onTimeout = () =>
                    @_executeQuery(query, callback)
                return setTimeout(onTimeout, RECONNECT_TIMEOUT * Math.random())
            @_reconnectCount = 0
            return callback(new SearchQueryError(err)) if err
            callback(null, rows)
        )

    _connect: () ->
        return if @_connection
        conf = Conf.getSearchConf()
        @_connection = mysql.createConnection({
            host: conf.sphinxHost
            port: conf.sphinxPort
        })
        @_connection.on('error', @_onDisconnect)

    _disconnect: () ->
        @_reconnectCount++
        @_connection.destroy()
        @_connection = null

    _onDisconnect: (err) =>
        @_logger.warn("SphinxSearch disconnect: #{err}", {err})
        @_disconnect()


class AmqpSearch extends BaseSearch
    ###
    Отправляет по AMQP запросы на поиск
    ###
    constructor: () ->
        @_logger = Conf.getLogger('search')
        @_options = Conf.getSearchConf() || {}
        @_searchTimeout = @_options.searchTimeout || 30
        amqpConnectOptions = Conf.getAmqpConf() || {}
        amqpOptions = @_options.amqpOptions || {}
        @_responseRoutingKey = "search_responses_#{process.pid}_#{Date.now()}"
        @_queriesRoutingKey = amqpOptions.queriesRoutingKey || "search_queries"
        @_responseCallbacks = {}
        @_connected = false
        amqpQueueListenerOptions =
            listenRoutingKey: @_responseRoutingKey
            listenCallback: @_processResponse
            listenQueueAutoDelete: true
            listenQueueAck: false
        _.extend(amqpQueueListenerOptions, amqpConnectOptions, amqpOptions)
        @_amqp = new AmqpQueueListener(amqpQueueListenerOptions)
        @_amqp.on 'close', () =>
            @_connected = false
        @_amqp.on 'queue-subscribed', () =>
            @_connected = true
        @_amqp.connect((err) =>
            if err
                return @_logger.error(err)
        )

    _processResponse: (rawMessage, headers, deliveryInfo) =>
        @_logger.debug "Got search result for #{@_responseRoutingKey}_#{deliveryInfo.correlationId}"
        respCallback = @_responseCallbacks[deliveryInfo.correlationId]
        if not respCallback
            @_logger.warn("Has no search callback for #{@_responseRoutingKey}_#{deliveryInfo.correlationId}")
            return
        delete @_responseCallbacks[deliveryInfo.correlationId]
        callback = respCallback.callback
        cancelTimeout = respCallback.cancelTimeout
        clearTimeout(cancelTimeout)
        try
            objMessage = JSON.parse rawMessage.data.toString()
        catch e
            return callback(e)
        err = objMessage.err
        err = new SearchQueryError(err.message) if err and err.code == QUERY_SYNTAX_ERROR
        callback(err, objMessage.res)

    executeQuery: (query, callback) =>
        correlationId = Date.now() + '_' + Math.random().toString().slice(3, 8)
        if not @_connected
            @_logger.error("AMQP is not connected #{@_responseRoutingKey}_#{correlationId}")
            return callback(new SearchTemporaryNotAvailableError("Search temporary not available"))
        cancelTimeout = setTimeout () =>
            @_logger.error("Amqp search took too long #{@_responseRoutingKey}_#{correlationId}")
            delete @_responseCallbacks[correlationId]
            callback(new SearchTimeoutError("Search took too long"), null)
        , @_searchTimeout * 1000
        @_responseCallbacks[correlationId] = { callback: callback, cancelTimeout: cancelTimeout }
        @_sendAmqpQuery(correlationId, query)

    _sendAmqpQuery: (correlationId, query) ->
        msg =
            query: query
            timeStamp: Math.round(Date.now() / 1000)
        msg = JSON.stringify(msg)
        @_logger.debug("Send amqp search message for #{@_responseRoutingKey}_#{correlationId}", msg)
        @_amqp.publish(@_queriesRoutingKey, msg, {
            replyTo: @_responseRoutingKey
            correlationId: correlationId
        })
        
module.exports =
    BaseSearch: BaseSearch
    AmqpSearch: AmqpSearch
    SphinxSearch: SphinxSearch