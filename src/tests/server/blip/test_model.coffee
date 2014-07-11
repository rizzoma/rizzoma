sinon = require('sinon-plus')
testCase = require('nodeunit').testCase
BlipModel = require('../../../server/blip/models').BlipModel
PluginModel = require('../../../server/blip/plugin_model').PluginModel
IdUtils = require('../../../server/utils/id_utils').IdUtils
BlipSearchConverter = require('../../../server/blip/search_converter').BlipSearchConverter
dataprovider = require('dataprovider')

module.exports =
    BlipModelTest: testCase
        setUp: (callback) ->
            @_model = new BlipModel('foo')
            callback()

        testIterateBlocks: (test) ->
            @_model.content = [
                {params: {__TYPE: 'foo'}, attr: 'a1'}
                {params: {__TYPE: 'bar'}, attr: 'a2'}
            ]
            iterator = sinon.stub()
            @_model._iterateBlocks(iterator)
            test.deepEqual(['foo', {params: {__TYPE: 'foo'}, attr: 'a1'}], iterator.args[0])
            test.deepEqual(['bar', {params: {__TYPE: 'bar'}, attr: 'a2'}], iterator.args[1])
            test.done()

        testGetTextByLines: (test) ->
            @_model.content = [
                {params: {__TYPE: 'TEXT'}, t: ''}
                {params: {__TYPE: 'TEXT'}, t: 'foo'}
                {params: {__TYPE: 'LINE'}, t: ''}
                {params: {__TYPE: 'TEXT'}, t: 'bar'}
                {params: {__TYPE: 'TEXT'}, t: 'baz'}
            ]
            result = @_model._getTextByLines()
            test.deepEqual(['foo', 'barbaz'], result)
            test.done()

        testGetText: (test) ->
            code = (done, start, end, expected) =>
                model = sinon.mock(@_model)
                model
                    .expects('_getTextByLines')
                    .returns(['foo', 'bar', 'baz'])
                    .once()
                result = @_model.getText(start, end)
                test.equal(expected, result)
                model.verify()
                model.restore()
                done()
            dataprovider(test, [
                [undefined, undefined, 'foo bar baz']
                [1, undefined, 'bar baz']
                [null, 2, 'foo bar']
                [1, 3, 'bar baz']
            ], code)

        testGetTitle: (test) ->
            model = sinon.mock(@_model)
            model
                .expects('getText')
                .withArgs(0, 1)
                .returns('foo')
                .once()
            result = @_model.getTitle()
            test.equal('foo', result)
            model.verify()
            model.restore()
            test.done()

        testGetSnippet: (test) ->
            model = sinon.mock(@_model)
            model
                .expects('getText')
                .withArgs(1)
                .returns('foo')
                .once()
            result = @_model.getSnippet()
            test.equal('foo', result)
            model.verify()
            model.restore()
            test.done()

        testGetTypedContentBlocksParam: (test) ->
            @_model.content = [
                {params: {__TYPE: 'bar', arg: 'value1'}}
                {params: {__TYPE: 'foo', arg: 'value2'}}
                {params: {__TYPE: 'bar', noArg: 'value3'}}
                {params: {__TYPE: 'bar', arg: 'value4'}}
            ]
            result = @_model.getTypedContentBlocksParam('bar', 'arg')
            test.deepEqual(result, ['value1', 'value4'])
            test.done()

        testGetSearchIndexHeader: (test) ->
            plugin =
                getSearchIndexHeader: sinon.stub()
            blip = sinon.mock(BlipModel)
            blip
                .expects('_pluginMap')
                .callsArgWith(0, plugin)
                .returns([[{foo: 'bar'}], [{foo: 'baz'}]])
            convertor = sinon.stub(BlipSearchConverter, 'fromFieldsToIndexHeader')
            convertor.returns('foo')
            result = BlipModel.getSearchIndexHeader()
            test.equal('foo', result)
            test.deepEqual([{foo: 'bar'}, {foo: 'baz'}], convertor.args[0][0][7...9])
            test.ok(plugin.getSearchIndexHeader.calledOnce)
            blip.verify()
            blip.restore()
            convertor.restore()
            test.done()

        testGetSearchIndex: (test) ->
            plugin = sinon.stub(PluginModel.prototype, 'getSearchIndex')
            blip = new BlipModel('foo')
            blip.participants = [1]
            blipMock = sinon.mock(blip)
            blipMock
                .expects('_pluginMap')
                .callsArgWith(0, PluginModel)
                .returns([[{foo: 'bar'}], [{foo: 'baz'}]])
            blipMock
                .expects('getOriginalId')
                .once()
                .returns('foo')
            convertor = sinon.stub(BlipSearchConverter, 'fromFieldsToIndex')
            convertor.returns('foo')
            result = blip.getSearchIndex()
            test.equal('foo', result)
            test.deepEqual('foo', convertor.args[0][0])
            test.deepEqual([{foo: 'bar'}, {foo: 'baz'}], convertor.args[0][1][7...9])
            test.ok(plugin.calledOnce)
            sinon.verifyAll()
            sinon.restoreAll()
            test.done()
