_ = require('underscore')
{Conf} = require('../../conf')
{AmqpQueueListener} = require('../../common/amqp')
{ParsedMail} = require('./parsed_mail')
{EmailReplySaver} = require('./saver')


class AmqpSaveWorker
    ###
    Слушает amqp очередь и сохраняет ответы блипов
    ###
    constructor: () ->
        @_logger = Conf.getLogger('amqp-email-reply-saver')
        connectOptions = Conf.getAmqpConf() or {}
        @_responseRoutingKey = "email_reply_saver_responses"
        @_queriesRoutingKey = "email_reply_saver_queries"
        listenerSettings =
            listenRoutingKey: @_queriesRoutingKey
            listenCallback: @_process
            listenQueueAutoDelete: false
            listenQueueAck: true
        _.extend(listenerSettings, connectOptions)
        @_amqp = new AmqpQueueListener(listenerSettings)

    run: () ->
        @_amqp.connect()

    _process: (rawMessage, headers, deliveryInfo, finish) =>
        @_logger.info "Got save query for #{@_responseRoutingKey}_#{deliveryInfo.correlationId}"
        try
            rawMails = JSON.parse(rawMessage.data.toString())
        catch e
            return @_sendResponse(correlationId, e, null)
        mails = []
        for rawMail in rawMails
            mails.push(new ParsedMail(rawMail.from, rawMail.waveUrl, rawMail.blipId, rawMail.random, rawMail.text, rawMail.html, rawMail.headers))
        saver = new EmailReplySaver()
        saver.save(mails, (err, res) =>
            @_sendResponse(deliveryInfo.correlationId, err, res)
            @_logger.info("finished")
            finish?(null)
        )

    _sendResponse: (correlationId, err, res) ->
        @_amqp.publish(@_responseRoutingKey, JSON.stringify({err: err, res: res}), { correlationId: correlationId })


class AmqpSaveManager
    ###
    Публикует в очередь запрос на сохранение блипов ответов
    и слушает очередь результатов сохранения
    ###
    constructor: () ->
        @_logger = Conf.getLogger('amqp-email-reply-saver')
        @_responseCallbacks = {}
        @RESPONSE_TIMEOUT = 20
        connectOptions = Conf.getAmqpConf() or {}
        @_responseRoutingKey = "email_reply_saver_responses"
        @_queriesRoutingKey = "email_reply_saver_queries"
        listenerSettings =
            listenRoutingKey: @_responseRoutingKey
            listenCallback: @_processResponse
            listenQueueAutoDelete: true
            listenQueueAck: false
        _.extend(listenerSettings, connectOptions)
        @_amqp = new AmqpQueueListener(listenerSettings)
        @_amqp.connect((err) =>
            if err
                @_logger.error(err)
                setTimeout(()->
                    process.exit(0)
                , 90 * 1000)
        )

    _processResponse: (rawMessage, headers, deliveryInfo, finish) =>
        @_logger.info "Got save result for #{@_responseRoutingKey}_#{deliveryInfo.correlationId}"
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
        callback(objMessage.err, objMessage.res)
        finish?(null)

    save: (mails, callback) ->
        ###
        Отправляет запрос по amqp на создание блипов ответа
        ###
        correlationId = Date.now() + '_' + Math.random().toString().slice(3, 8)
        cancelTimeout = setTimeout () =>
            @_logger.error("Amqp save response timeout #{@_responseRoutingKey}_#{correlationId}")
            callback(new Error("Save response timeout"), null)
        , @RESPONSE_TIMEOUT * 1000
        @_responseCallbacks[correlationId] = {callback: callback, cancelTimeout: cancelTimeout }
        @_amqp.publish(@_queriesRoutingKey, JSON.stringify(mails), { correlationId: correlationId })

module.exports =
    AmqpSaveWorker: AmqpSaveWorker
    AmqpSaveManager: AmqpSaveManager