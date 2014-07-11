testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
SearchResultProcessor = require('../../../server/search/result_processor').SearchResultProcessor

class TestSearchResultProcessor extends SearchResultProcessor
    constructor: () ->
        super()
        @_idField = 'id_field'
        @_changedField = 'changed_field'

    _getItem: (result, changed) ->
        return "test item #{result[@_idField]} #{changed}"

module.exports =
    SearchResultProcessorTest: testCase
        setUp: (callback) ->
            @_processor = new TestSearchResultProcessor()
            callback()

        tearDown: (callback) ->
            callback()

        testProcess: (test) ->
            prcocessorMock = sinon.mock(@_processor)
            prcocessorMock
                .expects('_getChangedItems')
                .once()
                .withArgs(['id2'], 'some_arg')
                .callsArgWith(2, null, 'foo')
            prcocessorMock
                .expects('_extendItems')
                .once()
                .withArgs(['test item id1 false', 'test item id2 true', 'test item id3 false'], {id2: 1}, 'foo')
            results =
                matches:
                    [
                        {attrs: {id_field: 'id1', changed_field: 1}}
                        {attrs: {id_field: 'id2', changed_field: 3}}
                        {attrs: {id_field: 'id3', changed_field: 2}}
                    ]
            @_processor.process(results, 2, 'some_arg', (err, res) ->
                test.equal(null, err)
                expected =
                    searchResults: ['test item id1 false', 'test item id2 true', 'test item id3 false']
                    lastSearchDate: 3
                test.deepEqual(expected, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testExtendItems: (test) ->
            items = [
                'item0'
                'item1'
                {bar: 'bar'}
                'item3'
            ]
            indexes = {some_id: 2}
            changedItems =
                'some_id': {foo: 'foo'}
            @_processor._extendItems(items, indexes, changedItems)
            expected = [
                'item0'
                'item1'
                {foo: 'foo', bar: 'bar', changed: true}
                'item3'            
            ]
            test.deepEqual(expected, items)
            test.done()
