_ = require('underscore')
nodemailer = require('nodemailer')
util = require('util')
async = require('async')
Conf = require('../../../conf').Conf
NotificationTransport = require('../').NotificationTransport

NOTIFICATOR_TRANSPORT_SMTP = require('../../constants').NOTIFICATOR_TRANSPORT_SMTP

class SmtpTransport extends NotificationTransport
    ###
    Уведомитель через Smtp
    ###
    constructor: (smtpConf) ->
        super(smtpConf)

    getName: () -> NOTIFICATOR_TRANSPORT_SMTP

    @getCommunicationType: () ->
        return "email"

    init: () ->
        super()
        conf = {}
        conf.host = @_conf.host
        conf.port = @_conf.port
        conf.secureConnection = @_conf.ssl
        conf.use_authentication = @_conf.use_authentication
        conf.user = @_conf.user
        conf.pass = @_conf.pass

        @_transport = nodemailer.createTransport("SMTP", conf)

    _getTemplatePath: (templateName) ->
        return "#{super()}smtp/#{templateName}"
    
    _escapeFromName: (fromName) ->
        ###
        Удаляет плохие символы из имени отправителя
        ###
        fromName = fromName.replace(/[<\\"]/g, '')
        return fromName.replace(" ", "\xa0")

    _getFromHeader: (context) ->
        ###
        Возвращает заголовок from
        ###
        return "" if not @_conf.from
        fromName = if context.from and context.from.name then context.from.name else @_conf.fromName
        if fromName
            return "\"#{@_escapeFromName(fromName)}\xa0(Rizzoma)\" <#{@_conf.from}>"
        else
            return @_conf.from

    _getReplyToHeader: (context) ->
        ###
        Возвращает заголовок replyTo если подобное поле есть в контексте
        context.replyTo может быть строкой или объектом типа UserModel
        ###
        return null if not context.replyTo
        return context.replyTo if _.isString(context.replyTo)
        return context.replyTo.email if context.replyTo and context.replyTo.email
        return null

    _fillMailData: (user, res, context, type) ->
        mailData =
            to: user.email
            html: res.html
            body: res.body
        from = @_getFromHeader(context)
        mailData.from = from if from
        replyTo = @_getReplyToHeader(context)
        mailData.replyTo = replyTo if replyTo
        mailData.attachments = context.attachments if context.attachments
        mailData.headers = {} if not mailData.headers
        mailData.headers['Subject'] = "=?utf-8?b?" + new Buffer(res.subject, "utf-8").toString("base64") + "?="
        return mailData

    notificateUser: (user, type, context, callback) ->
        super(user, type, context, callback)
        return callback(new Error('No user email'), null) if not user.email
        subjectTemplateName = @_getTemplate(type, user.firstVisit, '_subject.txt')
        htmlTemplateName = @_getTemplate(type, user.firstVisit, '_body.html')
        bodyTemplateName = @_getTemplate(type, user.firstVisit, '_body.txt')
        tasks =
            subject: async.apply(@_renderMessage, subjectTemplateName, context)
            body: async.apply(@_renderMessage, bodyTemplateName, context)
            html: async.apply(@_renderMessage, htmlTemplateName, context)
        async.series(tasks, (err, res) =>
            return callback(err, null) if err
            mailData = @_fillMailData(user, res, context, type)
            @_transport.sendMail(mailData, (error, success) =>
                isNewUser = if user.firstVisit then "existing user" else "new user"
                from = if context.from then context.from.email else @_getFromHeader(context)
                meta =
                    transport: @getName()
                    type: type
                    from: from
                    to: mailData.to
                    subject: res.subject
                    replyTo: mailData.replyTo
                    isNewUser: isNewUser
                    success: !!success
                callback(error, meta)
            )
        )

    close: () ->
        

module.exports.SmtpTransport = SmtpTransport
