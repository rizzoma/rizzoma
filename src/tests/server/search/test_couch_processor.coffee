sinon = require('sinon')
testCase = require('nodeunit').testCase
CouchSearchProcessor = require('../../../server/search/couch_processor').CouchSearchProcessor
CouchWaveProcessor = require('../../../server/wave/couch_processor').CouchWaveProcessor
CouchBlipProcessor = require('../../../server/blip/couch_processor').CouchBlipProcessor
WaveCouchConverter = require('../../../server/wave/couch_converter').WaveCouchConverter
BlipCouchConverter = require('../../../server/blip/couch_converter').BlipCouchConverter
UserGenerator = require('../../../server/user/generator').UserGenerator
Conf = require('../../../server/conf').Conf

module.exports =
    CouchSearchProcessorTest: testCase
        setUp: (callback) ->
            @_db = Conf.getDb('main')
            callback()

        testSaveDocWithoutRev: (test) ->
            CouchSearchProcessor._saveDoc('test_doc', null, 'foo', (err, res) =>
                test.equal(err, null)
                @_db.get('test_doc', (err, doc) =>
                    test.equal(doc.timestamp, 'foo')
                    @_db.remove(doc._id, doc._rev, () ->
                        test.done()
                    )
                )
            )

        testSaveDocWithRev: (test) ->
            @_db.save('test_doc', {timestamp: 'foo'}, (err, res) =>
                CouchSearchProcessor._saveDoc(res.id, res.rev, 'bar', (err, res) =>
                    test.equal(err, null)
                    @_db.get('test_doc', (err, doc) =>
                        test.equal(doc.timestamp, 'bar')
                        @_db.remove(doc._id, doc._rev, () ->
                            test.done()
                        )
                    )
                )
            )

        testGetOrCreateDocOnlyGetDoc: (test) ->
            getStub = sinon.stub(@_db, 'get')
            getStub.callsArgWith(1, null, {timestamp: 'foo'})
            CouchSearchProcessor._getOrCreateDoc('some_id', null, (err, res) ->
                test.equal(err, null)
                test.equal(res, 'foo')
                test.equal(getStub.args[0][0], 'some_id')
                getStub.restore()
                test.done()
            )

        testGetOrCreateDocGetAndCreateDoc: (test) ->
            getStub = sinon.stub(@_db, 'get')
            getStub.callsArgWith(1, {error: 'not_found'}, null)
            saveDocStub = sinon.stub(CouchSearchProcessor, '_saveDoc')
            saveDocStub.callsArgWith(3, null, 'foo')
            CouchSearchProcessor._getOrCreateDoc('some_id', 'bar', (err, res) ->
                test.equal(err, null)
                test.equal(res, 'foo')
                test.equal(getStub.args[0][0], 'some_id')
                test.deepEqual(saveDocStub.args[0][0...3], ['some_id', null, 'bar'])
                getStub.restore()
                saveDocStub.restore()
                test.done()
            )

        testUpdateOrCreateDocOnlyUpdateDoc: (test) ->
            getStub = sinon.stub(@_db, 'get')
            getStub.callsArgWith(1, null, {_rev: 'some_rev'})
            saveDocStub = sinon.stub(CouchSearchProcessor, '_saveDoc')
            saveDocStub.callsArgWith(3, null, 'foo')
            CouchSearchProcessor._updateOrCreateDoc('some_id', 'bar', (err, res) ->
                test.equal(err, null)
                test.equal(res, 'foo')
                test.equal(getStub.args[0][0], 'some_id')
                test.deepEqual(saveDocStub.args[0][0...3], ['some_id', 'some_rev', 'bar'])
                getStub.restore()
                saveDocStub.restore()
                test.done()
            )

        testUpdateOrCreateDocCreateAndUpdateDoc: (test) ->
            getStub = sinon.stub(@_db, 'get')
            getStub.callsArgWith(1, {error: 'not_found'}, null)
            saveDocStub = sinon.stub(CouchSearchProcessor, '_saveDoc')
            saveDocStub.callsArgWith(3, null, 'foo')
            CouchSearchProcessor._updateOrCreateDoc('some_id', 'bar', (err, res) ->
                test.equal(err, null)
                test.equal(res, 'foo')
                test.equal(getStub.args[0][0], 'some_id')
                test.deepEqual(saveDocStub.args[0][0...3], ['some_id', null, 'bar'])
                getStub.restore()
                saveDocStub.restore()
                test.done()
            )

        testAddParticipntsToBlip: (test) ->
            getOriginalIdStub = sinon.stub(UserGenerator, 'getOriginalId')
            getOriginalIdStub.withArgs('a1').returns('b1')
            getOriginalIdStub.withArgs('a2').returns('b2')
            getOriginalIdStub.withArgs('a3').returns('b3')
            blip = {}
            CouchSearchProcessor._addParticipantsToBlip(blip, [{id: 'a1'}, {id: 'a2'}, {id: 'a3'}])
            test.deepEqual(blip.participants, ['b1', 'b2', 'b3'])
            getOriginalIdStub.restore()
            test.done()

        testAddBlipsByWaves: (test) ->
            getByWaveIdsStub = sinon.stub(CouchBlipProcessor, 'getByWaveIds')
            getByWaveIdsStub.callsArgWith(1, null, [{waveId: 'w1', id: 'b1'}, {waveId: 'w2', id: 'b2'}])
            addParticipantsToBlipStub = sinon.stub(CouchSearchProcessor, '_addParticipantsToBlip')
            result = {}
            CouchSearchProcessor._addBlipsByWaves({w1: {participants: 'foo'}, w2: {participants: 'bar'}}, result, (err, res) ->
                test.equal(err, null)
                test.equal(res, true)
                test.deepEqual(getByWaveIdsStub.args[0][0], ['w1', 'w2'])
                test.deepEqual(addParticipantsToBlipStub.args[0], [{waveId: 'w1', id: 'b1'}, 'foo'])
                test.deepEqual(addParticipantsToBlipStub.args[1], [{waveId: 'w2', id: 'b2'}, 'bar'])
                test.deepEqual(result, {b1: {waveId: 'w1', id: 'b1'}, b2: {waveId: 'w2', id: 'b2'}})
                getByWaveIdsStub.restore()
                addParticipantsToBlipStub.restore()
                test.done()
            )

        testAddParticipantsByWaveIds: (test) ->
            getParticipantsByWaveIdsStub = sinon.stub(CouchWaveProcessor, 'getParticipantsByWaveIds')
            getParticipantsByWaveIdsStub.callsArgWith(1, null, [{key: 'w1', value: 'foo'}, {key: 'w2', value: 'bar'}])
            addParticipantsToBlipStub = sinon.stub(CouchSearchProcessor, '_addParticipantsToBlip')
            blipsByWaveId =
                w1: ['b1']
                w2: ['b2', 'b3']
            CouchSearchProcessor._addParticipantsByWaveIds(blipsByWaveId, (err, res) ->
                test.equal(err, null)
                test.equal(res, true)
                test.deepEqual(getParticipantsByWaveIdsStub.args[0][0], ['w1', 'w2'])
                test.deepEqual(addParticipantsToBlipStub.args[0], ['b1', 'foo'])
                test.deepEqual(addParticipantsToBlipStub.args[1], ['b2', 'bar'])
                test.deepEqual(addParticipantsToBlipStub.args[2], ['b3', 'bar'])
                getParticipantsByWaveIdsStub.restore()
                addParticipantsToBlipStub.restore()
                test.done()
            )

        testGetGroupedDocsStructures: (test) ->
            docs = [
                {doc: 'd1'}
                {doc: 'd2'}
                {doc: 'd3'}
            ]
            getDocTypeStub = sinon.stub(CouchSearchProcessor, '_getDocType')
            getDocTypeStub.withArgs('d1').returns('wave')
            getDocTypeStub.withArgs('d2').returns('blip')
            getDocTypeStub.withArgs('d3').returns('blip')
            fillWaveModelStub = sinon.stub(WaveCouchConverter, 'fromCouchToModel')
            fillWaveModelStub.withArgs('d1').returns({id: 'w0'})
            fillBlipModelStub = sinon.stub(BlipCouchConverter, 'fromCouchToModel')
            fillBlipModelStub.withArgs('d2').returns({id: 'b1', waveId: 'w1'})
            fillBlipModelStub.withArgs('d3').returns({id: 'b2', waveId: 'w1'})
            result = CouchSearchProcessor._getGroupedDocsStructures(docs)
            test.deepEqual(result, [
                {
                    b1:
                        {id: 'b1', waveId: 'w1'}
                    b2:
                        {id: 'b2', waveId: 'w1'}
                },                
                {w0:
                    {id: 'w0'}
                },
                {w1:
                    [
                        {id: 'b1', waveId: 'w1'}
                        {id: 'b2', waveId: 'w1'}
                    ]
                }
            ])
            fillWaveModelStub.restore()
            fillBlipModelStub.restore()
            getDocTypeStub.restore()
            test.done()

        testGetBlipsByTimestamp: (test) ->
            blips =
                b1: 'b1'
                b2: 'b2'
            viewStub = sinon.stub(CouchSearchProcessor._db, 'view')
            viewStub.callsArgWith(2, null, 'docs')
            getGroupedDocsStructuresStub = sinon.stub(CouchSearchProcessor, '_getGroupedDocsStructures')
            getGroupedDocsStructuresStub.withArgs('docs').returns([blips, 'foo', 'bar'])
            addBlipsByWavesStub = sinon.stub(CouchSearchProcessor, '_addBlipsByWaves')
            addBlipsByWavesStub.callsArgWith(2, null, true)
            addParticipantsByWaveIdsStub = sinon.stub(CouchSearchProcessor, '_addParticipantsByWaveIds')
            addParticipantsByWaveIdsStub.callsArgWith(1, null, true)
            CouchSearchProcessor.getBlipsByTimestamp(1, (err, res) ->
                test.equal(err, null)
                test.deepEqual(res, ['b1', 'b2'])
                test.deepEqual(addBlipsByWavesStub.args[0][0...2], ['foo', blips])
                test.equal(addParticipantsByWaveIdsStub.args[0][0], 'bar')
                viewStub.restore()
                getGroupedDocsStructuresStub.restore()
                addBlipsByWavesStub.restore()
                addParticipantsByWaveIdsStub.restore()
                test.done()
            )
