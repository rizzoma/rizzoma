global.getLogger = () ->
    return {error: ->}
testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
dataprovider = require('dataprovider')
OpListener = require('../../../server/ot/processor').OpListener
OtProcessor = require('../../../server/ot/processor').OtProcessor
OtTransformer = new (require('../../../server/ot/processor').OtTransformer)()
OperationCouchProcessor = require('../../../server/ot/operation_couch_processor').OperationCouchProcessor

DOC_ID = 'ot_processor_test_doc'
SHARE_TYPE = require('share/src/types')['volna']

module.exports =
    OtTransformer: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testTransformOp: (test) ->
            typeMock = sinon.mock(SHARE_TYPE)
            typeMock
                .expects('transform')
                .once()
                .withArgs('foo', 'bar1', 'left')
                .returns('baz1')
            typeMock
                .expects('transform')
                .once()
                .withArgs('baz1', 'bar2', 'left')
                .returns('baz2')
            op = 
                version: 5
                op: 'foo'
            res = OtTransformer.transformOp(op, [{op: 'bar1'}, {op: 'bar2'}])
            sinon.verifyAll()
            sinon.restoreAll()
            test.equal(undefined, res)
            test.equal('baz2', op.op)
            test.equal(7, op.version)
            test.done()

        testTransformOpReturnsWithException: (test) ->
            typeMock = sinon.mock(SHARE_TYPE)
            typeMock
                .expects('transform')
                .once()
                .throws(new Error('baz'))
            op = {op: 'foo'}
            res = OtTransformer.transformOp('foo', ['bar'])
            sinon.verifyAll()
            sinon.restoreAll()
            test.equal('baz', res.message)
            test.equal('foo', op.op)
            test.done()

        testTransformDoc: (test) ->
            typeMock = sinon.mock(SHARE_TYPE)
            doc = {foo: 'foo', version: 5}
            typeMock
                .expects('apply')
                .once()
                .withArgs(doc, 'bar1')
                .returns(doc)
            typeMock
                .expects('apply')
                .once()
                .withArgs(doc, 'bar2')
                .returns(doc)
            res = OtTransformer.transformDoc(doc, [{op: 'bar1', version: 5}, {op: 'bar2', version: 6}])
            sinon.verifyAll()
            sinon.restoreAll()
            test.equal(undefined, res)
            test.equal('foo', doc.foo)
            test.equal(7, doc.version)
            test.done()

        testTransformDocReturnsWithException: (test) ->
            typeMock = sinon.mock(SHARE_TYPE)
            doc = 'foo'
            typeMock
                .expects('apply')
                .once()
                .throws(new Error('baz'))
            res = OtTransformer.transformDoc(doc, ['bar'])
            sinon.verifyAll()
            sinon.restoreAll()
            test.equal('baz', res.message)
            test.equal('foo', doc)
            test.done()

    OpListener: testCase
        setUp: (callback) ->
            @_listener = new OpListener(null, [])
            callback()

        testAddDocReturnsIfDocAlreadyAdded: (test) ->
            @_listener._docs = ['foo']
            processorMock = sinon.mock(OperationCouchProcessor)
            processorMock
                .expects('getByDocId')
                .never()
            @_listener.addDoc('foo', 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual(['foo'], @_listener._docs)
            test.done()

        testAddDocReturnsIfDocAlreadyAdded: (test) ->
            @_listener._sendLocks = {foo: [5, 6, 7]}
            listenerMock = sinon.mock(@_listener)
            processorMock = sinon.mock(OperationCouchProcessor)
            listenerMock
                .expects('_createSendLock')
                .once()
                .withArgs('foo')
            processorMock
                .expects('getByDocId')
                .once('foo', 'bar', null)
                .callsArgWith(3, null, [3, 4])
            listenerMock
                .expects('_getReady')
                .once()
                .withArgs('foo')
            @_listener.addDoc('foo', 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual(['foo'], @_listener._docs)
            test.deepEqual({foo: [3, 4, 5, 6, 7]}, @_listener._sendLocks)
            test.done()

        testRemoveDocDoNothing: (test) ->
            @_listener._docs = ['bar']
            @_listener.removeDoc('foo')
            test.deepEqual(['bar'], @_listener._docs)
            test.done()

        testRemoveDoc: (test) ->
            @_listener._docs = ['bar', 'foo', 'baz']
            @_listener.removeDoc('foo')
            test.deepEqual(['bar', 'baz'], @_listener._docs)
            test.done()

        testSendDoNothing: (test) ->
            @_listener._send = sinon.mock()
            @_listener._send
                .never()
            @_listener.send({docId: 'foo'})
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual({}, @_listener._sendLocks)
            test.done()

        testSendAddsLock: (test) ->
            @_listener._send = sinon.mock()
            @_listener._send
                .never()
            @_listener._docs = ['foo']
            @_listener._sendLocks = {foo: ['bar']}
            @_listener.send({docId: 'foo'})
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual({foo: ['bar', {docId: 'foo'}]}, @_listener._sendLocks)
            test.done()

        testSend: (test) ->
            @_listener._send = sinon.mock()
            @_listener._send
                .once()
                .withArgs([{docId: 'foo'}])
            @_listener._docs = ['foo']
            @_listener._sendLocks = {bar: 'bar'}
            @_listener.send({docId: 'foo'})
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual({bar: 'bar'}, @_listener._sendLocks)
            test.done()

        testGetReady: (test) ->
            @_listener._send = sinon.mock()
            @_listener._send
                .once()
                .withArgs('foo')
            @_listener._sendLocks = {foo: 'foo', bar: 'bar'}
            @_listener._getReady('foo')
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual({bar: 'bar'}, @_listener._sendLocks)
            test.done()

        testCreateSendLock: (test) ->
            @_listener._sendLocks = {foo: 'foo'}
            @_listener._createSendLock('bar')
            test.deepEqual({foo: 'foo', bar: []}, @_listener._sendLocks)
            test.done()

    OtProcessor: testCase
        setUp: (callback) ->
            callback()

        testApplyFutureOps: (test) ->
            doc = {id: 'foo', version: 'bar'}
            processorMock = sinon.mock(OperationCouchProcessor)
            processorMock
                .expects('getByDocId')
                .once()
                .withArgs('foo', 'bar', null)
                .callsArgWith(3, null, ['baz'])
            transformerMock = sinon.mock(OtProcessor._transformer)
            transformerMock
                .expects('transformDoc')
                .once()
                .withArgs(doc, ['baz'])
                .returns(null)
            OtProcessor.applyFutureOps(doc, (err, doc, status) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal(null, err)
                test.deepEqual({id: 'foo', version: 'bar'}, doc)
                test.equal(status, true)
                test.done()
            )

        testApplyFutureOpsDoNothing: (test) ->
            doc = {id: 'foo', version: 'bar'}
            processorMock = sinon.mock(OperationCouchProcessor)
            processorMock
                .expects('getByDocId')
                .once()
                .withArgs('foo', 'bar', null)
                .callsArgWith(3, null, [])
            transformerMock = sinon.mock(OtProcessor._transformer)
            transformerMock
                .expects('transformDoc')
                .never()
            OtProcessor.applyFutureOps(doc, (err, doc, status) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal(null, err)
                test.deepEqual({id: 'foo', version: 'bar'}, doc)
                test.equal(status, undefined)
                test.done()
            )

        testApplyOpReturnsFutureVersionError: (test) ->
            OtProcessor.applyOp({version: 4}, {version: 5}, (err) ->
                test.equal('Op at future version', err.message)
                test.done()
            )

        testApplyOpReturnsTooLongError: (test) ->
            OtProcessor.applyOp({version: 40}, {version: 5}, (err) ->
                test.equal('Op too old', err.message)
                test.done()
            )

        testApplyOpReturnsOpsCountMismatchError: (test) ->
            processorMock = sinon.mock(OperationCouchProcessor)
            processorMock
                .expects('getByDocId')
                .once()
                .withArgs('foo', 3, 5)
                .callsArgWith(3, null, [1])
            OtProcessor.applyOp({id: 'foo', version: 5}, {version: 3}, (err) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal('Ops count mismatch', err.message)
                test.done()
            )

        testApplyOpReturnsOpsCountMismatchError: (test) ->
            doc = {id: 'foo', version: 5}
            op = {version: 3}
            processorMock = sinon.mock(OperationCouchProcessor)
            processorMock
                .expects('getByDocId')
                .once()
                .withArgs('foo', 3, 5)
                .callsArgWith(3, null, [1, 2])
            processorMock
                .expects('save')
                .once()
                .withArgs(op)
                .callsArgWith(1, null)
            transformerMock = sinon.mock(OtProcessor._transformer)
            transformerMock
                .expects('transformOp')
                .once()
                .withArgs(op, [1, 2])
                .returns(null)
            transformerMock
                .expects('transformDoc')
                .once()
                .withArgs(doc, [op])
                .returns(null)
            OtProcessor.applyOp(doc, op, (err, doc, op) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal(null, err)
                test.deepEqual({id: 'foo', version: 5}, doc)
                test.equal(3, op.version)
                test.ok(+op.timestamp > 0)
                test.done()
            )

        testSubscribeChannel: (test) ->
            listenerMock = sinon.mock(OpListener.prototype)
            listenerMock
                .expects('addDoc')
                .once()
                .withArgs('bar', 'bar_version')
            OtProcessor.subscribeChannel('foo', {bar: 'bar_version'}, 'baz', 'listener')
            sinon.verifyAll()
            sinon.restoreAll()
            listener = OtProcessor._subscriptions['foo']['baz']
            test.equal('listener', listener._send)
            test.done()

        testUnsubscribeFromChannel: (test) ->
            testCode = (done, subscriptions, expected) ->
                OtProcessor._subscriptions = subscriptions
                OtProcessor.unsubscribeFromChannel('foo', 'bar')
                test.deepEqual(expected, OtProcessor._subscriptions)
                done()
            dataprovider(test, [
                [
                    {baz: 'baz'}
                    {baz: 'baz'}
                ]
                [
                    {foo: {baz: 'baz'}}
                    {foo: {baz: 'baz'}}
                ]
                [
                    {foo: {bar: 'bar'}, other: 'other'}
                    {other: 'other'}
                ]
                [
                    {foo: {bar: 'bar', other: 'other'}}
                    {foo: {other: 'other'}}
                ]
            ], testCode)

        testSubscribeDoc: (test) ->
            listener = new OpListener(null, [])
            listenerMock = sinon.mock(listener)
            listenerMock
                .expects('addDoc')
                .once()
                .withArgs('baz', 'baz_version')
            OtProcessor._subscriptions = {foo: {bar: listener}}
            OtProcessor.subscribeDoc('foo', 'baz', 'baz_version', 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testUnsubscribeDoc: (test) ->
            listener = new OpListener(null, [])
            listenerMock = sinon.mock(listener)
            listenerMock
                .expects('removeDoc')
                .once()
                .withArgs('baz')
            OtProcessor._subscriptions = {foo: {bar: listener}}
            OtProcessor.unsubscribeDoc('foo', 'baz', 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testSendOp: (test) ->
            op = {listenerId: 'foo'}
            listener = new OpListener(null, [])
            listenerMock = sinon.mock(listener)
            listenerMock
                .expects('send')
                .twice()
                .withArgs(op)
            OtProcessor._subscriptions =
                bar:
                    foo: listener
                    foo1: listener
                    foo2: listener
            OtProcessor.sendOp('bar', op)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testGetOpName: (test) ->
            op =
                op: [{p: ['foo', 'other']}, {p: ['bar']}, {p: ['baz', 'other']}]
            res = OtProcessor.getOpName(op)
            test.deepEqual(['foo', 'bar', 'baz'], res)
            test.done()
