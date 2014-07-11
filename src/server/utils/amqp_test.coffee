AmqpQueueListener = require('../common/amqp').AmqpQueueListener
AmqpAdapter = require('../common/amqp').AmqpAdapter

KEY = 'test_key'

class Listener
    constructor:() ->
        options =
            listenRoutingKey: KEY
            listenCallback: @_onMessage
            listenQueueAutoDelete: false
            listenQueueAck: true
        @_amqp = new AmqpQueueListener(options)
        @_amqp.connect()

    _onMessage: (data, header, info, callback) ->
        console.log 'Got message: ', data
        console.log 'with header: ', header
        console.log 'info: ', info
        callback(null, true)

class Emitter
    constructor: ()->
        options =
            listenRoutingKey: KEY
            listenQueueAutoDelete: false
            listenQueueAck: true
        @_getMessage('a')
        @_amqp = new AmqpAdapter(options)
        @_amqp.connect()

    run: () ->
        setInterval(@_send, 1000)

    _getMessage: (char) ->
        @_message = ''
        for i in [1..50000]
            @_message += char

    _send: () =>
        @_amqp.publish(KEY, @_message, {})

module.exports =
    Listener: Listener
    Emitter: new Emitter()
