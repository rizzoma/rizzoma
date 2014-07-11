sinon = require('sinon')
testCase = require('nodeunit').testCase
Request = require('../../../share/communication').Request

module.exports =
    BlipProcessorTest: testCase
        setUp: (callback) ->
            @wnd = global['window']
            @sharejs = global['sharejs']
            @router = handle: ->
            global['window'] = {}
            global['sharejs'] = {types: {json: 'json'}, Document: 'doc'}
            global['jQuery'] = {fn: {}}
            @BlipProcessor = new require('../../../client/blip/processor').BlipProcessor
            sinon.stub @BlipProcessor.prototype, '_init'
            callback()

        tearDown: (callback) ->
            global['window'] = @wnd
            global['sharejs'] = @sharejs
            @BlipProcessor.prototype._init.restore()
            callback()

        testCreateBlip: (test) ->
            waveId = 'waveId'
            callback = ->
            request = new Request {waveId: 'waveId'}, callback
            routerMock = sinon.mock @router
            routerMock
                .expects('handle')
                .once()
                .withExactArgs('network.wave.createBlip', request)
            blipProcessor = new @BlipProcessor @router
            blipProcessor.createBlip waveId, callback
            routerMock.verify()
            routerMock.restore()
            test.done()

        testOpenBlip: (test) ->
            blipId = 'blipId'
            container = 'container'
            parentBlip = 'parentBlip'
            callback = ->
            request = new Request {blipId: blipId}, true
            routerMock = sinon.mock @router
            routerMock
                .expects('handle')
                .once()
                .withExactArgs('network.wave.getBlip', request)
            blipProcessor = new @BlipProcessor @router
            mockBlipProcessor = sinon.mock blipProcessor
            mockBlipProcessor
                .expects('_openBlipCallback')
                .once()
                .withExactArgs(container, parentBlip, callback)
                .returns('callback')
            blipProcessor._otProcessor = open: ->
            openMock = sinon.mock blipProcessor._otProcessor
            openMock
                .expects('open')
                .once()
                .withArgs(blipId, 'callback')
                .returns(true)
            blipProcessor.openBlip blipId, container, parentBlip, callback
            mockBlipProcessor.verify()
            mockBlipProcessor.restore()
            routerMock.verify()
            routerMock.restore()
            openMock.verify()
            openMock.restore()
            test.done()


        testCloseBlip: (test) ->
            blipId = 'blipId'
            callback = ->
            request = new Request {blipId: blipId}, callback
            routerMock = sinon.mock @router
            routerMock
                .expects('handle')
                .once()
                .withExactArgs('network.wave.closeBlip', request)
            blipProcessor = new @BlipProcessor @router
            blipProcessor.closeBlip blipId, callback
            routerMock.verify()
            routerMock.restore()
            test.done()
