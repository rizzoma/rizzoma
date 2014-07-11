{SmtpTransport} = require('../smtp')
NOTIFICATOR_TRANSPORT_MANDRILL_SMTP = require('../../constants').NOTIFICATOR_TRANSPORT_MANDRILL_SMTP

class MandrillSmtpTransport extends SmtpTransport
    ###
    Уведомитель через Smtp
    ###
    constructor: (conf) ->
        super(conf)

    @getCommunicationType: () ->
        return "email"

    getName: () -> NOTIFICATOR_TRANSPORT_MANDRILL_SMTP

    _fillMailData: (user, res, context, type) ->
        mailData = super(user, res, context, type)
        mailData.headers = {} if not mailData.headers
        mailData.headers['X-MC-Track'] = 'opens'
        mailData.headers['X-MC-Tags'] = "#{type}," + (if user.firstVisit then "existing_user" else "new_user")
        if mailData.from
            mailData.headers['From'] = "=?utf-8?b?" + new Buffer(mailData.from, "utf-8").toString("base64") + "?="
            delete mailData.from
        return mailData

module.exports.MandrillSmtpTransport = MandrillSmtpTransport