sinon = require('sinon')
testCase = require('nodeunit').testCase
Request = require('../../../share/communication').Request
BlipModel = require('../../../client/blip/model').BlipModel

module.exports =
    BlipModelTest: testCase
        setUp: (callback) ->
            @blipData =
                name: 'name'
                snapshot:
                    waveId: 'waveId'
                submitOp: ->
            callback()

        tearDown: (callback) ->
            callback()

        testInit: (test) ->
            blipModel = new BlipModel @blipData
            test.equal blipModel.id, @blipData.name
            test.equal blipModel.waveId, @blipData.snapshot.waveId
            test.equal blipModel._doc, @blipData
            test.done()

        testSubmitOps: (test) ->
            blipModel = new BlipModel @blipData
            ops = [
                {p: [0], x: 'x'},
                {p: [1], y: 1},
                {p: ['2'], z: 'z'},
                {p: [3], a: {a: 'a'}},
                {p: [4], b: {b: {c: {d: 'd'}}}}
            ]
            blipDataMock = sinon.mock @blipData
            blipDataMock
                .expects('submitOp')
                .withArgs([
                    {p: ['content', 0], x: 'x'},
                    {p: ['content', 1], y: 1},
                    {p: ['content', '2'], z: 'z'},
                    {p: ['content', 3], a: {a: 'a'}},
                    {p: ['content', 4], b: {b: {c: {d: 'd'}}}}
                ])
            blipModel.submitOps(ops)
            blipDataMock.verify()
            blipDataMock.restore()
            test.done()
