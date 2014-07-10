testCase = require('nodeunit').testCase
sinon = require('sinon')
DocumentCouchOtConverter = require('../../../server/ot/couch_converter').DocumentCouchOtConverter
WaveCouchOtConverter = require('../../../server/ot/couch_converter').WaveCouchOtConverter
BlipCouchOtConverter = require('../../../server/ot/couch_converter').BlipCouchOtConverter
OperationCouchOtConverter = require('../../../server/ot/couch_converter').OperationCouchOtConverter

getTestDataToEntity = () ->
    doc =
        id: 'some_id'
        version: 'some_version'
        _rev: 'some_rev'
        timestamp: 'some_timestamp'
        type: 'some_type'
    expected =
        id: 'some_id'
        v: 'some_version'
        meta:
            _rev: 'some_rev'
            ts: 'some_timestamp'
            type: 'some_type'
    return [doc, expected]

getTestDataToCouch = () ->
    entity =    
        id: 'some_id'
        v: 'some_version'
        meta:
            _rev: 'some_rev'
            ts: 'some_timestamp'
            type: 'some_type'
    expected =
        id: 'some_id'
        version: 'some_version'
        _rev: 'some_rev'
        timestamp: 'some_timestamp'
        type: 'some_type'
    return [entity, expected]

module.exports =
    TestDocumentCouchOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromCouchToOtEntity: (test) ->
            getEntityInstanceStub = sinon.stub(DocumentCouchOtConverter, '_getEntityInstance')
            getEntityInstanceStub.returns({meta: {}})
            [doc, expected] = getTestDataToEntity()
            entity = DocumentCouchOtConverter.fromCouchToOtEntity(doc)
            test.deepEqual(entity, expected)
            getEntityInstanceStub.restore()
            test.done()

        testFromOtEntityToCouch: (test) ->
            [entity, expected] = getTestDataToCouch()
            doc = DocumentCouchOtConverter.fromOtEntityToCouch(entity)
            test.deepEqual(doc, expected)
            test.done()

    TestWaveCouchOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromCouchToOtEntity: (test) ->
            [doc, expected] = getTestDataToEntity()
            doc.participants = 'some_participants'
            doc.rootBlipId = 'some_blip'
            doc.sharedState = 'public'
            expected.snapshot =
                participants: 'some_participants'
                rootBlipId: 'some_blip'
                sharedState: 'public'
            entity = WaveCouchOtConverter.fromCouchToOtEntity(doc)
            test.deepEqual(entity, expected)
            test.done()

        testFromOtEntityToCouch: (test) ->
            [entity, expected] = getTestDataToCouch()
            entity.snapshot =
                participants: 'some_participants'
                rootBlipId: 'some_blip'
                sharedState: 'public'
            expected.participants = 'some_participants'
            expected.rootBlipId = 'some_blip'
            expected.sharedState = 'public'
            doc = WaveCouchOtConverter.fromOtEntityToCouch(entity)
            test.deepEqual(doc, expected)
            test.done()

    TestBlipCouchOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromCouchToOtEntity: (test) ->
            [doc, expected] = getTestDataToEntity()
            doc.content = 'content'
            doc.isRootBlip = true
            doc.contributors = 'some_dudes'
            doc.isFoldedByDefault = false
            doc.removed = true
            doc.waveId = 'some_wave_id'
            doc.readers = 'some_another_id'
            expected.snapshot =
                content: 'content'
                isRootBlip: true
                contributors: 'some_dudes'
                isFoldedByDefault: false
                removed: true
            expected.meta.waveId = 'some_wave_id'
            expected.meta.readers = 'some_another_id'
            entity = BlipCouchOtConverter.fromCouchToOtEntity(doc)
            test.deepEqual(entity, expected)
            test.done()

        testFromOtEntityToCouch: (test) ->
            [entity, expected] = getTestDataToCouch()
            entity.snapshot =
                content: 'content'
                isRootBlip: true
                contributors: 'some_dudes'
                isFoldedByDefault: false
                removed: true
            entity.meta.waveId = 'some_wave_id'
            entity.meta.readers = 'some_another_id'
            expected.content = 'content'
            expected.isRootBlip = true
            expected.contributors = 'some_dudes'
            expected.isFoldedByDefault = false
            expected.removed = true
            expected.waveId = 'some_wave_id'
            expected.readers = 'some_another_id'            
            doc = BlipCouchOtConverter.fromOtEntityToCouch(entity)
            test.deepEqual(doc, expected)
            test.done()

    TestOperationCouchOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromCouchToOtEntity: (test) ->
            doc =
                docId: 'some_name'
                op: 'op'
                v: 'some_version'
            expected =
                docId: 'some_name'
                op: 'op'
                v: 'some_version'
                meta:
                    type:
                        'operation'
            entity = OperationCouchOtConverter.fromCouchToOtEntity(doc)
            test.deepEqual(entity, expected)
            test.done()

        testFromOtEntityToCouch: (test) ->
            entity =
                docId: 'some_name'
                op: 'op'
                v: 'some_version'
            expected =
                type: 'operation'
                docId: 'some_name'
                op: 'op'
                v: 'some_version'            
            doc = OperationCouchOtConverter.fromOtEntityToCouch(entity)
            test.done()

