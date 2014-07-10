xmpp = require('node-xmpp')
util = require('util')
NotificationTransport = require('../').NotificationTransport
NOTIFICATOR_TRANSPORT_XMPP = require('../../constants').NOTIFICATOR_TRANSPORT_XMPP

STATUS_ONLINE = 5

class XmppTransport extends NotificationTransport
    ###
    Уведомитель через xmpp
    ###
    constructor: (xmppConf) ->
        super(xmppConf)
        @jid = xmppConf.jid
        @password = xmppConf.password

        # таймауты
        @idleTimeout = (xmppConf.idleTimeout || 30) * 1000  # проверять связь (слать пинг) после такого времени неактивности соединения
        @pingTimeout = (xmppConf.pingTimeout || 10)  * 1000  # время, которое ожидаем ответа на пинг
        @connectTimeout = xmppConf.connectTimeout * 1000 || @idleTimeout  # если за это время не удалось установить соединение,то попробуем еще раз
        @_timer = null
        @_unsentMsg = []  # очередь, в которую кладем сообщения пока делаем реконнект

        # соединение с сервером
        @_cl = null

    @getCommunicationType: () ->
        return "gtalk"

    getName: () -> NOTIFICATOR_TRANSPORT_XMPP

    _createCl: () ->
        return new xmpp.Client({ jid: @jid, password: @password })
        
    _sendPresence: (to, type) ->
        param = {}
        if to
            param.to = to
        if type
            param.type = type
        # @_logger.debug("XMPP request is presence #{util.inspect(param)}")
        presence = new xmpp.Element('presence', param)
        @_cl.send(presence)
        
    _onStanza: (stanza) ->
        #@_logger.debug("XMPP response is #{stanza}")
        # если чувак авторизовал нас 
        if stanza.is('presence') and stanza.attrs.type == 'unsubscribe'
            @_sendPresence(stanza.attrs.from, 'unsubscribed')
        # если чувак хочет авторизоваться авторизуем его
        if stanza.is('presence') and stanza.attrs.type == 'subscribe'
            @_sendPresence(stanza.attrs.from, 'subscribed')
        # скажем что мы тоже онлайн
        if stanza.is('presence') and stanza.attrs.type is undefined
            @_sendPresence(stanza.attrs.from)

    init: () ->
        super()
        @_timer = setTimeout(@_reconnect, @connectTimeout)
        @_cl = @_createCl()
        @_initEvents()

    close: () ->
        clearTimeout(@_timer)
        @_cl.end()

    _reconnect: () =>
        @_logger.info('XMPP is starting reconnect')
        @close()
        @init()

    _onActivity: () ->
        sendPing = () =>
            pingElement = @_createPingElement()
            @_cl.send(pingElement)
            @_timer = setTimeout(@_reconnect, @pingTimeout)

        clearTimeout(@_timer)
        @_timer = setTimeout(sendPing, @idleTimeout)

    _initEvents: () ->
        @_cl.on('online', () =>
            @_onActivity()
            @_logger.info('XMPP is on-line')
            @_sendPresence()
            for msg in @_unsentMsg
                @_cl.send(msg)
            @_unsentMsg = []
        )
        @_cl.on('stanza', (stanza) =>
            @_onActivity()
            @_onStanza(stanza)
        )
        @_cl.on('error', (e) =>
            @_logger.error(e)
        )
        #@_cl.on('rawStanza', (stanza)=>
        #    @_logger.debug(if stanza.name == 'presence' then stanza.name else stanza)
        #)

    _getTemplatePath: (templateName) ->
        return "#{super()}xmpp/#{templateName}"

    _createPingElement: () ->
        ###
        Should send smth. like:
        <iq type='get' id='purple7c777ced'>
	        <ping xmlns='urn:xmpp:ping'/>
        </iq>
        ###
        return new xmpp.Element('iq', {type: 'get', id: 'ng'+(new Date()).getTime()})
            .c('ping', {xmlns: 'urn:xmpp:ping'}).up()

    _createMessageElement: (user, message) ->
        to = { to: user.email, type: 'chat'}    
        return new xmpp.Element('message', to)
            .c('body')
            .t(message).up()

    notificateUser: (user, type, context, callback) ->
        super(user, type, context, callback)
        return callback(new Error('No user email'), null) if not user.email
        templateName = @_getTemplate(type, true, '.txt')
        @_renderMessage(templateName, context, (err, message) =>
            return callback(err, null) if err
            messageElement = @_createMessageElement(user, message)
            if @_cl.state == STATUS_ONLINE
                @_cl.send(messageElement)
            else
                @_unsentMsg.push(messageElement)
            isNewUser = if user.firstVisit then "existing user" else "new user"
            meta =
                transport: @getName()
                type: type
                from: @jid
                to: user.email
                subject: message
                isNewUser: isNewUser
                success: @_cl.state == STATUS_ONLINE
            callback(null, meta)
        )

module.exports.XmppTransport = XmppTransport

