global.getLogger = () ->
    return {error: ->}
dataprovider = require('dataprovider')
testCase = require('nodeunit').testCase
sinon = require('sinon')
Notificator = require('../../../server/notification/').Notificator
Conf = require('../../../server/conf').Conf
XmppTransport = require('../../../server/notification/transport/xmpp').XmppTransport
SmtpTransport = require('../../../server/notification/transport/smtp').SmtpTransport
User = require('../../../server/user/models').User

module.exports =
    TestNotificator: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()
    
        testNotificateUsers: (test) ->
            users = [
                {id: 'usder1'}
                {id: 'usder2'}
                {id: 'usder3'}
            ]
            template = 'message'
            context =
                title: 'ia context'
            NotificatorMock = sinon.mock(Notificator)
            NotificatorMock
                .expects('notificateUser')
                .withArgs(users[0], template, context)
                .once()
                .callsArgWith(3, null, 'отправлено')
            NotificatorMock
                .expects('notificateUser')
                .withArgs(users[1], template, context)
                .once()
                .callsArgWith(3, null, 'отправлено')
            NotificatorMock
                .expects('notificateUser')
                .withArgs(users[2], template, context)
                .once()
                .callsArgWith(3, null, 'отправлено')
            
            Notificator.notificateUsers(users, template, context, (err) ->
                test.equal(null, err)
                NotificatorMock.verify()
                NotificatorMock.restore()
            )
            test.done()
        
        testNotificateUser: (test) ->
            user = new User()
            user.id = 'usder1'
            template = 'message'
            context =
                title: 'ia context'
            transport =
                notificateUser: (user, template, context, callback) ->
            userMock = sinon.mock(user)
            userMock
                .expects('getAvailableNotificationTransports')
                .withArgs(template)
                .once()
                .returns(['xmpp', 'smtp'])
            transportMock = sinon.mock(transport)
            Notificator.transports = {'xmpp': transport}
            transportMock
                .expects('notificateUser')
                .withArgs(user, template, context)
                .once()
                .callsArgWith(3, null, 'отправлено')
            
            Notificator.notificateUser(user, template, context, (err, res) ->
                test.equal(null, err)
                userMock.verify()
                userMock.restore()
                transportMock.verify()
                transportMock.restore()
            )
            test.done()
        
        test_transportFactory: (test) ->
            testCode = (done, exp, transport) =>
                transportsConf =
                    xmpp:
                        jid: 'projectvolnanotificator@gmail.com'
                        password: 'volnaman'
                    smtp:
                        host: 'smtp.gmail.com'
                        port: 587
                        ssl: false
                        use_authentication: true
                        user: 'projectvolnanotificator@gmail.com'
                        pass: 'volnaman'
                        sender: 'projectvolnanotificator@gmail.com'
                res = Notificator._transportFactory(transport, transportsConf[transport])
                if exp is null
                    test.equal(null, res)
                else
                    test.ok(res instanceof exp)
                done()
            
            testCases = [
                [XmppTransport, 'xmpp'],
                [SmtpTransport, 'smtp'],
                [null, 'abra'],
            ]
            
            dataprovider(test, testCases, testCode)
        
        testCloseTransports: (test) ->
            transport =
                close: () ->
            transportMock = sinon.mock(transport)
            Notificator.transports = {'xmpp': transport}
            transportMock
                .expects('close')
                .once()
            Notificator.closeTransports()
            transportMock.verify()
            transportMock.restore()
            test.done()

        testInitTransports: (test) ->
            transportsConf =
                xmpp:
                    jid: 'jid@jabber.com'
                smtp:
                    host: 'smtp@email.com'
            xmpp_transport = 
                init: () ->
            smtp_transport = 
                init: () ->
            ConfMock = sinon.mock(Conf)
            ConfMock
                .expects('get')
                .withExactArgs('notification')
                .once()
                .returns(transportsConf)
            NotificatorMock = sinon.mock(Notificator)
            NotificatorMock
                .expects('_transportFactory')
                .withArgs('xmpp', transportsConf.xmpp)
                .once()
                .returns(xmpp_transport)
            NotificatorMock
                .expects('_transportFactory')
                .withArgs('smtp', transportsConf.smtp)
                .once()
                .returns(smtp_transport)
            Notificator.initTransports()
            test.deepEqual(
                {xmpp: xmpp_transport, smtp: smtp_transport},
                Notificator.transports
            )
            ConfMock.verify()
            ConfMock.restore()
            NotificatorMock.verify()
            NotificatorMock.restore()
            test.done()

