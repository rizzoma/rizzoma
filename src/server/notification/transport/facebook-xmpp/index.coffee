_ = require('underscore')
xmpp = require('node-xmpp')
NotificationTransport = require('../').NotificationTransport
Conf  = require('../../../conf').Conf
logger = Conf.getLogger('notification')
Conf  = Conf.getAuthConf().facebook
NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP = require('../../constants').NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP

PING_TIMEPOT = 21 * 1000
CONNECTION_TTL = 3 * 60 * 1000


class Connection
    constructor: (facebookId, token, errback=->) ->
        @_pingTimerHandler = null
        @_isOnline = false
        @_messageQueue = []
        @_lastActivity = 0
        params =
            jid: "-#{facebookId}@chat.facebook.com"
            api_key: Conf.clientID
            secret_key: Conf.clientSecret
            access_token: token
        @_client = new xmpp.Client(params)
        @_client.on('online', @_onOnline)
        @_client.on('stanza', (stanza) ->
            if stanza.name == "iq" and stanza.type == 'set' and stanza.to
                meta =
                    transport: NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP
                    to: stanza.to
                    fromFacebookId: facebookId
                logger.debug("Notification by '#{NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP}' to #{stanza.to} has been delivered", meta)
        )
        @_client.on('error', (err) =>
            @destroy()
            errback(err)
        )

    send: (facebookId, text) ->
        to = {to: "-#{facebookId}@chat.facebook.com", type: 'chat'}
        message = new xmpp.Element('message', to).c('body').t(text).up()
        @_messageQueue.push(message)
        @_flushQueue()
        @_lastActivity = Date.now()

    getLastActivity: () ->
        return @_lastActivity

    destroy: () ->
        @_isOnline = false
        clearInterval(@_pingTimerHandler)
        @_client.end()

    _onOnline: () =>
        presence = new xmpp.Element('presence')
        @_client.send(presence)
        ping = () =>
            return if not @_isOnline
            try
                @_client.send(presence)
            catch err
                logger.error("Facebook xmpp ping error: #{err}")
        @_pingTimerHandler = setInterval(ping, PING_TIMEPOT)
        ready = () =>
            @_isOnline = true
            @_flushQueue()
        setTimeout(ready, 2000)

    _flushQueue: () =>
        return if not @_isOnline
        while @_messageQueue.length
            message = @_messageQueue.shift()
            @_client.send(message)


class FacebookXmppTransport extends NotificationTransport
    ###
    Уведомитель через xmpp
    ###
    constructor: (xmppConf) ->
        super(xmppConf)
        @_connections = {}
        setInterval(@_destroyConnections, CONNECTION_TTL)

    getName: () -> NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP

    @getCommunicationType: () ->
        return "facebook-xmpp"

    notificateUser: (user, type, context, callback) ->
        super(user, type, context, callback)
        fromFacebookId = context.from.getExternalIds().facebook
        toFacebookId = context.contacts.getContact(user.email)[0].externalId
        token = context.contacts.getSourceData('facebook').accessToken
        templateName = @_getTemplate(type, true, '.txt')
        @_renderMessage(templateName, context, (err, message) =>
            return callback(err) if err
            @_getConnection(fromFacebookId, token).send(toFacebookId, message)
            isNewUser = if user.firstVisit then "existing user" else "new user"
            meta =
                transport: @getName()
                type: type
                from: context.from.email or fromFacebookId
                to: user.email or toFacebookId
                subject: message
                isNewUser: isNewUser
                success: true
            callback(null, meta)
        )

    _getTemplatePath: (templateName) ->
        return "#{super()}facebook-xmpp/#{templateName}"

    _getConnection: (facebookId, token) ->
        @_connections[facebookId] ||= new Connection(facebookId, token, (err) =>
            @_logger.error("Facebook-xmpp transport error: #{err}")
        )
        return @_connections[facebookId]

    _destroyConnections: () =>
        now = Date.now()
        ids = _.keys(@_connections)
        for id in ids
            connection = @_connections[id]
            continue if now - connection.getLastActivity() < CONNECTION_TTL
            connection.destroy()
            delete @_connections[id]

module.exports.FacebookXmppTransport = FacebookXmppTransport
