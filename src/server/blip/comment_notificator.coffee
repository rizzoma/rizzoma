_ = require('underscore')
async = require('async')
{Conf} = require('../conf')
{CouchBlipProcessor} = require('./couch_processor')
{CouchWaveProcessor} = require('../wave/couch_processor')
{DateUtils} = require('../utils/date_utils')
{UserCouchProcessor} = require('../user/couch_processor')
{Notificator} = require('../notification')
NotificationUtils = require('../notification/utils').Utils
{USER_DENY_NOTIFICATION} = require('../notification/exceptions')
#{WAVE_SHARED_STATE_PUBLIC} = require('../wave/constants')
{ACTIONS} = require('../wave/constants')

# Время по прошествии которого считаем что блип уже не редактируют (сек)
IDLE_TIMEOUT = 5 * 60
# Время после которого уже не подбираем эти блипы (сек) 3 дня
NOTIFICATE_TIMEOUT = 60 * 60 * 24 * 3

class CommentNotificator
    constructor: () ->
        @_logger = Conf.getLogger('comment-notificator')

    _getBlipsToNotificate: (callback) =>
        ###
        Достает блипы о которых нужно уведомить
        ###
        now = DateUtils.getCurrentTimestamp()
        CouchBlipProcessor.getByNeedNotificateAsDict(now - NOTIFICATE_TIMEOUT, now - IDLE_TIMEOUT, callback)

    _getParents: (blips, callback) ->
        ###
        Достает блипы на которые появились комменты
        ###
        blipIds = (blipId for blipId, blip of blips)
        CouchBlipProcessor.getByAnswerIds(blipIds, callback)

    _getUsers: (blips, parents, callback) ->
        ###
        Загружает пользовуателей из блипов
        ###
        userIds = {}
        for blipId, blip of blips
            parentBlip = parents[blipId]
            if not parentBlip
                @_logger.warn("Blip #{blipId} has no parent")
                continue
            contributorId = blip.getAuthorId()
            userIds[contributorId] = contributorId
            contributorId = parentBlip.getAuthorId()
            userIds[contributorId] = contributorId
        userIds = _.keys(userIds)
        UserCouchProcessor.getByIdsAsDict(userIds, callback)

    _hasMentionOrTaskWithRecipient: (blip, recipient) ->
        ###
        Проверяет есть ли в контенте меншен или задача на данного получателя
        ###
        for block in blip.content
            blockType = block.params.__TYPE
            return true if blockType == 'RECIPIENT' and recipient.isEqual(block.params.__ID)
            return true if blockType == 'TASK' and recipient.isEqual(block.params.recipientId)
        return false

    _getNotificationContexts: (blips, parents, users, waves, rootBlipsByWaveIds, randoms) ->
        ###
        Собирает контексты уведомлений
        ###
        notifications = []
        for blipId, blip of blips
            parentBlip = parents[blipId]
            if not parentBlip
                @_logger.warn("Blip #{blipId} has no parent")
                continue
            wave = waves[blip.waveId]
