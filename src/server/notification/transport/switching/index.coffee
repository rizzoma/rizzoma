Conf = require('../../../conf').Conf
ContactsCouchProcessor = require('../../../contacts/couch_processor').ContactsCouchProcessor
NotificationTransport = require('../').NotificationTransport
MandrillSmtpTransport = require('../mandrill-smtp').MandrillSmtpTransport
FacebookXmppTransport = require('../facebook-xmpp').FacebookXmppTransport
UserUtils = require('../../../user/utils').UserUtils

{
    NOTIFICATOR_TRANSPORT_SWITCHING
    NOTIFICATOR_TRANSPORT_MANDRILL_SMTP
    NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP
} = require('../../constants')

class SwitchingTransport extends NotificationTransport
    ###
    ###
    constructor: (facebookConf) ->
        super(facebookConf)
        conf = Conf.getNotificationConf().transport or {}
        smtpConf = conf[NOTIFICATOR_TRANSPORT_MANDRILL_SMTP]
        xmppConf = conf[NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP]
        return if not (smtpConf and xmppConf)
        @_smtpTransport = new MandrillSmtpTransport(smtpConf)
        @_smtpTransport.init()
        @_xmppTransport = new FacebookXmppTransport(xmppConf)
        @_xmppTransport.init()

    @getCommunicationType: () ->
        return 'email'

    getName: () -> NOTIFICATOR_TRANSPORT_SWITCHING

    notificateUser: (user, type, context, callback) ->
        @_selectTransport(user, context, (err, transport) ->
            return callback(err) if err
            transport.notificateUser(user, type, context, callback)
        )
        super(user, type, context, callback)


    _selectTransport: (user, context, callback) ->
        selectSmtp = (logMessage, logMeta, isError=no) =>
            logMeta.transport = 'smtp'
            if isError then @_logger.error(logMessage, logMeta) else @_logger.debug(logMessage, logMeta)
            callback(null, @_smtpTransport)
        selectXmpp = (logMessage, logMeta) =>
            logMeta.transport = 'xmpp'
            @_logger.debug(logMessage, logMeta)
            callback(null, @_xmppTransport)
        logMeta =
            toId: user.id
            toEmail: user.email
        from = context.from
        if not from
            return selectSmtp("Switching transport use smtp for user #{user.id} (#{user.email}): 'from' not specified", logMeta)
        logMeta.fromId = from.id
        logMeta.fromEmail = from.email
        if not UserUtils.isFacebookEmail(user.email)
            return selectSmtp("Switching transport use smtp #{from.id} (#{from.email}) -> #{user.id} (#{user.email}): not facebook user", logMeta)
        facebookId = from.getExternalIds().facebook
        if not facebookId
            @_logger.warn("Bugcheck. Usending facebook message from user #{from.id} with no facebook id. Use default")
            facebookId = 'rizzoma'
            #return selectSmtp("Switchin transport use smtp #{from.id} (#{from.email}) -> #{user.id} (#{user.email}): facebook id not specified", logMeta)
        @_getContacts(from, (err, contacts) =>
            if err
                logMeta.err = err
                return selectSmtp("Switching transport use smtp #{from.id} (#{from.email}) -> #{user.id} (#{user.email}): #{err}", logMeta, yes)
            if not contacts.getSourceData('facebook')?.accessToken
                return selectSmtp("Switching transport use smtp #{from.id} (#{from.email}) -> #{user.id} (#{user.email}): no token", logMeta)
            if not contacts.getContact(user.email)[0]
                return selectSmtp("Switching transport use smtp #{from.id} (#{from.email}) -> #{user.id} (#{user.email}): not in contacts", logMeta)
            context.contacts = contacts
            selectXmpp("Switching transport use facebook-xmpp #{from.id} (#{from.email}) -> #{user.id} (#{user.email})", logMeta)
        )

    _getContacts: (user, callback) ->
        ContactsCouchProcessor.getById(user.getContactsId(), callback)

module.exports.SwitchingTransport = SwitchingTransport
