global.getLogger = () ->
    return {
        error: () ->
        debug: () ->
    }

sinon = require('sinon')
testCase = require('nodeunit').testCase
MessageProcessor = require('../../../server/message/controller').MessageProcessor
BlipController = require('../../../server/blip/controller').BlipController
BlipModel = require('../../../server/blip/models').BlipModel
MessageModel = require('../../../server/message/model').MessageModel
UserProcessor = require('../../../server/user/processor').UserProcessor
Notificator = require('../../../server/notification').Notificator
OtProcessor = require('../../../server/ot/processor').OtProcessor

getBlip = (message) ->
    blip = new BlipModel()
    blip.message = message
    return blip

module.exports =
    BlipModelTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetBlip: (test) ->
            blip = new BlipModel()
            blipMock = sinon.spy(blip, 'attach')
            controller = sinon.mock(BlipController)
            controller
                .expects('getBlip')
                .once()
                .withArgs('foo', 'bar')
                .callsArgWith(2, null, blip)
            MessageProcessor._getBlip('foo', 'bar', (err, blip) ->
                test.equal(null, err)
                test.ok(blip.message?)
                test.ok(blipMock.calledOnce)
                controller.verify()
                controller.restore()
                test.done()
            )

        testGetSender: (test) ->
            message = new MessageModel()
            messageMock = sinon.mock(message)
            messageMock
                .expects('getSenderId')
                .once()
                .returns('foo')
            blip = getBlip(message)
            blipMock = sinon.mock(blip)
            blipMock
                .expects('checkPermission')
                .once().withArgs('bar')
                .returns(null)
            processor = sinon.mock(UserProcessor)
            processor
                .expects('loadUserById')
                .once().withArgs('foo')
                .callsArgWith(1, null, 'bar')
            MessageProcessor._getSender(blip, (err, sender) ->
                test.equal(null, err)
                test.equal('bar', sender)
                messageMock.verify()
                blipMock.verify()
                blipMock.restore()
                processor.verify()
                processor.restore()
                test.done()
            )

        testGetRecipients: (test) ->
            message = new MessageModel()
            messageMock = sinon.mock(message)
            messageMock
                .expects('getRecipientIds')
                .once()
                .returns('foo')
            blip = getBlip(message)
            userProcessor = sinon.mock(UserProcessor)
            userProcessor
                .expects('loadUsersByIds')
                .once().withArgs('foo')
                .callsArgWith(1, null, 'bar')
            messageProcessor = sinon.mock(MessageProcessor)
            messageProcessor
                .expects('_getPermittedRecipients')
                .withArgs(blip, 'bar')
                .returns(['baz1', 'baz2'])
            MessageProcessor._getRecipients(blip, (err, recepients, states) ->
                test.equal(null, err)
                test.equal('baz1', recepients)
                test.equal('baz2', states)
                messageMock.verify()
                userProcessor.verify()
                userProcessor.restore()
                messageProcessor.verify()
                messageProcessor.restore()
                test.done()
            )

        testSendNotifications: (test) ->
            message = new MessageModel()
            messageMock = sinon.mock(message)
            messageMock
                .expects('getMessageContext')
                .once().withArgs('foo')
                .returns('context')
            blip = getBlip(message)
            notificator = sinon.mock(Notificator)
            notificator
                .expects('notificateUsers')
                .once().withArgs('bar', 'message', 'context', 'callback')
            MessageProcessor._sendNotifications(blip, 'foo', 'bar', 'callback')
            messageMock.verify()
            notificator.verify()
            notificator.restore()
            test.done()

        updateSentTimestamp: (test) ->
            message = new MessageModel()
            messageMock = sinon.mock(message)
            messageMock
                .expects('generatePluginDataOp')
                .once().withArgs('foo')
                .returns('op')
            blip = getBlip(message)
            blip.id = 'some_id'
            blip.version = 'some_version'
            processor = sinon.mock(OtProcessor)
            processor
                .expects('postOp')
                .once().withArgs('some_id', 'some_version', null, 'op', null, 'callback')
            MessageProcessor._updateSentTimestamp(blip, 'foo', 'callback')
            messageMock.verify()
            processor.verify()
            processor.restore()
            test.done()
