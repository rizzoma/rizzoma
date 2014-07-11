testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
dataprovider = require('dataprovider')
BlipSearchResultProcessor = require('../../../server/blip/search_result_processor').BlipSearchResultProcessor
CouchBlipProcessor = require('../../../server/blip/couch_processor').CouchBlipProcessor
BlipModel = require('../../../server/blip/models').BlipModel
CouchWaveProcessor = require('../../../server/wave/couch_processor').CouchWaveProcessor
WaveModel = require('../../../server/wave/models').WaveModel
UserCouchProcessor = require('../../../server/user/couch_processor').UserCouchProcessor

module.exports =
    BlipSearchResultProcessorTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetItem: (test) ->
            prcocessorMock = sinon.mock(BlipSearchResultProcessor)
            prcocessorMock
                .expects('_hasAllPtag')
                .once()
                .withArgs('tags')
                .returns(true)
            prcocessorMock
                .expects('_isFollow')
                .once()
                .withArgs({wave_url: 'foo', groupdate: 'bar'}, 'user')
                .returns(true)
            testCode = (done, changed, expected) ->
                res = BlipSearchResultProcessor._getItem({wave_url: 'foo', groupdate: 'bar'}, changed, 'user', 'tags')
                test.deepEqual(res, expected)
                sinon.verifyAll()
                sinon.restoreAll()  
                done()
            dataprovider(test, [
                [true, {waveId: 'foo', changeDate: 'bar', follow: true}]
                [false, {waveId: 'foo'}]
            ], testCode)

        testIsFollow: (test) ->
            testCode = (done, ptags, expected) ->
                res = BlipSearchResultProcessor._isFollow({ptags}, {id: '0_u_15'})
                test.equal(res, expected)
                done()
            dataprovider(test, [
                [[1024, 9727, 7463], true]
                [[1024, 9726, 7463], false]
            ], testCode)

        testGetChangedItems: (test) ->
            prcocessorMock = sinon.mock(BlipSearchResultProcessor)
            prcocessorMock
                .expects('_getWavesAndStuffIds')
                .once()
                .withArgs('ids')
                .callsArgWith(1, null, 'waves', 'blipsIds', 'creatorsIds')
            blipProcessorMock = sinon.mock(CouchBlipProcessor)
            blipProcessorMock
                .expects('getByIdsAsDict')
                .once()
                .withArgs('blipsIds')
                .callsArgWith(1, null, 'blips')
            userProcessorMock = sinon.mock(UserCouchProcessor)
            userProcessorMock
                .expects('getByIdsAsDict')
                .once()
                .withArgs('creatorsIds')
                .callsArgWith(1, null, 'creators')
            prcocessorMock
                .expects('_getReadBlipCounts')
                .once()
                .withArgs('ids', 'userId')
                .callsArgWith(2, null, 'readBlips')
            prcocessorMock
                .expects('_getTotalBlipCounts')
                .once()
                .withArgs('ids')
                .callsArgWith(1, null, 'totalBlips')
            prcocessorMock
                .expects('_compileItems')
                .once()
                .withArgs('waves', 'blips', 'creators', 'readBlips', 'totalBlips')
                .callsArgWith(5, null, 'foo')
            BlipSearchResultProcessor._getChangedItems('ids', {id: 'userId'}, 'tags', (err, res) ->
                test.equal(null, err)
                test.equal('foo', res)
                sinon.verifyAll()
                sinon.restoreAll()       
                test.done()
            )

        testGetWavesAndStuffIds: (test) ->
            wave = new WaveModel()
            wave.rootBlipId = 'blipId'
            waveMock = sinon.mock(wave)
                .expects('getFirstParticipantWithRole')
                .once()
                .returns({id: 'creatorId'})
            prcocessorMock = sinon.mock(CouchWaveProcessor)
            prcocessorMock
                .expects('getByIdsAsDict')
                .once()
                .withArgs('ids')
                .callsArgWith(1, null, {foo: wave})
            BlipSearchResultProcessor._getWavesAndStuffIds('ids', (err, waves, rootBlipsIds, creatoresIds) ->
                test.equal(null, err)
                test.deepEqual({foo: wave}, waves)
                test.deepEqual(['blipId'], rootBlipsIds)
                test.deepEqual(['creatorId'], creatoresIds)
                sinon.verifyAll()
                sinon.restoreAll()             
                test.done()
            )

        testConvertCountsToDict: (test) ->
            counts = [
                {key: ['id1', 'bar'], value: 1},
                {key: 'id2', value: 2},
                {key: ['id3'], value: 3}
            ]
            res = BlipSearchResultProcessor._convertCountsToDict(counts)
            test.deepEqual({
                'id1': 1
                'id2': 2
                'id3': 3
            }, res)
            test.done()
        testComplileChangedWavesInfo: (test) ->
            wave = new WaveModel()
            wave.rootBlipId = 'blipId'
            waveMock = sinon.mock(wave)
            waveMock
                .expects('getFirstParticipantWithRole')
                .once()
                .returns({id: 'creatorId'})
            blip = new BlipModel()
            blipMock = sinon.mock(blip)
            blipMock
                .expects('getTitle')
                .once()
                .returns('foo')
            blipMock
                .expects('getSnippet')
                .once()
                .returns('bar')
            waves = {waveId: wave}
            blips = {blipId: blip}
            creators = {creatorId: {name: 'name', avatar: 'avatar'}}
            readBlipsStat = {waveId: 5}
            totalBlipsStat = {waveId: 20}
            BlipSearchResultProcessor._compileItems(waves, blips, creators, readBlipsStat, totalBlipsStat, (err, items) ->
                test.deepEqual({waveId: {
                    title: 'foo'
                    snippet: 'bar'
                    avatar: 'avatar'
                    name: 'name'
                    totalBlipCount: 20
                    totalUnreadBlipCount: 15
                }}, items)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
