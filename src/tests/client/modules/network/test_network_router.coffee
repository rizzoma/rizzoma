sinon = require('sinon')
testCase = require('nodeunit').testCase;
NetworkRouter = require('../../../../../src/client/modules/network/network_router').NetworkRouter
UnknownTransport = require('../../../../../src/share/exceptions').UnknownTransport

module.exports =
    NetworkRouterTest: testCase
        setUp: (callback) ->
            sinon.stub NetworkRouter.prototype, '_initTransports'
            @networkRouter = new NetworkRouter()
            callback()

        tearDown: (callback) ->
            NetworkRouter.prototype._initTransports.restore()
            @networkRouter._transports = []
            callback()

        testCallEmit: (test) ->
            @networkRouter._callCounter = 42
            stubSetProperty = sinon.spy()
            request =
                callback: 'callback'
                setProperty: stubSetProperty
            stubEmit = sinon.spy()
            @networkRouter._transports['testTransport'] = 
                emit: stubEmit

            @networkRouter._call 'testTransport', 'testProcedure', request

            test.equal @networkRouter._callCounter, 43, "call counter must be incremented"
            test.equal @networkRouter._callStack['k43'], 'callback', "callStack must be updated"
            test.ok stubSetProperty.calledOnce, "request.setProperty must be called once"
            test.deepEqual stubSetProperty.args[0], ['callId', 'k43'], "request.setProperty must be called with callId and value"
            test.ok stubEmit.calledOnce, "emit must be called once"
            test.deepEqual stubEmit.args[0], ['testProcedure', request], "emit must be called with procedureName and request"
            test.done()

        testCallThrows: (test) ->
            block = () =>
                @networkRouter._call 'testTransport', 'testProcedure', 'request'                
            test.throws block, UnknownTransport, "must throws excpetion UnknownTransport"
            test.done()

        testOnTransportReceiveCallCallback: (test) ->
            stubCallback = sinon.spy()
            response =
                callId: 'foo'
                data: 'bar'
                wait: true
            @networkRouter._callStack['foo'] = stubCallback
            @networkRouter._onTransportReceive response
            test.ok stubCallback.calledOnce, "callback must be called once"
            test.deepEqual stubCallback.args[0], ['bar'], "callback must be aclled with specified args"
            test.ok !!@networkRouter._callStack['foo'], "callback must be alive"
            test.done()

        testOnTransportReceiveCallAndDeleteCallback: (test) ->
            stubCallback = sinon.spy()
            response =
                callId: 'foo'
                data: 'bar'
            @networkRouter._callStack['foo'] = stubCallback
            @networkRouter._onTransportReceive response
            test.ok stubCallback.calledOnce, "callback must be called once"
            test.deepEqual stubCallback.args[0], ['bar'], "callback must be aclled with specified args"
            test.ifError @networkRouter._callStack['foo'], "callback must be dead"
            test.done()
