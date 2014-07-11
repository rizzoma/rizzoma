sinon = require('sinon')
testCase = require('nodeunit').testCase
Request = require('../../../share/communication').Request
dataprovider = require('dataprovider')

module.exports =
    WaveProcessorTest: testCase
        setUp: (callback) ->
            @wnd = global['window']
            @sharejs = global['sharejs']
            global['window'] = {}
            global['sharejs'] = {}
            @WaveProcessor = require('../../../client/wave/processor').WaveProcessor
            sinon.stub @WaveProcessor.prototype, '_init'
            callback()

        tearDown: (callback) ->
            global['window'] = @wnd
            global['sharejs'] = @sharejs
            @WaveProcessor.prototype._init.restore()
            callback()

        testCreateWave: (test) ->
            waveId = 'waveId'
            callback = ->
            request = new Request {}, callback
            router =
                handle: ->

            waveProcessor = new @WaveProcessor(router)
            mockWaveProcessor = sinon.mock waveProcessor
            mockWaveProcessor.expects('_createRequest').withExactArgs({}, callback).once().returns(request)
            routerMock = sinon.mock router
            routerMock.expects('handle').once().withExactArgs('network.wave.createWave', request)

            waveProcessor.createWave(callback)
            routerMock.verify()
            mockWaveProcessor.verify()
            mockWaveProcessor.restore()
            test.done()

        testOpenWave: (test) ->
            testCases = [
                [null],
                [->]
            ]
            testCode = (test, wrappedCallback) =>
                waveId = 'waveId'
                container = 'container'
                otCallback = 'otCallback'
                wrappedCallback = ->
                callback = ->
                router = handle: ->
                request = 'request'
                waveProcessor = new @WaveProcessor router
                waveProcessor._otProcessor = 
                    open: (waveId, otCallback) ->
                mockWaveProcessor = sinon.mock waveProcessor
                mockWaveProcessor.expects('_getOtCallback').withExactArgs(container, callback).once().returns(otCallback)
                mockOtProcessor = sinon.mock waveProcessor._otProcessor
                mockOtProcessor.expects('open').withExactArgs(waveId, otCallback).once().returns(wrappedCallback)
                if wrappedCallback
                    mockWaveProcessor.expects('_createRequest').withExactArgs({waveId: waveId}, wrappedCallback).once().returns(request)
                    mockRouter = sinon.mock router
                    mockRouter.expects('handle').once().withExactArgs('network.wave.getWave', request)
                waveProcessor.openWave(waveId, container, callback)
                mockWaveProcessor.verify()
                mockWaveProcessor.restore()
                mockOtProcessor.verify()
                mockOtProcessor.restore()
                if wrappedCallback            
                    mockRouter.verify()
                    mockRouter.restore()
                test()
            dataprovider(test, testCases, testCode)

        testCloseWave: (test) ->
            waveId = 'waveId'
            callback = ->
            request = new Request {}, callback
            router =
                handle: ->
            waveProcessor = new @WaveProcessor(router)
            mockWaveProcessor = sinon.mock waveProcessor
            mockWaveProcessor.expects('_createRequest').withExactArgs({waveId: waveId}, callback).once().returns(request)
            routerMock = sinon.mock router
            routerMock.expects('handle').once().withExactArgs('network.wave.closeWave', request)

            waveProcessor.closeWave(waveId, callback)
            routerMock.verify()
            routerMock.restore()
            mockWaveProcessor.verify()
            mockWaveProcessor.restore()
            test.done()

        testAddParticipant: (test) ->
            testCases = [
                [''],
                ['userId']
            ]
            testCode = (test, userId) =>
                waveId = 'waveId'
                callback = ->
                router =
                        handle: ->
                waveProcessor = new @WaveProcessor router
                if userId.length
                    request = new Request({waveId: waveId, participantId: userId}, callback)
                    mockWaveProcessor = sinon.mock waveProcessor
                    mockWaveProcessor.expects('_createRequest').withExactArgs({waveId: waveId, participantId: userId}, callback).once().returns(request)
                    routerMock = sinon.mock router
                    routerMock.expects('handle').once().withExactArgs('network.wave.addParticipantToWaveByParams', request)
                waveProcessor.addParticipant(waveId, userId, callback)

                if userId.length
                    routerMock.verify()
                    routerMock.restore()
                    mockWaveProcessor.verify()
                    mockWaveProcessor.restore()
                test()
            dataprovider(test, testCases, testCode)

        testRemoveParticipant: (test) ->
            waveId = 'waveId'
            callback = ->
            userId = 'userId'
            request = new Request({waveId: waveId, participantId: userId}, callback)
            router =
                handle: ->
            waveProcessor = new @WaveProcessor(router)
            mockWaveProcessor = sinon.mock waveProcessor
            mockWaveProcessor.expects('_createRequest').withExactArgs({waveId: waveId, participantId: userId}, callback).once().returns(request)
            routerMock = sinon.mock router
            routerMock.expects('handle').once().withExactArgs('network.wave.deleteParticipantFromWave', request)

            waveProcessor.removeParticipant(waveId, userId, callback)

            routerMock.verify()
            routerMock.restore()
            mockWaveProcessor.verify()
            mockWaveProcessor.restore()
            test.done()

        testGetUserInfo: (test) ->
            waveId = 'waveId'
            callback = ->
            userIds = ['userId1', 'userId1']
            request = new Request({participantIds: userIds}, callback)
            router =
                handle: ->
            waveProcessor = new @WaveProcessor(router)
            mockWaveProcessor = sinon.mock waveProcessor
            mockWaveProcessor.expects('_createRequest').withExactArgs({participantIds: userIds}, callback).once().returns(request)
            routerMock = sinon.mock router
            routerMock.expects('handle').once().withExactArgs('network.wave.getUsersInfo', request)

            waveProcessor.getUserInfo(userIds, callback)

            routerMock.verify()
            routerMock.restore()
            mockWaveProcessor.verify()
            mockWaveProcessor.restore()
            test.done()
