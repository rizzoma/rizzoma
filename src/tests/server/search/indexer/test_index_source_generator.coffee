ltx = require('ltx')
sinon = require('sinon')
dataprovider = require('dataprovider')
testCase = require('nodeunit').testCase
BlipModel = require('../../../../server/blip/models').BlipModel
CouchSearchProcessor = require('../../../../server/search/couch_processor').CouchSearchProcessor
IndexSourceGenerator = require('../../../../server/search/indexer/index_source_generator').IndexSourceGenerator

module.exports =
    IndexSourceGenerator: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testXMLElementToString: (test) ->
            code = (done, element, expected) ->
                generator = sinon.mock(IndexSourceGenerator)
                generator
                    .expects('_getXMLDeclaration')
                    .once()
                    .returns('foo')
                test.equal("foo#{expected}", IndexSourceGenerator._XMLElementToString(element))
                generator.verify()
                generator.restore()
                done()
            dataprovider(test, [
                [new ltx.Element('bar'), '<bar/>']
                [new ltx.Element('bar', {baz: '1">'}).t('text&<'), '<bar baz="1&quot;&gt;">text&amp;&lt;</bar>']
            ], code)

        testGetIndexHeader: (test) ->
            blip = sinon.mock(BlipModel)
            blip
                .expects('getSearchIndexHeader')
                .once()
                .returns(new ltx.Element('foo'))
            result = IndexSourceGenerator._getIndexHeader()
            test.equal('<sphinx:docset><foo/></sphinx:docset>', result.toString())
            blip.verify()
            blip.restore()
            test.done()

        testBlipsToIndex: (test) ->
            generator = sinon.mock(IndexSourceGenerator)
            index = new ltx.Element('foo').c('bar').up()
            generator
                .expects('_getIndexHeader')
                .once()
                .returns(index)
            generator
                .expects('_addBlipToIndex')
                .once()
                .withArgs(index, 'blip1')
            generator
                .expects('_addBlipToIndex')
                .once()
                .withArgs(index, 'blip2')
            result = IndexSourceGenerator._blipsToIndex(['blip1', 'blip2'])
            test.equal('<foo><bar/></foo>', result.toString())
            generator.verify()
            generator.restore()
            test.done()

        testAddBlipToIndex: (test) ->
            code = (done, removed, expected) ->
                blip = new BlipModel()
                blipMock = sinon.mock(blip)
                blip.removed = removed
                generator = sinon.mock(IndexSourceGenerator)
                generator
                    .expects('_getKillList')
                    .once()
                    .withArgs(blip)
                    .returns(new ltx.Element('bar'))
                if not removed
                    blipMock
                        .expects('getSearchIndex')
                        .once()
                        .returns(new ltx.Element('baz'))
                index = new ltx.Element('foo')
                IndexSourceGenerator._addBlipToIndex(index, blip)
                test.equal(expected, index.toString())
                generator.verify()
                blipMock.verify()
                generator.restore()
                done()
            dataprovider(test, [
                [false, '<foo><bar/><baz/></foo>']
                [true, '<foo><bar/></foo>']
            ], code)

        testGetKillList: (test) ->
            blip = new BlipModel()
            blipMock = sinon.mock(blip)
            blipMock
                .expects('getOriginalId')
                .once()
                .returns('foo')
            result = IndexSourceGenerator._getKillList(blip)
            test.equal(result.toString(), '<sphinx:killlist><id>foo</id></sphinx:killlist>')
            blipMock.verify()
            test.done()

        testGetIndex: (test) ->
            processor = sinon.mock(CouchSearchProcessor)
            generator = sinon.mock(IndexSourceGenerator)
            processor
                .expects('getLastMergingTimestamp')
                .once()
                .callsArgWith(0, null, 'foo')
            processor
                .expects('getBlipsByTimestamp')
                .once()
                .withArgs('foo', null)
                .callsArgWith(2, null, 'bar')
            generator
                .expects('_blipsToIndex')
                .once()
                .withArgs('bar')
                .returns('baz')
            IndexSourceGenerator._getIndex((err, result) ->
                test.equal(null, err)
                test.equal('baz', result)
                processor.verify()
                processor.restore()
                generator.verify()
                generator.restore()
                test.done()
            )
