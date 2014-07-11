global.getLogger = () ->
    return {error: ->}
sinon = require('sinon-plus')
testCase = require('nodeunit').testCase
WaveModule = require('../../../server/wave/module').WaveModule
WaveProcessor = require('../../../server/wave/processor').WaveProcessor
WaveController = require('../../../server/wave/controller').WaveController
BlipProcessor = require('../../../server/blip/processor').BlipProcessor
BlipController = require('../../../server/blip/controller').BlipController
UserCouchProcessor = require('../../../server/user/couch_processor').UserCouchProcessor
UserController = require('../../../server/user/controller').UserController
WaveError = require('../../../server/wave/exceptions').WaveError
Response = require('../../../server/common/communication').ServerResponse

module.exports =
    WaveModuleTest: testCase

        setUp: (callback) ->
            @_wave = new WaveModule()
            @_wave._waveListeners = []
            @_wave._blipListeners = []
            callback()

        tearDown: (callback) ->
            callback()

        testCreateWave: (test) ->
            request =
                user: 'user'
            WaveControllerMock = sinon.mock(WaveController)
            WaveControllerMock
                .expects('createWave')
                .withArgs('user')
                .once()
                .callsArgWith(1, null, 'ok')
            @_wave.createWave(request, {}, (err, res) ->
                test.equal('ok', res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        createWaveWithEveryoneHere: (test) ->
            request =
                user: 'user'
            args =
                waveId: 'waveId'
            WaveControllerMock = sinon.mock(WaveController)
            WaveControllerMock
                .expects('createWaveWithEveryoneHere')
                .withArgs('waveId', 'user')
                .once()
                .callsArgWith(2, null, 'ok')
            @_wave.createWaveWithEveryoneHere(request, args, (err, res) ->
                test.equal('ok', res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        getWaveWithBlips: (test) ->
            request =
                user: 'user'
                session: 'session'
            args =
                waveId: 'waveId'
            data =
                wave:
                    otClientConverter:
                        toClient: sinon.stub()
                blips: [{
                    otClientConverter:
                        toClient: sinon.stub()
                }]
            data.wave.otClientConverter.toClient.returns('waveOtDoc')
            data.blips[0].otClientConverter.toClient.returns('blipOtDoc')
            exp =
                wave: 'waveOtDoc'
                blips: ['blipOtDoc']
            WaveControllerMock = sinon.mock(WaveController)
            WaveControllerMock
                .expects('getWaveWithBlipsByUrl')
                .withArgs('waveId', request.user)
                .once()
                .callsArgWith(2, null, data)
            @_wave.getWaveWithBlips(request, args, (err, data) ->
                test.equal(null, err)
                test.deepEqual(exp, data)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        subscribeWaveWithBlips: (test) ->
            request =
                user: 'user'
                session: 'session'
                callId: 'callId'
            args =
                waveId: 'waveId'
                versions: 'versions'
            WaveControllerMock = sinon.mock(WaveController)
            WaveControllerMock
                .expects('subscribeWaveWithBlips')
                .withArgs('versions', 'user', "#{request.session}#{request.callId}")
                .once()
                .callsArgWith(4, 'err', null)
            @_wave.subscribeWaveWithBlips(request, args, (err, res) ->
                test.equal('err',err)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testCloseWave: (test) ->
            request = 
                args:
                    waveId: 'waveId'
                user: 'user'
                session: 'session'
                callback: (response) ->
                    test.equal(null, response.err)
                    WaveProcessorMock.verify()
                    WaveProcessorMock.restore()
                    test.done()
                
            WaveProcessorMock = sinon.mock(@_wave._WaveProcessor)
            WaveProcessorMock
                .expects('closeWave')
                .withArgs('waveId', request.user, request.session)
                .once()
                .callsArgWith(3, null, 'ok')
            
            @_wave.closeWave(request)

        testCreateBlip: (test) ->
            request = 
                args:
                    waveId: 'waveId'
                user: 'user'
                session: 'session'
                callback: (response) ->
                    test.equal(null, response.err)
                    BlipProcessorMock.verify()
                    BlipProcessorMock.restore()
                    test.done()
                
            BlipProcessorMock = sinon.mock(@_wave._BlipProcessor)
            BlipProcessorMock
                .expects('createBlip')
                .withArgs('waveId', request.user, no)
                .once()
                .callsArgWith(3, null, 'ok')
            
            @_wave.createBlip(request)
        
        testCloseBlip: (test) ->
            request = 
                args:
                    blipId: 'blipId'
                user: 'user'
                session: 'session'
                callback: (response) ->
                    test.equal(null, response.err)
                    BlipProcessorMock.verify()
                    BlipProcessorMock.restore()
                    test.done()
                
            BlipProcessorMock = sinon.mock(@_wave._BlipProcessor)
            BlipProcessorMock
                .expects('closeBlip')
                .withArgs('blipId', request.session)
                .once()
                .callsArgWith(2, null, 'ok')
            
            @_wave.closeBlip(request)

        testGetBlip: (test) ->
            request = 
                args:
                    blipId: 'blipId'
                user: 'user'
                session: 'session'
                callback: (response) ->
                    test.equal(null, response.err)
                    test.equal('otDoc', response.data)
                    BlipProcessorMock.verify()
                    BlipProcessorMock.restore()
                    BlipClientOtConverterMock.verify()
                    BlipClientOtConverterMock.restore()
                    test.done()
                
            BlipProcessorMock = sinon.mock(@_wave._BlipProcessor)
            BlipProcessorMock
                .expects('getBlip')
                .withArgs('blipId', request.user)
                .once()
                .callsArgWith(2, null, 'model')
                
            BlipClientOtConverterMock = sinon.mock(BlipClientOtConverter)
            BlipClientOtConverterMock
                .expects('fromModelToClientOt')
                .withArgs('model')
                .once()
                .returns('otDoc')

            @_wave.getBlip(request)
        
        testSubscribeBlip: (test) ->
            request = 
                args:
                    blipId: 'blipId'
                    version: 'version'
                user: 'user'
                session: 'session'
                callback: (response) ->
                
            BlipProcessorMock = sinon.mock(@_wave._BlipProcessor)
            BlipProcessorMock
                .expects('subscribeBlip')
                .withArgs('blipId', 'version', request.session)
                .once()
                .callsArgWith(4, null, 'model')
            
            @_wave.subscribeBlip(request)
            
            BlipProcessorMock.verify()
            BlipProcessorMock.restore()
            test.done()

        testAddParticipantToWaveByParamsCreateUserThenNotFound: (test) ->
            request = 
                args:
                    waveId: 'waveId'
                    participantId: 'participantId'
                user: 'user'
                session: 'session'
                callback: (response) ->
                    test.equal(null, response.err)
                    test.equal('added_user', response.data)
                    UserProcessorMock.verify()
                    UserProcessorMock.restore()
                    WaveModuleMock.verify()
                    WaveModuleMock.restore()
                    test.done()
                
            UserProcessorMock = sinon.mock(UserProcessor)
            UserProcessorMock
                .expects('loadUserByEmail')
                .withArgs('participantId')
                .once()
                .callsArgWith(1, { error: 'not_found'})
            UserProcessorMock
                .expects('createUserByEmail')
                .withArgs('participantId')
                .once()
                .callsArgWith(1, null, 'added_user')
            WaveModuleMock = sinon.mock(@_wave)
            WaveModuleMock
                .expects('_addParticipantToWaveById')
                .withArgs('waveId', request.user, 'added_user')
                .once()
                .callsArgWith(3, new Response(null, 'added_user'))
            
            @_wave.addParticipantToWaveByParams(request)
        
        testAddParticipantToWaveByParamsCreateUserThenFound: (test) ->
            request = 
                args:
                    waveId: 'waveId'
                    participantId: 'participantId'
                user: 'user'
                session: 'session'
                callback: (response) ->
                    test.equal(null, response.err)
                    test.equal('added_user', response.data)
                    UserProcessorMock.verify()
                    UserProcessorMock.restore()
                    WaveModuleMock.verify()
                    WaveModuleMock.restore()
                    test.done()
                
            UserProcessorMock = sinon.mock(UserProcessor)
            UserProcessorMock
                .expects('loadUserByEmail')
                .withArgs('participantId')
                .once()
                .callsArgWith(1, null, 'added_user')
            WaveModuleMock = sinon.mock(@_wave)
            WaveModuleMock
                .expects('_addParticipantToWaveById')
                .withArgs('waveId', request.user, 'added_user')
                .once()
                .callsArgWith(3, new Response(null, 'added_user'))
            
            @_wave.addParticipantToWaveByParams(request)
