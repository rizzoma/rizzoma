async = require('async')
SettingsGroupView = require('./settings_group_view').SettingsGroupView
{UserCouchProcessor} = require('../user/couch_processor')
{Conf} = require('../conf')

{DB_TO_COMMUNICATION_TYPES, COMMUNICATION_TYPES_TO_DB} = require('../user/notification')

class NotificationsSettingsView extends SettingsGroupView
    ###
    View группа настроек уведомлений.
    ###
    constructor: () ->
        super()
        @_routes['unsubscribe'] = @unsubscribeAll

    getName: () ->
        return 'notification'

    supplementContext: (context, user, profile, auths, callback) ->
        context.hash = user.notification.id
        context.name = user.name
        context.email = user.email
        context.avatar = user.avatar
        context.settings = user.notification.getSettings()
        context.denyAll = user.notification.state == 'deny-all'
        callback(null, context)

    unsubscribeAll: (req, res, userDataStrategy) =>
        ###
        Отписат от всех оповещений.
        ###
        tasks = [
            async.apply(userDataStrategy.get, req)
            (user, profile, auths, callback) =>
                action = (user, callback) ->
                    user.notification.state = 'deny-all'
                    user.notification.clearSettings()
                    callback(null, true, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, (err) =>
                    @_logger.error('Error while  unsubscribe from all notifications', {err: err, userId: user.id}) if err
                    callback(err)
                )
        ]
        async.waterfall(tasks, (err) =>
            return @_sendResponse(res, err) if req.method == 'POST'
            res.redirect(req.url.replace('unsubscribe/', ''))
        )

    update: (req, res, userDataStrategy) =>
        return if super(req, res)
        tasks = [
            async.apply(userDataStrategy.get, req)
            (user, profile, auths, callback) =>
                try
                    [settings, denyAll] = @_parsePostedSettings(req)
                catch err
                    return callback(err, user)
                action = (user, callback) =>
                    user.notification.state = null if not denyAll
                    user.notification.setSettings(settings)
                    callback(null, true, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, (err) =>
                    callback(err, user)
                )
        ]
        async.waterfall(tasks, (err, user) =>
            @_logger.error('Error while updating notfication settings', {err: err, userId: user.id}) if err
            @_sendResponse(res, err)
        )

    _parsePostedSettings: (req) ->
        ###
        Парсит настройки нотификаций которые надо изменить.
        ###
        rules = Conf.getNotificationConf().getCommunicationTypes()
        checked = req.param('settings') || []
        checked = [checked] if typeof checked == 'string'
        settings = {}
        denyAll = true
        for setting in checked
            [type, transport] = setting.split(';')
            throw new Error("Unknown notification type #{type}") if not rules[type]
            communicationType = DB_TO_COMMUNICATION_TYPES[transport]
            throw new Error("Unknown notification communicationType #{communicationType} for type #{type}") if communicationType not in rules[type]
            settings[type] = {} if not settings[type]
            settings[type][transport] = true
            denyAll = false
        for type, communicationTypes of rules
            settings[type] = {} if not settings[type]
            for communicationType in communicationTypes
                transport = COMMUNICATION_TYPES_TO_DB[communicationType]
                settings[type][transport] = false if not settings[type][transport]
        if settings.daily_changes_digest
            for transport, enabled of settings.daily_changes_digest
                settings.weekly_changes_digest[transport] = false if enabled
        return [settings, denyAll]

module.exports.NotificationsSettingsView = new NotificationsSettingsView()
