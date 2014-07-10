_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
CouchWaveProcessor = require('../wave/couch_processor').CouchWaveProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Notificator = require('../notification').Notificator
DateUtils = require('../utils/date_utils').DateUtils
USER_DENY_NOTIFICATION = require('../notification/exceptions').USER_DENY_NOTIFICATION
AmqpQueueListener = require('../common/amqp').AmqpQueueListener
NotImplementedError = require('../../share/exceptions').NotImplementedError

ACTION_READ = require('../wave/constants').ACTION_READ

DIGEST_PERIOD = 60 * 10
DIGEST_PERIOD_LIMIT = 60 * 60 * 24

PLUGINS = [
    require('../task/autosender')
    require('../message/autosender')
]

class PluginAutosender

    constructor: () ->
        @_logger = Conf.getLogger('plugin-autosender')
        @_plugins = {}
        for plugin in PLUGINS
            @_plugins[plugin.getName()] = plugin
        amqpConnectOptions = Conf.getAmqpConf() || {}
        queriesRoutingKey = 'plugin_autosender_queries'
        amqpQueueListenerOptions =
            listenRoutingKey: queriesRoutingKey
            listenCallback: @_processRequest
            listenQueueAutoDelete: false
            listenQueueAck: true
        _.extend(amqpQueueListenerOptions, amqpConnectOptions)
        @_amqp = new AmqpQueueListener(amqpQueueListenerOptions)
        @_amqp.connect((err) =>
            return @_logger.error(err) if err
        )

    _processRequest: (rawMessage, headers, deliveryInfo, callback) =>
        responseRoutingKey = deliveryInfo.replyTo
        id = "#{responseRoutingKey}_#{deliveryInfo.correlationId}"
        @_logger.debug('Plugin autosender received start message', {id})
        @_run((err, res) =>
            @_logger.error(err) if err
            @_logger.info('Done', res)
            @_sendResponse(responseRoutingKey, deliveryInfo.correlationId, err)
            callback(null)
        )

    _sendResponse: (responseRoutingKey, correlationId, err) ->
        options =
            correlationId: correlationId
        @_amqp.publish(responseRoutingKey, JSON.stringify({err}), options)

    _mergeErrStates: (errState, errState1) ->
        for own name, plugin of @_plugins
            errState[name] = _.extend(errState[name] or {} , errState1[name] or {})
        return errState

    _run: (callback) ->
        tasks = [
            async.apply(@_prepareNotificationData)
            (blips, rootBlips, callback) =>
                @_getSendersAndRecipients(blips, (err, users, errState) ->
                    return callback(err) if err
                    callback(null, blips, rootBlips, users, errState)
                )
            (blips, rootBlips, users, errState, callback) =>
                randoms = @_generateNotificationRandoms(blips)
                callback(null, blips, rootBlips, users, errState, randoms)
            (blips, rootBlips, users, errState, randoms, callback) =>
                @_updateSentTimestamps(blips, errState, (err, saveErrState) =>
                    return callback(err, null) if err
                    errState = @_mergeErrStates(errState, saveErrState)
                    callback(null, blips, rootBlips, users, errState, randoms)
                    @_saveBlipsNotificationRandoms(blips, randoms)
                )
            (blips, rootBlips, users, errState, randoms, callback) =>
                notifications = @_getNotifications(blips, rootBlips, users, randoms, errState)
                @_sendNotifications(notifications, (err, sendErrState) =>
                    errState = @_mergeErrStates(errState, sendErrState)
                    callback(err, errState)
                )
        ]
        async.waterfall(tasks, callback)

    _generateNotificationRandoms: (blips) ->
        randoms = {}
        for own name, plugin of @_plugins
            randoms[name] = {}
            for own id, blip of blips
                randoms[name][id] = blip[name].generateNotificationRandoms()
        return randoms

    _saveBlipsNotificationRandoms: (blips, randoms) ->
        blips = _.values(blips) if not _.isArray(blips)
        action = (blip, callback) =>
            blipRandoms = {}
            for own name, plugin of @_plugins when randoms[name] and randoms[name][blip.id]
                blipRandoms = _.extend(blipRandoms, randoms[name][blip.id])
            for userId, random of blipRandoms
                blip.notificationRecipients[random] = userId
            callback(null, true, blip, false)
        CouchBlipProcessor.bulkSaveResolvingConflicts(blips, action, (err, res) =>
            @_logger.warn(err) if err
            for id, err of res
                @_logger.warn(err) if err.error
        )

    _prepareNotificationData: (callback) =>
        tasks = [
            async.apply(@_getNonSentBlips)
            (blips, callback) ->
                waveIds = {}
                for own id, blip of blips
                    waveId = blip.waveId
                    waveIds[waveId] = waveId
                CouchWaveProcessor.getByIdsAsDict(_.keys(waveIds), (err, waves) ->
                    return callback(err, blips, waves)
                )
            (blips, waves, callback) ->
                rootBlipIds = []
                for own id, blip of blips
                    wave = waves[blip.waveId]
                    continue if not wave
                    blip.setWave(wave)
                    rootBlipIds.push(wave.rootBlipId)
                callback(null, blips, rootBlipIds)
            (blips, rootBlipIds, callback) ->
                CouchBlipProcessor.getByIdsAsDict(rootBlipIds, (err, rootBlips) ->
                    callback(err, blips, rootBlips)
                )
        ]
        async.waterfall(tasks, callback)

    _getNonSentBlips: (callback) =>
        now = DateUtils.getCurrentTimestamp()
        to = now - DIGEST_PERIOD
        from = now - DIGEST_PERIOD_LIMIT
        CouchBlipProcessor.getNonSentBlipsByTimestampAsDict(from, to, (err, blips) =>
            return callback(err) if err
            @_logger.debug("Loaded #{_.keys(blips).length} blips with nonsent plugins data")
            callback(null, blips)
        )

    _getSendersAndRecipients: (blips, callback) ->
        ###
        Возвращает словарь участников (отправители и получатели) всех задач в блипе.
        ###
        allIds = []
        for own id, blip of blips
            for own name, pluginIds of  @_getSendersAndRecipientsIdsPlugins(blip)
                [ids, recipientIds] = pluginIds
                allIds.push(ids)
        UserCouchProcessor.getByIdsAsDict([].concat(allIds...), (err, users) =>
            return callback(err) if err
            errState = {}
            for own id, blip of blips
                for own name, pluginIds of  @_getSendersAndRecipientsIdsPlugins(blip)
                    [ids, recipientIds] = pluginIds
                    errState[name] ?= {}
                    errState[name][id] = @_checkRecipientPermissions(blip, users, recipientIds)
            callback(null, users, errState)
        )

    _checkRecipientPermissions: (blip, users, recipientIds) ->
        errState = {}
        for id in recipientIds
            user = users[id]
            if not user
                @_logger.warn("User #{id} not loaded while process plugin data autosending")
                continue
            err = blip.checkPermission(user, ACTION_READ)
            continue if not err
            errState[id] = err.toClient()
            delete users[id]
        return errState

    _getSendersAndRecipientsIdsPlugins: (blip) ->
        idsByPlugin = {}
        for own name, plugin of @_plugins
            idsByPlugin[name] = plugin.getSendersAndRecipientsIdsForOneItem(blip)
        return idsByPlugin

    _getNotifications: (blips, rootBlips, users, randoms, errState) ->
        notifications = {}
        for own name, plugin of @_plugins
            notifications[name] = {}
            errStatePlugin = errState[name] or {}
            for own id, blip of blips
                continue if not _.isEmpty(errStatePlugin[id])
                rootBlip = rootBlips[blip.getWave().rootBlipId]
                continue if not rootBlip
                notifications[name][id] = plugin.getNotifications(blip, rootBlip, users, randoms[name][id])
        return notifications

    _sendNotifications: (notifications, callback) ->
        tasks = {}
        for own name, notificationsByBlip of notifications
            tasks[name] = do(name, notificationsByBlip) =>
                return (callback) =>
                    @_notificateUsersByBlips(notificationsByBlip, name, callback)
        async.parallel(tasks, callback)

    _notificateUsersByBlips: (notifications, name, callback) ->
        tasks = {}
        for own blipId, blipNotifications of notifications
            tasks[blipId] = do(blipNotifications) =>
                return (callback) =>
                    nonSelfNotifications = []
                    for notification in blipNotifications
                        nonSelfNotifications.push(notification) if not notification.user.isEqual(notification.context.sender)
                    Notificator.notificateUsers(nonSelfNotifications, name, (err, errById) =>
                        return callback(null, @_processNotificationBlipError(err, blipNotifications)) if err
                        callback(null, @_processNotificationUserError(nonSelfNotifications, errById))
                    )
        async.parallel(tasks, callback)

    _processNotificationBlipError: (err, blipNotifications) ->
        blipErr = {}
        for blipNotification in blipNotifications
            blipErr[blipNotification.user.id] = err
        return blipErr

    _processNotificationUserError: (notifications, errById) ->
        userErr = {}
        for notification, i in notifications
            err = errById[i]
            userErr[notification.user.id] = err if err and err.code != USER_DENY_NOTIFICATION
        return userErr

    _updateSentTimestamps: (blips, gotErrState, callback) ->
        tasks = {}
        for own name, plugin of @_plugins
            errState = gotErrState[name] or {}
            tasks[name] = do(errState, plugin) =>
                return (callback) =>
                    @_updatePluginSentTimestamps(blips, errState, plugin, callback)
        async.parallel(tasks, callback)

    _updatePluginSentTimestamps: (blips, errState, plugin, callback) ->
        tasks = {}
        for own id, blip of blips
            continue if not _.isEmpty(errState[id])
            tasks[id] = do(blip) =>
                return (callback) =>
                    plugin.updateSentTimestamp(blip, (err) ->
                        callback(null, err)
                    )
        async.parallel(tasks, callback)

module.exports.PluginAutosender = new PluginAutosender()
