_ = require('underscore')
util = require('util')
async = require('async')
{Mandrill} = require('mandrill-api')
{Conf} = require('../../../conf')
fs = require('fs-plus')
{SmtpTransport} = require('../smtp')

class MandrillApiTransport extends SmtpTransport
    ###
    Уведомитель через Smtp
    ###
    constructor: (conf) ->
        super(conf)
        @_mandrill = new Mandrill(conf.key, true)

    @getCommunicationType: () ->
        return "email"

    _getFromName: (context) ->
        ###
        Возвращает заголовок fromName
        ###
        fromName = if context.from and context.from.name then context.from.name else @_conf.fromName
        return "" if not fromName
        return @_escapeFromName(fromName)

    _fillMailData: (user, res, context) ->
        fromEmail = @_conf.from
        fromName = @_getFromName(context)
        headers = {}
        replyTo = @_getReplyToHeader(context)
        headers['Reply-To'] = replyTo if replyTo
        console.log(res)
        params=
            "message":
                "subject": res.subject
                "html": res.html
                "text": res.body
                "from_email": fromEmail
                "from_name": fromName
                "to": [{
                    "email": user.email
                    "name": user.name
                }]
                "headers": headers
                "track_opens": true
                "track_clicks": false
                "auto_text": true
            "async": false
        return params

    notificateUser: (user, type, context, callback) ->
        return callback(new NotificationError('Wrong settings for transport'), null) if not @_conf
        subjectTemplateName = @_getTemplate(type, user.firstVisit, '_subject.txt')
        htmlTemplateName = @_getTemplate(type, user.firstVisit, '_body.html')
        bodyTemplateName = @_getTemplate(type, user.firstVisit, '_body.txt')
        tasks =
            subject: async.apply(@_renderMessage, subjectTemplateName, context)
            body: async.apply(@_renderMessage, bodyTemplateName, context)
            html: async.apply(@_renderMessage, htmlTemplateName, context)
        async.series(tasks, (err, res) =>
            return callback(err, null) if err
            mailData = @_fillMailData(user, res, context)
            isNewUser = if user.firstVisit then "existing user" else "new user"
            from = if context.from then context.from.email else "#{mailData.message.from_name} #{mailData.message.from_email}"
            meta =
                from: from
                mailData: mailData
                isNewUser: isNewUser
            @_mandrill.messages.send(mailData, (res) =>
                @_logger.debug("Mail of type '#{type}' from #{from} to #{user.email} (#{isNewUser}) has been sent", meta)
                callback?(null, res)
            , (err) =>
                @_logger.error("Mail of type '#{type}' from #{from} to #{user.email} (#{isNewUser}) has not been sent", meta)
                callback?(err, null)
            )
        )

    close: () ->


module.exports.MandrillApiTransport = MandrillApiTransport
