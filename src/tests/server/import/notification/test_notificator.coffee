global.getLogger = () ->
    return {
        error: ->
        log: ->
    }
sinon = require('sinon-plus')
testCase = require('nodeunit').testCase
dataprovider = require('dataprovider')
Conf = require('../../../../server/conf').Conf
ImportSourceParser = require('../../../../server/import/source_parser').ImportSourceParser
UserCouchProcessor = require('../../../../server/user/couch_processor').UserCouchProcessor
#CouchImportProcessor = require('../../../../server/import/couch_processor').CouchImportProcessor
ImportNotificator = require('../../../../server/import/notification').ImportNotificator
CouchImportNotificationProcessor = require('../../../../server/import/notification/couch_processor').CouchImportNotificationProcessor


module.exports =
    ImportSourceParserTest: testCase
        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()

        testNotificate: (test) ->
            emails = ['ya@Mbilo.com']
            source = 'source'
            ImportNotificator._smtp = {}
            ImportNotificatorMock = sinon.mock(ImportNotificator)
            ImportNotificatorMock
                .expects('_getEmailsToSendNotification')
                .withArgs(emails)
                .once()
                .callsArgWith(1, null, emails)
            ImportNotificatorMock
                .expects('_notificateEmails')
                .withArgs(emails, source)
                .once()
                .callsArgWith(2, null, 'ok')
            ImportNotificator.notificate(emails, source, (err, res) ->
                test.equal('ok', res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_getEmailsToSendNotification: (test) ->
            code = (done, exp, emails, loadedEmails) ->
                CouchImportNotificationProcessorMock = sinon.mock(CouchImportNotificationProcessor)
                CouchImportNotificationProcessorMock
                    .expects('getByIdsAsDict')
                    .withArgs(emails)
                    .once()
                    .callsArgWith(1, null, loadedEmails)
                ImportNotificator._getEmailsToSendNotification(emails, (err, toSend) ->
                    test.deepEqual(exp, toSend)
                    sinon.verifyAll()
                    sinon.restoreAll()
                    done()
                )
            dataprovider(test, [
                [['non@exist.email'], ['non@exist.email'], {'ya@exist.email':'ya@exist.email'}]
                [[], ['ya@exist.email'], {'ya@exist.email':'ya@exist.email'}]
            ], code)

        test_getNotificationContext: (test) ->
            source =
                userId: '0_u_1'
                importedWaveUrl: 'sasadfcsaddfghghn345dcv'
                sourceData: 'sourceData'
            exp = 
                user: 'user'
                waveLink: Conf.get('baseUrl') + "/wave/sasadfcsaddfghghn345dcv/?utm_source=email&utm_medium=body&utm_campaign=exportwave"
                waveTitle: "waveTitle"
            UserProcessorMock = sinon.mock(UserCouchProcessor)
            UserProcessorMock
                .expects('getById')
                .withArgs(source.userId)
                .once()
                .callsArgWith(1, null, 'user')
            ImportSourceParserMock = sinon.mock(ImportSourceParser)
            ImportSourceParserMock
                .expects('getWaveTitle')
                .withExactArgs('sourceData')
                .once()
                .returns('waveTitle')
            ImportNotificator._getNotificationContext(source, (err, context) ->
                test.deepEqual(exp, context)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_notificateEmails: (test) ->
            emails = ['ya@exist.email', 'i-ya@exist.email']
            source =
                id: 'source_id'
            context = 'ya context'
            ImportNotificatorMock = sinon.mock(ImportNotificator)
            ImportNotificatorMock
                .expects('_getNotificationContext')
                .withArgs(source)
                .once()
                .callsArgWith(1, null, context)
            ImportNotificatorMock
                .expects('_sendNotificationsAndSaveResults')
                .withArgs(emails, context, source.id)
                .once()
                .callsArgWith(3, null, 'ok')
            
            ImportNotificator._notificateEmails(emails, source, (err, res) ->
                test.equal('ok', res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

        test_sendNotificationsAndSaveResults: (test) ->
            emailsToSend = ['ya@exist.email', 'i-ya@exist.email']
            expRes = 
                'ya@exist.email': null
                'i-ya@exist.email': {error:'error'}
            context = 'ya context'
            sourceId = 'ya sourceId'
            ImportNotificatorMock = sinon.mock(ImportNotificator)
            ImportNotificatorMock
                .expects('_notificateEmailAndSaveResult')
                .withArgs('ya@exist.email', context, sourceId)
                .once()
                .callsArgWith(3, null, null)
            ImportNotificatorMock
                .expects('_notificateEmailAndSaveResult')
                .withArgs('i-ya@exist.email', context, sourceId)
                .once()
                .callsArgWith(3, {error:'error'}, null)
            ImportNotificator._sendNotificationsAndSaveResults(emailsToSend, context, sourceId, (err, res) ->
                test.deepEqual(expRes, res)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )
            
        test_notificateEmailAndSaveResult: (test) ->
            context = 'ya context'
            sourceId = 'ya sourceId'
            ImportNotificatorMock = sinon.mock(ImportNotificator)
            ImportNotificatorMock
                .expects('_notificateEmail')
                .withArgs('ya@exist.email', context)
                .once()
                .callsArgWith(2, null, null)
            ImportNotificatorMock
                .expects('_saveNotification')
                .withArgs('ya@exist.email', sourceId)
                .once()
                .callsArgWith(2, null, null)
            ImportNotificator._notificateEmailAndSaveResult('ya@exist.email', context, sourceId, (err, res) ->
                test.deepEqual(null, null)
                sinon.verifyAll()
                sinon.restoreAll()
                test.done()
            )

