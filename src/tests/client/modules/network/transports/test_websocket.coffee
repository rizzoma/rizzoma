sinon = require('sinon')
testCase = require('nodeunit').testCase;
Websocket = require('../../../../../client/modules/network/transports/websocket').Websocket

module.exports =
    WesocketTest: testCase
        setUp: (callback) ->
            @wnd = global['window']            
            global['window'] = {'expressSessionId': 'expressSessionId' }
            sinon.stub(Websocket.prototype, '_init')
            callback()

        tearDown: (callback) ->
            Websocket.prototype._init.restore()
            global['window'] = @wnd
            callback()

        testEmit: (test) ->
            @websocket = new Websocket()
            @websocket._socket =
                emit: (message, data) ->
            mockSocket = sinon.mock @websocket._socket
            request = {'serialize': ->
                return 1
            }
            data =
                procedureName: 'procedureName'
                request: 1
                expressSessionId: 'expressSessionId'
            mockSocket.expects('emit').withExactArgs('message', data).once()

            @websocket.emit 'procedureName', request
            
            mockSocket.verify()
            mockSocket.restore()
            test.done()
