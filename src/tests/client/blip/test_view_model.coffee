sinon = require('sinon')
testCase = require('nodeunit').testCase

module.exports =
    BlipViewModelTest: testCase
        setUp: (callback) ->
            @wnd = global['window']
            @sharejs = global['sharejs']
            global['window'] = {}
            global['sharejs'] = {types: {json: 'json'}, Document: 'doc'}
            global['jQuery'] = {fn: {}}
            View = require('../../../client/blip/view').BlipView
            @blipViewProtoMock = sinon.mock View.prototype
            Model = require('../../../client/blip/model').BlipModel
            @blipModelProtoMock = sinon.mock Model.prototype
            @ViewModel = require('../../../client/blip').BlipViewModel
            @blipData =
                snapshot:
                    content: ''
                    contributors: []
                    timestamp: 0
                on: ->
            @container = 'container'
            @parentBlip = 'parentBlip'
            @blipProcessor = 'blipProcessor'

            @blipModelInitExp = @blipModelProtoMock
                .expects('_init')
                .once()
            @blipViewInitExp = @blipViewProtoMock
                .expects('_init')
                .once()
            callback()

        tearDown: (callback) ->
            @blipModelProtoMock.verify()
            @blipViewProtoMock.verify()
            global['window'] = @wnd
            global['sharejs'] = @sharejs
            @blipModelProtoMock.restore()
            @blipViewProtoMock.restore()
            callback()

        testInit: (test) ->
            blipDataMock = sinon.mock @blipData
            blipDataExp = blipDataMock
                .expects('on')
                .once()
            @blipModelInitExp
                .withExactArgs @blipData
            blipViewModel = new @ViewModel @blipProcessor, @blipData, @container, @parentBlip
            test.equal blipDataExp.args[0][0], 'remoteop'
            test.equal blipDataExp.args[0][1], blipViewModel._processRemoteChanges
            blipViewArgs = @blipViewInitExp.args[0]
            test.equal blipViewArgs[0], @blipProcessor
            test.equal blipViewArgs[1], blipViewModel._blipModel
            test.equal blipViewArgs[2], @blipData.snapshot.content
            test.equal blipViewArgs[3], @blipData.snapshot.contributors
            test.equal blipViewArgs[4], @blipData.snapshot.timestamp
            test.equal blipViewArgs[5], @container
            test.equal blipViewArgs[6], @parentBlip
            blipDataMock.verify()
            blipDataMock.restore()
            test.done()

        testProcessRemoteChanges: (test) ->
            blipViewModel = new @ViewModel @blipProcessor, @blipData, @container, @parentBlip
            blipViewMock = sinon.mock blipViewModel._blipView
            blipViewMock
                .expects('applyParticipantOp')
                .exactly(4)
            applyOpsExp = blipViewMock
                .expects('applyOps')
                .once()
                .withArgs([{p: [1], test0: 1}, {p: ['test', 2]}, {p: [], test: {}}, {p: []}])
            ops = [
                {p: ['content', 1], test0: 1},
                {p: ['content', 'test', 2]},
                {p: ['content'], test: {}},
                {p: ['content']},
                {p: ['contributors']},
                {p: ['contributors']},
                {p: ['contributors']},
                {p: ['contributors']}
            ]
            blipViewModel._processRemoteChanges ops
            blipViewMock.verify()
            blipViewMock.restore()
            test.done()

        testGetView: (test) ->
            blipViewModel = new @ViewModel @blipProcessor, @blipData, @container, @parentBlip
            test.equal blipViewModel._blipView, blipViewModel.getView()
            test.done()
