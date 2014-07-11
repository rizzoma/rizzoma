AmqpQueueListener = require('../common/amqp').AmqpQueueListener
OtError= require('./exceptions').OtError

MAX_LOG_LENGTH = 100

class SendingQueue
    ###
    Очередь на публикацию сообщений, не дает добавить в amqp новое сообщение,
    пока не опубликуется предидущее. Предотвращает перепутывание операций при от правке.
    Так же собирает задания пока устанвливается соединение с amqp.
    ###
    constructor: (@_worker, @_retryCount, @_retryTimeout) ->
        @_buffer = []
        @_stopped = true
        @_isBusy = false

    push: (task) ->
        task.retryCount = @_retryCount
        @_buffer.push(task)
        return if @_stopped or @_buffer.length > 1
        @_process()

    stop: () ->
        @_stopped = true

    start: () ->
        return if not @_stopped
        @_stopped = false
        @_process()

    _process: () ->
        return if not @_buffer.length or @_stopped or @_isBusy
        @_isBusy = true
        task = @_buffer[0]
        @_worker(task, (err) =>
            needShift = not err or not task.retryCount
            if needShift
                @_buffer.shift()
                task.callback(if err then OtError("Ot temporary not available (ot method call)") else null)
            task.retryCount--
            setTimeout(() =>
                @_isBusy = false
                @_process()
            , if needShift then 1 else @_retryTimeout)
        )

class AmqpHelper
    constructor: (settings) ->
        @_amqp = new AmqpQueueListener(settings)
        @_connected = false
        worker = (task, done) =>
            @_sendAmqpRequest(task, (err) ->
                done(err)
            )
        @_sendingQueue = new SendingQueue(worker, 3, 1000)
        @_amqp.on 'close', () =>
            @_sendingQueue.stop()
            @_connected = false
        @_amqp.connect (err) =>
            return @_logger.error(err) if err
            @_sendingQueue.start()
            @_connected = true

    _parseRawMessage: (rawMessage, callback) ->
        process.nextTick(->
            try
                msg = JSON.parse(rawMessage.data.toString())
            catch e
                @_logger.error("AMQP request JSON parse error", {rawMessage: rawMessage, err: e})
                return callback(e)
            callback(null, msg)
        )

    _sendAmqpRequest: (task, callback) ->
        {msg, routingKey, options} = task
        m = msg.substr(0, MAX_LOG_LENGTH)
        m += '…' if m.length == MAX_LOG_LENGTH
        @_logger.debug("AMQP send rpc data", { msg: m })
        @_amqp.publish(routingKey, msg, options or {}, callback)

module.exports.AmqpHelper = AmqpHelper