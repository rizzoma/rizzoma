global.getLogger = () ->
    return {error: ->}
testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
Conf = require('../../../server/conf').Conf
WaveProcessor = require('../../../server/wave/processor').WaveProcessor
OtProcessor = require('../../../server/ot/processor').OtProcessor
UserCouchProcessor = require('../../../server/user/couch_processor').UserCouchProcessor
WaveGenerator = require('../../../server/wave/generator').WaveGenerator
WaveModel = require('../../../server/wave/models').WaveModel
CouchWaveProcessor = require('../../../server/wave/couch_processor').CouchWaveProcessor

module.exports =
    WaveProcessorTest: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testCreateWave: (test) ->
            id = 'wave_processor_test_wave_id'
            user = {id:'0_user_1'}
            blipId = 'b1'
            
            WaveGeneratorMock = sinon.mock(WaveGenerator)
            WaveGeneratorMock
                .expects('getNext')
                .once()
                .callsArgWith(0, null, id)

            CouchWaveProcessorMock = sinon.mock(CouchWaveProcessor)
            CouchWaveProcessorMock
                .expects('save')
                .once()
                .callsArgWith(1, null, id)

            WaveProcessor.createWave(null, user, 'blipId', {}, (err, waveId) =>
                test.equal(err, null)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getWaveOk: (test) ->
            user = 'user'
            waveId = '0_wave_1'
            wave = 'wave'
            CouchWaveProcessorMock = sinon.mock(CouchWaveProcessor)
            CouchWaveProcessorMock
                .expects('getById')
                .withArgs(waveId)
                .once()
                .callsArgWith(1, null, wave)
            
            WaveProcessor.getWave(waveId, (err) ->
                test.equal(null, err)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getWaveByUrlOk: (test) ->
            user = 'user'
            waveId = '0_wave_1'
            wave = 'wave'
            CouchWaveProcessorMock = sinon.mock(CouchWaveProcessor)
            CouchWaveProcessorMock
                .expects('getByUrl')
                .withArgs(waveId)
                .once()
                .callsArgWith(1, null, wave)

            WaveProcessor.getWaveByUrl(waveId, (err) ->
                test.equal(null, err)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testAddParticipant: (test) ->
            wave =
                hasParticipantWithRole: sinon.stub()
                getParticipantIndex: () ->
                getParticipantByIndex: () ->
                participants: [1, 2]
            wave.hasParticipantWithRole.returns(false)
            participant =
                id: 'participantId'
            WaveProcessorMock = sinon.mock(WaveProcessor)
            WaveProcessorMock
                .expects('_getParticipant')
                .withArgs('participantId')
                .once()
                .callsArgWith(1, null, participant)
            expCallback = (err, op) ->
                test.equal('op', op)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            _queueOtProcessorMock = sinon.mock(WaveProcessor._queueOtProcessor)
            _queueOtProcessorMock
                .expects('applyOp')
                .withArgs('waveId')
                .once()
                .callsArgWith(1, wave, expCallback)
            WaveProcessorMock
                .expects('_getOperation')
                .withArgs(wave)
                .once()
                .returns('op')
            WaveProcessor.addParticipant('waveId', 'user', 'participantId', expCallback)

        testDeleteParticipant: (test) ->
            wave =
                id: 'waveId'
                hasParticipantWithRole: sinon.stub()
                hasAnotherModerator: () ->
                    return true
                getParticipantIndex: () ->
                    return 'index'
                getParticipantByIndex: () ->
                participants: [1, 2]
            wave.hasParticipantWithRole.returns(false)
            participant =
                id: 'participantId'
            WaveProcessorMock = sinon.mock(WaveProcessor)
            expCallback = (err, op) ->
                test.equal('op', op)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            _queueOtProcessorMock = sinon.mock(WaveProcessor._queueOtProcessor)
            _queueOtProcessorMock
            .expects('applyOp')
            .withArgs('waveId')
            .once()
            .callsArgWith(1, wave, expCallback)
            WaveProcessorMock
            .expects('_getOperation')
            .withArgs(wave)
            .once()
            .returns('op')
            WaveProcessor.deleteParticipant(wave, 'user', 'participantId', expCallback)
