testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
SequenceGenerator = require('../../../server/common/generator').SequenceGenerator
Generator = require('../../../server/common/generator').Generator

module.exports =
    SequenceGeneratorTest: testCase
        setUp: (callback) ->
            SequenceGenerator::_init = ->
            @_generator = new SequenceGenerator('foo')
            callback()

        testGetNext: (test) ->
            generatorMock = sinon.mock(@_generator)
            generatorMock
                .expects('_processAwaitingRequests')
                .once()
            @_generator.getNext('foo', 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.deepEqual([{offset: 'foo', callback: 'bar'}], @_generator._awaitingRequests)
            test.done()

        testGetTotalOffset: (test) ->
            res = @_generator._getTotalOffset([{offset: 10}, {offset: 2}, {offset: 6}])
            test.equal(18, res)
            test.done()

        testProcessCallbacksSuccess: (test) ->
            generatorMock = sinon.mock(@_generator)
            generatorMock
                .expects('_processCallbacksOnSuccess')
                .once()
                .withExactArgs('foo', 'bar')
            @_generator._processCallbacks('foo', false, 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testProcessCallbacksError: (test) ->
            generatorMock = sinon.mock(@_generator)
            generatorMock
                .expects('_processCallbacksOnError')
                .once()
                .withExactArgs('foo', 'baz')
            @_generator._processCallbacks('foo', 'baz', 'bar')
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()

        testProcessCallbacksOnError: (test) ->
            callback = sinon.stub()
            callbacks = [{callback: callback}, {callback: callback}]
            @_generator._processCallbacksOnError(callbacks, 'foo')
            test.equal(2, callback.callCount)
            test.deepEqual([['foo', null], ['foo', null]], callback.args)
            test.done()

        testProcessCallbacksOnSuccess: (test) ->
            callback = sinon.stub()
            callbacks = [{offset: 3, callback: callback}, {offset: 1, callback: callback}]
            @_generator._processCallbacksOnSuccess(callbacks, {start: 51})
            test.equal(2, callback.callCount)
            test.deepEqual([[null, [51, 52, 53]], [null, [54]]], callback.args)
            test.done()

        testProcessAwaitingRequests: (test) ->
            @_generator._isBusy = false
            @_generator._awaitingRequests = 'foo'
            generatorMock = sinon.mock(@_generator)
            generatorMock
                .expects('_getTotalOffset')
                .withExactArgs('foo')
                .returns('bar')
            generatorMock
                .expects('_executeRequest')
                .withArgs('bar')
                .callsArgWith(1, 'err', 'range')
            generatorMock
                .expects('_processCallbacks')
                .withExactArgs('foo', 'err', 'range')
            @_generator._processAwaitingRequests()
            sinon.verifyAll()
            sinon.restoreAll()
            test.equal(false, @_generator._isBusy)
            test.deepEqual([], @_generator._awaitingRequests)
            test.done()

    GeneratorTest: testCase
        setUp: (callback) ->
            Generator::_sequencerId = 'foo'
            Generator::_typePrefix = 'test'
            SequenceGenerator::_init = ->
            @_generator = new Generator()
            callback()

        testGetNext: (test) ->
            generatorMock = sinon.mock(@_generator._sequenceGenerator)
            generatorMock
                .expects('getNext')
                .withArgs(1)
                .callsArgWith(1, null, [15])
            @_generator.getNext((err, id) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal(null, err)
                test.equal('0_test_f', id)
                test.done()
            )

        testGetNextWithArg: (test) ->
            sequenceGeneratorMock = sinon.mock(@_generator._sequenceGenerator)
            generatorMock = sinon.mock(@_generator)
            sequenceGeneratorMock
                .expects('getNext')
                .withArgs(1)
                .callsArgWith(1, null, [15])
            generatorMock
                .expects('_getParts')
                .withArgs('foo', 15)
                .returns(['1', '2', '3'])
            @_generator.getNext('foo', (err, id) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal(null, err)
                test.equal('1_2_3', id)
                test.done()
            )

        testGetNextRange: (test) ->
            generatorMock = sinon.mock(@_generator._sequenceGenerator)
            generatorMock
                .expects('getNext')
                .withArgs(10)
                .callsArgWith(1, null, [13, 14, 15])
            @_generator.getNextRange(10, (err, id) ->
                sinon.verifyAll()
                sinon.restoreAll()
                test.equal(null, err)
                test.deepEqual(['0_test_d', '0_test_e', '0_test_f'], id)
                test.done()
            )
