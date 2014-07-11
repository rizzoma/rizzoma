sinon = require('sinon')
testCase = require('nodeunit').testCase

module.exports =
    WaveViewModelTest: testCase
        setUp: (callback) ->
            @wnd = global['window']
            @sharejs = global['sharejs']
            global['window'] = {}
            global['sharejs'] = {}
            View = require('../../../client/wave/view').WaveView
            @waveViewProtoMock = sinon.mock View.prototype
            Model = require('../../../client/wave/model').WaveModel
            @waveModelProtoMock = sinon.mock Model.prototype
            @ViewModel = require('../../../client/wave').WaveViewModel
            @waveData =
                snapshot:
                    participants: ['одын', 'дыва']
                on: ->
            @container = 'container'
            @parentWave = 'parentWave'
            @waveProcessor = 'waveProcessor'

            @waveModelInitExp = @waveModelProtoMock.expects('_init').once()
            @waveViewInitExp = @waveViewProtoMock.expects('_init').once()
            callback()

        tearDown: (callback) ->
            @waveModelProtoMock.verify()
            @waveViewProtoMock.verify()
            global['window'] = @wnd
            global['sharejs'] = @sharejs
            @waveModelProtoMock.restore()
            @waveViewProtoMock.restore()
            callback()

        testInit: (test) ->
            waveDataMock = sinon.mock @waveData
            waveDataExp = waveDataMock.expects('on').once()
            @waveModelInitExp.withExactArgs @waveData
            
            waveViewModel = new @ViewModel @waveProcessor, @waveData, @container
            test.equal waveDataExp.args[0][0], 'remoteop'
            test.equal waveDataExp.args[0][1], waveViewModel._processRemoteOps
            waveViewArgs = @waveViewInitExp.args[0]
            test.equal waveViewArgs[0], @waveProcessor
            test.equal waveViewArgs[1], waveViewModel._waveModel
            test.equal waveViewArgs[2], @waveData.snapshot.participants
            test.equal waveViewArgs[3], @container
            waveDataMock.verify()
            waveDataMock.restore()
            test.done()
        
        testProcessRemoteOps: (test) ->
            waveViewModel = new @ViewModel @waveProcessor, @waveData, @container
            waveViewMock = sinon.mock waveViewModel._waveView
            waveViewMock
                .expects('applyParticipantOp')
                .exactly(4)
            ops = [
                {p: ['content', 1], test0: 1},
                {p: ['content', 'test', 2]},
                {p: ['content'], test: {}},
                {p: ['content']},
                {p: ['participants']},
                {p: ['participants']},
                {p: ['participants']},
                {p: ['participants']}
            ]
            waveViewModel._processRemoteOps ops
            waveViewMock.verify()
            waveViewMock.restore()
            test.done()