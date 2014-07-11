global.getLogger = () ->
    return {error: ->}
sinon = require('sinon')
nodemailer = require('nodemailer')
testCase = require('nodeunit').testCase
SmtpTransport = require('../../../../server/notification/transport/smtp').SmtpTransport

module.exports =
    TestSmtpTransport: testCase

        setUp: (callback) ->
            callback()

        tearDown: (callback) ->
            callback()
    
        testNotificateUser: (test) ->
            transport = new SmtpTransport({sender: 'ya MbIJI0'})
            transportMock = sinon.mock(transport)
            
            transportMock
                .expects('_getTemplatePath')
                .withArgs('templateName')
                .once()
                .returns('subject_template_name')
            transportMock
                .expects('_getTemplatePath')
                .withArgs('templateName')
                .once()
                .returns('body_template_name')
            transportMock
                .expects('_getTemplatePath')
                .withArgs('templateName')
                .once()
                .returns('html_template_name')

            transportMock
                .expects('_renderMessage')
                .withArgs('subject_template_name_subject.txt')
                .once()
                .callsArgWith(2, null, 'rendered_subject')
            transportMock
                .expects('_renderMessage')
                .withArgs('body_template_name_body.txt')
                .once()
                .callsArgWith(2, null, 'rendered_body')
            transportMock
                .expects('_renderMessage')
                .withArgs('html_template_name_body.html')
                .once()
                .callsArgWith(2, null, 'rendered_html')
            
            user = {email: 'Other tomail'}
            mail_data =
                sender: 'ya MbIJI0'
                to: 'Other tomail'
                subject: 'rendered_subject'
                html: 'rendered_html'
                body: 'rendered_body'
            
            transportMock
                .expects('_fillMailData')
                .withArgs(user)
                .once()
                .returns(mail_data)
            
            nodemailerMock = sinon.mock(nodemailer)
            nodemailerMock
                .expects('send_mail')
                .withArgs(mail_data)
                .once()
                .callsArgWith(1, null, true)

            transport.notificateUser(user, 'templateName', {}, (err, res) ->
                test.equal(true, res)
                
                transportMock.verify()
                transportMock.restore()
                nodemailerMock.verify()
                nodemailerMock.restore()
                
                test.done()
            )
