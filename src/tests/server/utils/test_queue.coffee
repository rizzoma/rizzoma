sinon = require('sinon-plus')
async = require('async')
testCase = require('nodeunit').testCase
HashedQueue = require('../../../server/utils/queue').HashedQueue

module.exports =
    TestWaveCouchConverter: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testPush: (test) ->
            worker = () ->
            q = new HashedQueue(worker)
            qMock = sinon.mock(q)
            qMock
                .expects('_execute')
                .withArgs('firstKey')
                .once()
            q.push('firstKey', 1, 'callback')
            test.deepEqual({ firstKey: { busy: false, tasks: [ { args: [1], callback: 'callback'} ] } }, q._queue)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        test_execute: (test) ->
            worker = () ->
            q = new HashedQueue(worker)
            qMock = sinon.mock(q)
            qMock
                .expects('_worker')
                .withArgs(1)
                .once()
                .callsArgWith(1, null, 'res1')
            qMock
                .expects('_worker')
                .withArgs(2)
                .once()
                .callsArgWith(1, null, 'res2')
            tasks = [
                (callback) ->
                    q.push('key', 1, callback)
                (callback) ->
                    q.push('key', 2, callback)
            ]
            async.series(tasks, (err, res) ->
                test.deepEqual({}, q._queue)
                test.deepEqual(['res1', 'res2'], res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
