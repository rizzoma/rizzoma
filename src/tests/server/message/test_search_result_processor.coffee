testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
dataprovider = require('dataprovider')
MessageSearchResultProcessor = require('../../../server/message/search_result_processor').MessageSearchResultProcessor
BlipModel = require('../../../server/blip/models').BlipModel
CouchBlipProcessor = require('../../../server/blip/couch_processor').CouchBlipProcessor
MessageModel = require('../../../server/message/model').MessageModel
UserModel = require('../../../server/user/model').UserModel
UserCouchProcessor = require('../../../server/user/couch_processor').UserCouchProcessor

module.exports =
    MessageSearchResultProcessorTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testGetItem: (test) ->
            testCode = (done, changed, expected) ->
                res = MessageSearchResultProcessor._getItem({blip_id: 'foo', wave_url: 'bar'}, changed)
                test.deepEqual(res, expected)
                done()
            dataprovider(test, [
                [true, {blipId: 'foo', waveId: 'bar'}]
                [false, {blipId: 'foo', waveId: 'bar'}]
            ], testCode)

        testGetChangedItems: (test) ->
            blip = new BlipModel()
            blip.attach(MessageModel)
            blipCouchProcessorMock = sinon.mock(CouchBlipProcessor)
            blipCouchProcessorMock
                .expects('getByIdsAsDict')
                .withArgs('ids')
                .callsArgWith(1, null, {blipId: blip})
            blipMock = sinon.mock(blip)
            blipMock
                .expects('attach')
                .once()
            messageMock = sinon.mock(blip.message)
            messageMock
                .expects('getSenderId')
                .once()
                .returns('senderId')
            userCouchProcessorMock = sinon.mock(UserCouchProcessor)
            userCouchProcessorMock
                .expects('getByIdsAsDict')
                .once()
                .withArgs(['senderId'])
                .callsArgWith(1, null, 'senders')
            processorMock = sinon.mock(MessageSearchResultProcessor)
            processorMock
                .expects('_compileItems')
                .once()
                .withArgs({blipId: blip}, 'senders', 'recipient')
                .callsArgWith(3, null, 'foo')
            MessageSearchResultProcessor._getChangedItems('ids', 'recipient', (err, items) ->
                sinon.verifyAll()
                sinon.restoreAll()  
                test.equal(err, null)
                test.deepEqual(items, 'foo')
                test.done()
            )

        testComplileItems: (test)->
            blip = new BlipModel()
            blip.attach(MessageModel)
            blip.contentTimestamp = 608552093256
            sender = new UserModel()
            sender.name = 'name'
            sender.email = 'email'
            sender.avatar = 'avatar'
            messageMock = sinon.mock(blip.message)
            messageMock
                .expects('getSenderId')
                .once()
                .returns('senderId')
            blipMock = sinon.mock(blip)
            blipMock
                .expects('getTitle')
                .once()
                .returns('title')
            blipMock
                .expects('getSnippet')
                .once()
                .returns('snippet')
            messageMock
                .expects('getLastSentTimestamp')
                .once()
                .returns(undefined)
            blipMock
                .expects('getReadState')
                .once()
                .withArgs('recipient')
                .returns('someValue')
            blip = {blipId: blip}
            senders = {senderId: sender}
            MessageSearchResultProcessor._compileItems(blip, senders, 'recipient', (err, items) ->
                sinon.verifyAll()
                sinon.restoreAll()  
                test.equal(err, null)
                expected = 
                    blipId:
                        blipId: 'blipId'
                        title: 'title'
                        snippet: 'snippet'
                        lastSent: 608552093256
                        senderName: 'name'
                        senderEmail: 'email'
                        senderAvatar: 'avatar'
                        isRead: 'someValue'
                test.deepEqual(items, expected)
                test.done()
            )
