global.getLogger = () ->
    return {error: ->}
testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
Conf = require('../../../server/conf').Conf
CouchBlipProcessor = require('../../../server/blip/couch_processor').CouchBlipProcessor
BlipProcessor = require('../../../server/blip/processor').BlipProcessor
OtProcessor = require('../../../server/ot/processor').OtProcessor
BlipGenerator = require('../../../server/blip/generator').BlipGenerator
dataprovider = require('dataprovider')

module.exports =
    BlipProcessorTest: testCase

        setUp: (callback) ->
            @_db = Conf.getDb('main')
            callback()

        tearDown: (callback) ->
            callback()

        testCreateBlip: (test) ->
            id = 'blip_processor_test_blip_id'
            BlipGeneratorMock = sinon.mock(BlipGenerator)
            BlipGeneratorMock
                .expects('getNext')
                .withArgs('foo')
                .once()
                .callsArgWith(1, null, id)
            CouchBlipProcessorMock = sinon.mock(CouchBlipProcessor)
            CouchBlipProcessorMock
                .expects('save')
                .once()
                .callsArgWith(1, null)
            BlipProcessor.createBlip('foo', {id: 'some_id', isAnonymous: () -> return false }, 'bar', (err, blipId) =>
                test.equal(id, blipId)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        testGetBlip: (test) ->
            blipId = '0_blip_1'
            expBlip = 'blip'
            CouchBlipProcessorMock = sinon.mock(CouchBlipProcessor)
            CouchBlipProcessorMock
                .expects('getById')
                .withArgs(blipId)
                .once()
                .callsArgWith(1, null, expBlip)
            BlipProcessor.getBlip(blipId, (err, blip) ->
                test.equal(null, err)
                test.equal(expBlip, blip)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_addContributorBlipWithExistingContributor: (test) ->
            contributor =
                id: 'foo'
            blip=
                id: 'blipId'
                hasContributor: sinon.stub()
            blip.hasContributor.withArgs(contributor.id).returns(true)
            expCallback = (err, res) ->
                test.equal(null, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            _queueOtProcessorMock = sinon.mock(BlipProcessor._queueOtProcessor)
            _queueOtProcessorMock
                .expects('applyOp')
                .withArgs('blipId')
                .once()
                .callsArgWith(1, blip, expCallback)
            BlipProcessor._addContributorBlip('blipId', contributor, expCallback)

        testAddContributorToOpAddsOp: (test) ->
            contributor =
                id: 'foo'
            blip=
                id: 'blipId'
                hasContributor: sinon.stub()
                contributors: [1, 2]
                version: 3
            blip.hasContributor.withArgs('foo').returns(false)
            expCallback = (err, res) ->
                test.deepEqual(['op', {p: ['contributors', 2], li: {id: 'foo'}}], res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            _queueOtProcessorMock = sinon.mock(BlipProcessor._queueOtProcessor)
            _queueOtProcessorMock
                .expects('applyOp')
                .withArgs('blipId')
                .once()
                .callsArgWith(1, blip, expCallback)
            BlipProcessorMock = sinon.mock(BlipProcessor)
            BlipProcessorMock
                .expects('_getOperation')
                .withArgs('blipId', contributor, {p: ['contributors', 2], li: {id: 'foo'}}, 3)
                .once()
                .returns(['op', {p: ['contributors', 2], li: {id: 'foo'}}])
            BlipProcessor._addContributorBlip('blipId', contributor, expCallback)


        testPostOp: (test) ->
            blip =
                id: 'blipId'
            BlipProcessorMock = sinon.mock(BlipProcessor)
            BlipProcessorMock
                .expects('_getOperation')
                .withArgs('blipId', 'contributor', 'op', 'version', 'listenerId')
                .once()
                .returns('opa')
            _queueOtProcessorMock = sinon.mock(BlipProcessor._queueOtProcessor)
            _queueOtProcessorMock
                .expects('applyOp')
                .withArgs('blipId', 'opa')
                .once()
                .callsArgWith(2, null, 'blip')
            BlipProcessorMock
                .expects('_processOpsRemovedFlag')
                .withArgs(blip, 'op')
                .once()
                .callsArgWith(2, null)
            BlipProcessor.postOp(blip, 'contributor', 'op', 'version', 'listenerId', (err, result) ->
                setTimeout(() ->
                    test.equal(err, null)
                    test.equal(result, 'blip')
                    sinon.verifyAll()
                    sinon.restoreAll()
                    test.done()
                , 500)
            )

        testUpdateBlipReader: (test) ->
            blip =
                id: '0_blip_7'
                markAsRead: (user_id) ->
            reader =
                id: '0_user_xz'
                isLoggedIn: sinon.stub()
            reader.isLoggedIn.returns(true)
            CouchBlipProcessorMock = sinon.mock(CouchBlipProcessor)
            CouchBlipProcessorMock
                .expects('saveResolvingConflicts')
                .withArgs(blip)
                .callsArgWith(3, null, 'rev')
            BlipProcessor.updateBlipReader(blip, reader, (err) ->
                test.equal(null, err)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_processOpsRemovedFlagDoNothing: (test) ->
            blip =
                waveId = '0_w_xz'
            BlipProcessorMock = sinon.mock(BlipProcessor)
            BlipProcessorMock
                .expects('_getSummaryBlipOps')
                .withExactArgs('ops')
                .once()
                .returns({})
            BlipProcessor._processOpsRemovedFlag(blip, 'ops', (err, res) ->
                test.equal(null, err)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_processOpsRemovedFlag: (test) ->
            blip =
                waveId: '0_w_xz'
            BlipProcessorMock = sinon.mock(BlipProcessor)
            BlipProcessorMock
                .expects('_getSummaryBlipOps')
                .withExactArgs('ops')
                .once()
                .returns({ '0_b_1': true, '0_b_2': false })
            BlipProcessorMock
                .expects('_processBlipRemovedFlag')
                .withArgs('0_b_1', '0_w_xz', true)
                .once()
                .callsArgWith(3, null, 'revs')
            BlipProcessorMock
                .expects('_processBlipRemovedFlag')
                .withArgs('0_b_2', '0_w_xz', false)
                .once()
                .callsArgWith(3, null, 'revs')
            BlipProcessor._processOpsRemovedFlag(blip, 'ops', (err, res) ->
                test.equal(null, err)
                test.deepEqual(['revs', 'revs'], res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getSummaryBlipOps: (test) ->
            code = (done, exp, ops) ->
                res = BlipProcessor._getSummaryBlipOps(ops)
                test.deepEqual(exp, res)
                done()
            dataprovider(test, [
                [ {}, [{ti: {}, params: {}},{ti: {}, params: {}}] ]
                [ {'1':false, '2':true}, [{ti: {}, params: {__TYPE:'BLIP', __ID: '1'}},{td: {}, params: {__TYPE:'BLIP', __ID: '2'}}] ]
                [
                    {},
                    [
                        {ti: {}, params: {__TYPE:'BLIP', __ID: '1'}},
                        {td: {}, params: {__TYPE:'BLIP', __ID: '1'}}
                    ]
                ]
                [
                    {'1': false},
                    [
                        {ti: {}, params: {__TYPE:'BLIP', __ID: '1'}},
                        {td: {}, params: {__TYPE:'BLIP', __ID: '1'}},
                        {ti: {}, params: {__TYPE:'BLIP', __ID: '1'}}
                    ]
                ]
                [
                    {'1': true},
                    [
                        {td: {}, params: {__TYPE:'BLIP', __ID: '1'}},
                        {ti: {}, params: {__TYPE:'BLIP', __ID: '1'}},
                        {td: {}, params: {__TYPE:'BLIP', __ID: '1'}}
                    ]
                ]
            ], code)

        test_processBlipRemovedFlag: (test) ->
            blipId = 'b1'
            waveId = 'w1'
            removed = true
            blipWithChilds = [{}, {}]
            CouchBlipProcessorMock = sinon.mock(CouchBlipProcessor)
            CouchBlipProcessorMock
                .expects('getWithChildsById')
                .withArgs(blipId, waveId, !removed)
                .once()
                .callsArgWith(3, null, blipWithChilds)
            CouchBlipProcessorMock
                .expects('bulkSave')
                .withArgs(blipWithChilds)
                .once()
                .callsArgWith(1, null, 'ok')
            BlipProcessor._processBlipRemovedFlag(blipId, waveId, removed, (err, res) ->
                test.equal(null, err)
                test.equal('ok', res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )


