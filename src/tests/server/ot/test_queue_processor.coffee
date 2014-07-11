testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
QueueOtProcessor =  require('../../../server/ot/queue_processor').QueueOtProcessor
OtProcessor =  require('../../../server/ot/processor').OtProcessor

module.exports =
    TestQueueOtProcessor: testCase

        testApplyOp: (test) ->
            onOpApplied = null
            queueProcessor = new QueueOtProcessor(null)
            queueProcessorMock = sinon.mock(queueProcessor)
            queueProcessorMock
                .expects('_processBeforeOperation')
                .withArgs('foo_id', 'foo_op', 0)
                .callsArgWith(3, null, 'foo_doc', 'foo_doc_clone', 'channel_id')
            queueProcessorMock
                .expects('_processAfterOperation')
                .withArgs('foo_doc', { version: 'bar_version', content: 'bar_content' }, [ 'content' ], { op: 'bar_op' }, onOpApplied, [])
                .callsArgWith(6, null, 'bar_doc')
            otProcessorMock = sinon.mock(OtProcessor)
            otProcessorMock
                .expects('applyOp')
                .withArgs('foo_doc_clone', 'foo_op', false, 'channel_id')
                .once()
                .callsArgWith(4, null, { version: 'bar_version', content: 'bar_content' }, { op: 'bar_op' })
            otProcessorMock
                .expects('getOpsParam')
                .withArgs('bar_op')
                .once()
                .returns(['content'])
            queueProcessor.applyOp('foo_id', 'foo_op', onOpApplied, (err, doc) ->
                test.equal(doc, 'bar_doc')
                sinon.verifyAll()
                sinon.restoreAll()
                test.ifError(err)
                test.done()
            )
