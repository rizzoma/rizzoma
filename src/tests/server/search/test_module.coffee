global.getLogger = () ->
    return {
        error: ->
        debug: ->
    }

sinon = require('sinon')
testCase = require('nodeunit').testCase
dataprovider = require('dataprovider')
SearchModule = require('../../../server/search/module').SearchModule
Conf = require('../../../server/conf').Conf
CouchSearchProcessor = require('../../../server/search/couch_processor').CouchSearchProcessor
DateUtils = require('../../../server/utils/date_utils').DateUtils
Anonymous = require('../../../user/models').Anonymous
UserGenerator = require('../../../server/user/generator').UserGenerator
IndexSourceGenerator = require('../../../server/search/index_source_generator').IndexSourceGenerator

module.exports =
    SerachModuleTest: testCase

        setUp: (callback) ->
            SearchModule.prototype._processDelayedRequests = ->
            @_searchModule = new SearchModule()
            @_clock = sinon.useFakeTimers()
            @_testTime = @_searchModule._indexingThreshold * 2
            callback()

        tearDown: (callback) ->
            @_clock.restore()
            callback()

        testMakeIndexSourceWhenBusy: (test)->
            @_searchModule._isBusy = true
            @_searchModule._hasDelayedRequests = 'foo'
            onTimestampStub = sinon.stub(@_searchModule, '_onTimestamp')
            @_searchModule.makeIndexSource({callback: ->})
            @_clock.tick(@_testTime)
            test.ok(@_searchModule._hasDelayedRequests)
            test.ok(not onTimestampStub.called)
            onTimestampStub.restore()
            test.done()

        testMakeIndexSourceWhenNotBusy: (test)->
            @_searchModule._isBusy = false
            onTimestampStub = sinon.stub(@_searchModule, '_onTimestamp')
            @_searchModule.makeIndexSource({callback: ->})
            @_clock.tick(@_testTime)
            test.ok(@_searchModule._isBusy)
            test.ok(onTimestampStub.called)
            onTimestampStub.restore()
            test.done()

        testOnTimestamp: (test) ->
            indexStub = sinon.stub(@_searchModule, 'index')
            indexStub.callsArgWith(0, null)
            mergeStub = sinon.stub(@_searchModule, 'merge')
            mergeStub.callsArgWith(0, null)
            processDelayedRequestsStub = sinon.stub(@_searchModule, '_processDelayedRequests')
            @_searchModule._onTimestamp((err, res) ->
                test.equal(!!err, false)
                test.ok(processDelayedRequestsStub.called)
                indexStub.restore()
                mergeStub.restore()
                processDelayedRequestsStub.restore()
                test.done()
            )
            
        testBuildQuery: (test) ->
            Anonymous.id = 'foo'
            code = (done, user, query, expected) =>
                getOriginalIdStub = sinon.stub(UserGenerator, 'getOriginalId')
                getOriginalIdStub.withArgs('foo').returns('foo1')
                getOriginalIdStub.withArgs('bar').returns('bar1')
                result = @_searchModule._buildQuery(user, query)
                test.equal(result.query, expected.query)
                test.equal(result.groupsort, expected.groupsort)
                test.equal(result.filters.length, 1)
                test.deepEqual(result.filters[0].values, expected.values)
                getOriginalIdStub.restore()
                done()
            expected = [
                [{loggedIn: true, id: 'bar'}, undefined, {query: '', groupsort: 'groupdate desc', values: ['foo1', 'bar1']}]
                [{loggedIn: false}, '', {query: '', groupsort: 'groupdate desc', values: ['foo1']}]
                [{loggedIn: false}, 'foo', {query: 'foo', groupsort: '@relevance desc', values: ['foo1']}]
            ]
            dataprovider(test, expected, code)

        testMergeDoNothing: (test) ->
            @_searchModule._mergingThreshold = 10
            getLastMergingTimestampStub = sinon.stub(CouchSearchProcessor, 'getLastMergingTimestamp')
            getLastMergingTimestampStub.callsArgWith(0, null, 1)
            getCurrentTimestampStub = sinon.stub(DateUtils, 'getCurrentTimestamp')
            getCurrentTimestampStub.returns(1)
            runCommandStub = sinon.stub(@_searchModule, '_runCommand')
            setLastMergingTimestampStub = sinon.stub(CouchSearchProcessor, 'setLastMergingTimestamp')
            @_searchModule.merge((err) ->
                test.ok(not err)
                test.ok(not runCommandStub.called)
                test.ok(not setLastMergingTimestampStub.called)
                getLastMergingTimestampStub.restore()
                setLastMergingTimestampStub.restore()
                runCommandStub.restore()
                getCurrentTimestampStub.restore()
                test.done()
            )

        testMergeRunMerging: (test) ->
            @_searchModule._mergeCommand = 'foo'
            @_searchModule._mergingThreshold = 10
            getLastMergingTimestampStub = sinon.stub(CouchSearchProcessor, 'getLastMergingTimestamp')
            getLastMergingTimestampStub.callsArgWith(0, null, 1)
            getCurrentTimestampStub = sinon.stub(DateUtils, 'getCurrentTimestamp')
            getCurrentTimestampStub.returns(100)
            runCommandStub = sinon.stub(@_searchModule, '_runCommand')
            runCommandStub.callsArgWith(1, null)
            setLastMergingTimestampStub = sinon.stub(CouchSearchProcessor, 'setLastMergingTimestamp')
            setLastMergingTimestampStub.callsArgWith(1, null)
            indexSourceGeneratorMock = sinon.mock(IndexSourceGenerator.prototype)
            indexSourceGeneratorMock
                .expects('outDeltaIndexSource')
                .once()
                .returns('xml')
            
            @_searchModule.merge((err) ->
                test.ok(not err)
                test.equal(setLastMergingTimestampStub.args[0][0], 95) #100-5 сек
                test.equal(runCommandStub.args[0][0], 'foo')
                indexSourceGeneratorMock.verify()
                indexSourceGeneratorMock.restore()
                getLastMergingTimestampStub.restore()
                setLastMergingTimestampStub.restore()
                runCommandStub.restore()
                getCurrentTimestampStub.restore()
                test.done()
            )