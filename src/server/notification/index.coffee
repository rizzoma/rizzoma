_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
NotificationTransport = require('./transport')
XmppTransport = require('./transport/xmpp').XmppTransport
SmtpTransport = require('./transport/smtp').SmtpTransport
SwitchingTransport = require('./transport/switching').SwitchingTransport
MandrillSmtpTransport = require('./transport/mandrill-smtp').MandrillSmtpTransport
FacebookXmppTransport = require('./transport/facebook-xmpp').FacebookXmppTransport
NotificationError = require('./exceptions').NotificationError
USER_DENY_NOTIFICATION = require('./exceptions').USER_DENY_NOTIFICATION
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor

{
    NOTIFICATOR_TRANSPORT_XMPP
    NOTIFICATOR_TRANSPORT_SMTP
    NOTIFICATOR_TRANSPORT_SWITCHING
    NOTIFICATOR_TRANSPORT_MANDRILL_SMTP
    NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP
} = require('./constants')

class Notificator
    ###
    Класс нотификатора который нужно использовать
    определяет настройки нотификаций пользователя,
    заволдит необходимые транспорты и шлет ччз них уведомления
    ###
    constructor: () ->
        @transports = {}
        @_logger = Conf.getLogger('notification')
        @_conf = Conf.getNotificationConf()

    initTransports: () ->
        transports = @_conf.transport || {}
        for own transport, conf of transports
            @transports[transport] = @_transportFactory(transport, conf)
            @transports[transport].init()

    notificateUser: (user, type, context, callback) ->
        ###
        Отсылает уведомление пользователю.
        @param user: UserModel
        @param type: string - тип сообщения (пределяет шаблон сообщения), @see: src/server/templates/notification
        @param context: object - контекст сообщения, передается вшаблон
        @param callback: function
        ###
        @notificateUsers([{user, context}], type, callback)

    notificateUsers: (notifications, type, callback) ->
        ###
        Оповещает нескольких пользователей сообщениями одного типа, но (возможно) с разным контекстом.
        @param notifications: array
            [{context: object- контекст сообщения, user: UserModel}, ...]
        @param type: string
        @param callback: function
        ###
        users = []
        for notification in notifications
            user = notification.user
            context = notification.context
            continue if not user or not context
            users.push(user)
            context.baseUrl = Conf.get('baseUrl')
            context.dstUser = user
            context.fromType = type
        tasks = [
            async.apply(@_initUsersNotificationSettings, users)
            async.apply(@_notificateUsers, notifications, type)
        ]
        async.waterfall(tasks, callback)

    closeTransports: () ->
        for own trName, transport of @transports
            transport.close()

    _transportFactory: (transport, conf) ->
        switch transport
            when NOTIFICATOR_TRANSPORT_XMPP then return new XmppTransport(conf)
            when NOTIFICATOR_TRANSPORT_SMTP then return new SmtpTransport(conf)
            when NOTIFICATOR_TRANSPORT_MANDRILL_SMTP then return new MandrillSmtpTransport(conf)
            when NOTIFICATOR_TRANSPORT_FACEBOOK_XMPP then return new FacebookXmppTransport(conf)
            when NOTIFICATOR_TRANSPORT_SWITCHING then return new SwitchingTransport(conf)
            else return null

    _initUsersNotificationSettings: (users, callback) =>
        ###
        Инициализирует объект настройки нотификаций пользователя.
        @params users: array
        @params callback: function
        ###
        action = (user, callback) ->
            return callback(null, false, user, false) if user.notification.id
            user.notification.generateId()
            callback(null, true, user, false)
        UserCouchProcessor.bulkSaveResolvingConflicts(users, action, (err) =>
            return callback(null) if not err
            @_logger.warn("Error while saving notification settings for user '#{user.id}': ", err)
            return callback(new NotificationError("Can not init notification settings for user '#{user.id}'"))
        )

    _notificateUsers: (notifications, type, callback) =>
        return callback(new NotificationError("No any available notification transports")) if _.isEmpty(@transports)
        return callback(new NotificationError("No any available notification transports for type '#{type}'")) if not @_conf.hasTypeRules(type)
        tasks = []
        for notification in notifications
            tasks.push do (notification) =>
                return (callback) =>
                    @_notificateUser(notification.user, type, notification.context, (err) ->
                        callback(null, err)
                    )
        async.series(tasks, (err, res) ->
            for userId, err of res
                return callback(null, res) if err
            callback(null, {})
        )

    _filterTransportsByUserSettings: (transports, type, user) ->
        enabledCommunicationTypes = user.notification.getEnabledCommunicationTypes(type)
        transportNames = (name for name in transports when @transports[name].constructor.getCommunicationType() in enabledCommunicationTypes)
        return transportNames

    _notificateUser: (user, type, context, callback) ->
        ###
        Непосредственно шлет уведомления пользователю через возможные транспорты
        ###
        transportNames = _.intersection(_.keys(@transports), @_conf.getTypeRules(type))
        transportNames = @_filterTransportsByUserSettings(transportNames, type, user)
        if not transportNames or not transportNames.length
            return callback(new NotificationError("User '#{user.id}' has not any available notification transport", USER_DENY_NOTIFICATION), null)
        tasks = []
        for transportName in transportNames
            if @transports[transportName]
                tasks.push(do (transportName) =>
                    return (callback) =>
                        transport = @transports[transportName]
                        transport.notificateUser(user, type, context, (err, meta) =>
                            return callback(null, err) if not meta
                            msg = "Notification by transport '#{meta.transport}' of type '#{type}' from #{meta.from} to #{meta.to} (#{meta.isNewUser})"
                            if not meta.success
                                @_logger.error(msg + " has not been sent", meta)
                            else
                                @_logger.debug(msg + " has been sent", meta)
                            callback(null, err)
                        )
                )
        async.parallel(tasks, (err, res) =>
            err = null
            if _.all(res, _.identity)
                err = new NotificationError("Unable to send message to user '#{user.id}'")
                @_logger.error(oneRes) for oneRes in res
            callback(err)
        )

module.exports =
    Notificator: new Notificator()
    NOTIFICATOR_TRANSPORT_XMPP: NOTIFICATOR_TRANSPORT_XMPP
    NOTIFICATOR_TRANSPORT_SMTP: NOTIFICATOR_TRANSPORT_SMTP

