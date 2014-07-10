sinon = require('sinon')
testCase = require('nodeunit').testCase
dataprovider = require('dataprovider')
BlipModel = require('../../../server/blip/models').BlipModel
MessageModel = require('../../../server/message/model').MessageModel
DateUtils = require('../../../server/utils/date_utils').DateUtils

getMessage = (blip) ->
    return new MessageModel(blip)

module.exports =
    MessageModelTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetSenderId: (test) ->
            message = getMessage({contributors: [{id: 'foo'}, {id: 'foo'}]})
            test.equal('foo', message.getSenderId())
            test.done()

        testGetRecipientIds: (test) ->
            blip = new BlipModel()
            blipMock = sinon.mock(blip)
            blipMock
                .expects('getNodesAttrByName')
                .once()
                .returns('foo')
            message = getMessage(blip)
            test.equal('foo', message.getRecipientIds())
            blipMock.verify()
            test.done()

        testGeneratePluginDataOp: (test) ->
            code = (done, pluginData, expected) ->    
                message = getMessage()
                messageMock = sinon.mock(message)
                messageMock
                    .expects('_getPluginPath')
                    .returns('foo')
                messageMock
                    .expects('_getPluginData')
                    .returns(pluginData)
                dateutils = sinon.mock(DateUtils)
                dateutils
                    .expects('getCurrentTimestamp')
                    .returns('time')
                result = message.generatePluginDataOp({id: 'some_id'})
                test.deepEqual(expected, result)
                messageMock.verify()
                dateutils.verify()
                messageMock.restore()
                dateutils.restore()
                test.done()
            dataprovider(test, [
                [
                    'bar'
                    [{p: 'foo', oi: {lastSent: 'time', lastSenderId: 'some_id'}, od: 'bar'}]
                ]
                [
                    null
                    [{p: 'foo', oi: {lastSent: 'time', lastSenderId: 'some_id'}}]
                ]
            ], code)
