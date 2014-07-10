testCase = require('nodeunit').testCase;
ClientTransport = require('../../share/client_transport').ClientTransport
NotImplementedError = require('../../share/exceptions').NotImplementedError

module.exports =
    ClientTransportTest: testCase
        setUp: (callback) ->
            @transport = new ClientTransport()
            callback()

        testEmit: (test) ->
            block = () =>
                @transport.emit()
            test.throws block, NotImplementedError, 'must throws NotImplemented exception'
            test.done()

        testInit: (test) ->
            block = () =>
                @transport._init()
            test.throws block, NotImplementedError, 'must throws NotImplemented exception'
            test.done()