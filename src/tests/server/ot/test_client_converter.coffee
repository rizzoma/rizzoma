testCase = require('nodeunit').testCase
ClientOtConverter = require('../../../server/ot/client_converter').ClientOtConverter
WaveClientOtConverter = require('../../../server/ot/client_converter').WaveClientOtConverter
BlipClientOtConverter = require('../../../server/ot/client_converter').BlipClientOtConverter

getTestData = () ->
    model = 
        id: 'some_id'
        version: 'some_version'
        _rev: 'some_rev'
        timestamp: 'some_timestamp'
        _type: 'some_type'
    expected = 
        docId: 'some_id'
        v: 'some_version'
        open: true
        meta:
            ts: 'some_timestamp'
            type: 'some_type'
    return [model, expected]

module.exports =
    TestOtClientOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromModelToClientOt: (test) ->
            [model, expected] = getTestData()
            doc = ClientOtConverter.fromModelToClientOt(model)
            test.deepEqual(doc, expected)
            test.done()

    TestWaveClientOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromModelToClientOt: (test) ->
            [model, expected] = getTestData()
            model.participants = 'participants'
            model.rootBlipId = 'some_blip_id'
            model.getSharedState = () ->
                return 'public'
            expected.snapshot =
                participants: 'participants'
                rootBlipId: 'some_blip_id'
                sharedState: 'public'
            doc = WaveClientOtConverter.fromModelToClientOt(model)
            test.deepEqual(doc, expected)
            test.done()

    TestBlipClientOtConverter: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testFromModelToClientOt: (test) ->
            [model, expected] = getTestData()
            model.content = 'content'
            model.isRootBlip = true
            model.contributors = 'some_dudes'
            model.isFoldedByDefault = false
            model.removed = false
            model.waveId = 'some_wave_id'
            model.readers = 'some_another_dudes'
            expected.snapshot =
                content: 'content'
                isRootBlip: true
                contributors: 'some_dudes'
                isFoldedByDefault: false
                removed: false
                pluginData: undefined
            expected.meta.waveId = 'some_wave_id'
            expected.meta.isRead = false
            user = 
                isLoggedIn: ()->
                    return true
            doc = BlipClientOtConverter.fromModelToClientOt(model, user)
            test.deepEqual(doc, expected)
            test.done()
