global.getLogger = () ->
    return {
        error: ->
        debug: ->
    }
sinon = require('sinon')
xmpp = require('node-xmpp')
dataprovider = require('dataprovider')
testCase = require('nodeunit').testCase
XmppTransport = require('../../../../server/notification/transport/xmpp/').XmppTransport


module.exports =
    TestNotificator: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()
        
        testNotificateUser: (test) ->
            transport = new XmppTransport({sender: 'ya MbIJI0'})
            transport.cl = {
                send: (messageElement) ->
            }
            transportMock = sinon.mock(transport)
            transportMock
                .expects('_getTemplatePath')
                .withArgs('templateName')
                .once()
                .returns('our_string')
            transportMock
                .expects('_renderMessage')
                .withArgs('our_string.txt')
                .once()
                .callsArgWith(2, null, 'MyMessage')
            user = {email: 'Other tomail'}
            transportMock
                .expects('_createMessageElement')
                .withArgs(user, 'MyMessage')
                .returns('xmppElement')
            clMock = sinon.mock(transport.cl)
            clMock
                .expects('send')
                .withArgs('xmppElement')
                .once()
            transport.notificateUser(user, 'templateName', {}, (err, res) ->
                test.equal(true, res)
                transportMock.verify()
                transportMock.restore()
                clMock.verify()
                clMock.restore()
                test.done()
            )

        testInit: (test) ->
            transport = new XmppTransport({sender: 'ya MbIJI0'})
            transport.cl = {
                on: (event, callback) ->
                send: (messageElement) ->
            }
            transportMock = sinon.mock(transport)
            transportMock
                .expects('_createCl')
                .once()
                .returns(transport.cl)
            clMock = sinon.mock(transport.cl)
            clMock
                .expects('on')
                .withArgs('online')
                .once()
                .callsArgWith(1)
            clMock
                .expects('send')
                .once()
            clMock
                .expects('on')
                .withArgs('stanza')
                .once()
                .callsArgWith(1)
            transportMock
                .expects('_onStanza')
                .once()
            clMock
                .expects('on')
                .withArgs('error')
                .once()
            transport.init()
            transportMock.verify()
            transportMock.restore()
            clMock.verify()
            clMock.restore()
            test.done()
            
        test_onStanza: (test) ->
            testCode = (done, exp, stanzaStr, type, from) ->
                transport = new XmppTransport({})
                stanza =
                    is: (str) ->
                        return str == 'presence'
                    attrs: {
                        type: type
                        from: from
                    }
                stanza.attrs.type = type
                transportMock = sinon.mock(transport)
                if stanzaStr == 'presence'
                    transportMock
                        .expects('_sendPresence')
                        .withArgs(exp...)
                        .once()
                transport._onStanza(stanza)
                transportMock.verify()
                transportMock.restore()
                done()
                
            testCases = [
                [['mbIlo', 'unsubscribed'], 'presence', 'unsubscribe', 'mbIlo'],
                [['mbIlo', 'subscribed'], 'presence', 'subscribe', 'mbIlo'],
                [['mbIlo'], 'presence', undefined, 'mbIlo']
            ]
            
            dataprovider(test, testCases, testCode)
           