#            включили релаи в паблик топика на попробовать
#            continue if wave.getSharedState() == WAVE_SHARED_STATE_PUBLIC
            from = users[blip.getAuthorId()]
            user = users[parentBlip.getAuthorId()]
            continue if from.isEqual(user)
            continue if blip.getReadState(user)
            continue if wave.checkPermission(user, ACTIONS.ACTION_READ)
            # не отсылаем если встретили меншен или таск на данного пользователя
            continue if @_hasMentionOrTaskWithRecipient(blip, user)
            timezone = user.timezone or 0
            replyEmail = Conf.get('replyEmail').split('@')
            random = randoms[blip.id]
            replyTo = "#{replyEmail[0]}+#{waves[blip.waveId].getUrl()}/#{blip.id}/#{random.random}@#{replyEmail[1]}"
            context =
                topicTitle: rootBlipsByWaveIds[blip.waveId].getTitle()
                waveId: waves[blip.waveId].getUrl()
                blipText: blip.getText(null, null, "\n")
                blipId: blip.id
                blipTime: new Date(blip.contentTimestamp * 1000 + timezone * 3600000)
                timezone: if timezone >= 0 then "GMT+#{timezone}" else "GMT#{timezone}"
                parentBlipText: parentBlip.getText(null, null, "\n")
                from: from
                replyTo: replyTo
            notification = {user, context}
            notifications.push(notification)
        return notifications

    _parseNotificationsResult: (notifications, res) ->
        ###
        Парсит результат уведомлений и возвращает блипы о которых успешно уведомили
        ###
        notificatedBlips = []
        for notification, i in notifications
            err = res[i]
            if err and err.code != USER_DENY_NOTIFICATION
                @_logger.error(res[i])
            else
                notificatedBlips.push(notification.context.blipId)
        return notificatedBlips

    _notificateBlips: (blips, parents, users, waves, rootBlips, randoms, callback) ->
        ###
        Посылает уведомления и обрабатывает разультат
        ###
        notifications = @_getNotificationContexts(blips, parents, users, waves, rootBlips, randoms)
        @_logger.info("To notificate #{notifications.length} blips")
        Notificator.notificateUsers(notifications, 'new_comment', (err, res) =>
            return callback(err, null) if err
            notificatedBlips = @_parseNotificationsResult(notifications, res)
            callback(null, notificatedBlips)
        )

    _markBlipsAsNotificated: (blips, randoms, callback) ->
        ###
        Помечает блипы что о них уведомили
        ###
        action = (blip, callback) ->
            random = randoms[blip.id]
            blip.needNotificate = false
            blip.notificationRecipients[random.random] = random.userId if random
            callback(null, true, blip, false)
        CouchBlipProcessor.bulkSaveResolvingConflicts(_.values(blips), action, callback)

    _getWaves: (blips, callback) ->
        ###
        Загружает волны для блипов
        ###
        waveIds = []
        for blipId, blip of blips
            waveIds.push(blip.waveId)
        CouchWaveProcessor.getByIdsAsDict(waveIds, callback)

    _getRootBlipsByWaveIdsFromWaves: (parents, waves, callback) ->
        ###
        Загружает корневые блипы для волн
        ###
        rootBlips = {}
        rootBlipIds = {}
        for chldId, parent of parents
            if parent.isRootBlip
                rootBlips[parent.waveId] = parent
            else if not rootBlips[parent.waveId]
                wave = waves[parent.waveId]
                rootBlipIds[wave.rootBlipId] = wave.rootBlipId
        rootBlipIds = _.values(rootBlipIds)
        return callback(null, rootBlips) if not rootBlipIds.length
        CouchBlipProcessor.getByIdsAsDict(rootBlipIds, (err, blips) ->
            return callback(err, null) if err
            for blipId, blip of blips
                rootBlips[blip.waveId] = blip
            callback(null, rootBlips)
        )

    _parseMarkAsNotificatedResult: (blips, res) ->
        ###
        Собст-но парсит результат помечания отправленным и возвращает массив id удачно помеченных блипов
        ###
        saved = []
        for blipId, blip of blips
            errSrtate = res[blip.id]
            if errSrtate and errSrtate.error
                @_logger.error(errSrtate.error)
            else
                saved.push(blip.id)
        return saved

    _generateNotificationRandoms: (parents) ->
        randoms = {}
        for blipId, parent of parents
            randoms[blipId] = { random: NotificationUtils.generateNotificationRandom(), userId: parent.getAuthorId() }
        return randoms

    run: (callback) ->
        ###
        С чегооо начинается родина...
        ###
        @_logger.info("Started")
        Notificator.initTransports()
        tasks = [
            async.apply(@_getBlipsToNotificate)
            (blips, callback) =>
                @_logger.info("Loaded #{_.values(blips).length} blips to notify about")
                @_getParents(blips, (err, parents) ->
                    return callback(err, null) if err
                    callback(null, blips, parents)
                )
            (blips, parents, callback) =>
                @_logger.info("Loaded #{_.values(parents).length} parents blips")
                @_getUsers(blips, parents, (err, users) ->
                    return callback(err, null) if err
                    callback(null, blips, parents, users)
                )
            (blips, parents, users, callback) =>
                @_logger.info("Loaded #{_.values(users).length} users")
                @_getWaves(parents, (err, waves)->
                    return callback(err, null) if err
                    callback(null, blips, parents, users, waves)
                )
            (blips, parents, users, waves, callback) =>
                @_logger.info("Loaded #{_.values(waves).length} waves")
                @_getRootBlipsByWaveIdsFromWaves(parents, waves, (err, rootBlips) ->
                    return callback(err, null) if err
                    callback(null, blips, parents, users, waves, rootBlips)
                )
            (blips, parents, users, waves, rootBlips, callback) =>
                @_logger.info("Loaded #{_.values(rootBlips).length} root blips")
                randoms = @_generateNotificationRandoms(parents)
                callback(null, blips, parents, users, waves, rootBlips, randoms)
            (blips, parents, users, waves, rootBlips, randoms, callback) =>
                @_logger.info("To mark as notificated #{_.keys(blips).length} blips")
                @_markBlipsAsNotificated(blips, randoms, (err, res) =>
                    return callback(err, null) if err
                    saved = @_parseMarkAsNotificatedResult(blips, res)
                    @_logger.info("Mark as notificated #{saved.length} blips", saved)
                    savedBlips = {}
                    for blipId in saved
                        savedBlips[blipId] = blips[blipId]
                    callback(null, savedBlips, parents, users, waves, rootBlips, randoms)
                )
            (blips, parents, users, waves, rootBlips, randoms, callback) =>
                @_notificateBlips(blips, parents, users, waves, rootBlips, randoms, (err, notificatedBlips) =>
                    return callback(err, null) if err
                    @_logger.info("Notificated #{notificatedBlips.length} blips", notificatedBlips)
                    callback(null)
                )
        ]
        async.waterfall(tasks, (err) =>
            @_logger.error(err) if err
            @_logger.info("Finished")
            callback(null)
        )

module.exports.CommentNotificator = new CommentNotificator()