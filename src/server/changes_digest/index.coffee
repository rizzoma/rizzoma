_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
DateUtils = require('../utils/date_utils').DateUtils
Query = require('../common/query').Query
SearchController = new (require('../search/controller').SearchController)()
Ptag = require('../ptag').Ptag
CouchWaveProcessor = require('../wave/couch_processor').CouchWaveProcessor
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
Notificator = require('../notification').Notificator
USER_DENY_NOTIFICATION = require('../notification/exceptions').USER_DENY_NOTIFICATION
{SHARED_STATES} = require('../wave/constants')

class ChangesDigestNotificator
    constructor: () ->
        @RUNNING_DELTA = 60 * 60 * 6 # погрешность запуска скрипта, чтобы не пропустить изменения
        @DIGEST_PERIOD = 60 * 60 * 24 * 7 # неделя
        @USER_CHANGES_LIMIT = 5 # сколько изменений для одного пользователя в одном письме
        @DIGEST_USERS_LIMIT = 1000 # скольким пользователям высылаем дайджест за 1 запуск
        @MAX_CONTRIBUTORS_SHOW = 5 # сколько контрибутров показывать для блипа
        @MAX_TITLE_LENGTH = 100
        @MAX_CHANGED_TEXT_LENGTH = 30
        @_logger = Conf.getLogger('digest')
        @_now = DateUtils.getCurrentTimestamp()
        @DIGEST_TYPE = null

    _getUserChangesMinTimestamp: (user) ->
        ###
        Возвращает таймстэмп ранее которго изменения для пользователя не берутся
        ###
        return Math.max(@_now - @DIGEST_PERIOD - @RUNNING_DELTA, user.lastDigestSent or 0)

    _processSearchResult: (results, users, callback) ->
        changes = {}
        for result in results
            waveId = result.wave_id
            contentTimestamp = result.content_timestamp
            for ptag in result.ptags.split(',')
                [userId, ptag] = Ptag.parseSearchPtagId(ptag)
                user = users[userId]
                continue if not user
                # отсеим лишниие изменения
                continue if contentTimestamp < @_getUserChangesMinTimestamp(user)
                changes[userId] ?= {}
                if not changes[userId][waveId] or changes[userId][waveId].content_timestamp > contentTimestamp
                    changes[userId][waveId] = result
        callback(null, changes)

    _getChangesByUsers: (users, callback) ->
        ###
        Загружает изменения для пользователей
        ###
        query = new Query()
            .select(['content_timestamp', 'shared_state', 'blip_id', 'wave_id', 'wave_url', 'ptags'])
            .addPtagsFilter(_.values(users), ["FOLLOW"])
            .addAndFilter("content_timestamp between #{@_now - @DIGEST_PERIOD - @RUNNING_DELTA} and #{@_now}")
            .orderBy(['shared_state', 'content_timestamp'])
        SearchController.executeQueryWithoutPostprocessing(query, (err, results) =>
            return callback(err) if err
            @_processSearchResult(results, users, callback)
        )

    _getUserChangesLimit: (changesLength) ->
        ###
        Возвращает лимит изменений в зависимости от их общего кол-ва
        ###
        return if changesLength - @USER_CHANGES_LIMIT == 1 then @USER_CHANGES_LIMIT + 1 else @USER_CHANGES_LIMIT

    _prepareStructuresForLoadingData: (changes) ->
        ###
        Подготавливает данные для загрузки из бд, а также для удобного посылания писем
        ###
        digests = {}
        waveIds = []
        blipIds = []
        for userId, userChanges of changes
            userChanges = _.values(userChanges)
            userChanges = userChanges.sort((a, b) ->
                # сортируем сначала все непубличные, затем по времени в обратном порядке
                aSharedWeight = if a.shared_state != SHARED_STATES.SHARED_STATE_PUBLIC then 1 else 0
                bSharedWeight = if b.shared_state != SHARED_STATES.SHARED_STATE_PUBLIC then 1 else 0
                weightRazn = bSharedWeight - aSharedWeight
                return weightRazn if weightRazn != 0
                return b.content_timestamp - a.content_timestamp
            )
            digests[userId] = userChanges
            userChangesLimit = @_getUserChangesLimit(userChanges.length)
            for change, i in userChanges
                # будем загружать блипы и волны только для первых USER_CHANGES_LIMIT изменений
                break if i >= userChangesLimit
                waveIds.push(change.wave_id)
                blipIds.push(change.blip_id)
        return [digests, waveIds, blipIds]

    _getUsersForDigest: (callback) ->
        ###
        Достаем пользователей которые не активны неделю и им не рассылали еще письма
        ###
        now = DateUtils.getCurrentTimestamp()
        UserCouchProcessor.getByDigestDate(now - @DIGEST_PERIOD, @DIGEST_USERS_LIMIT, @DIGEST_TYPE, callback)

    _getMaxContributorsShow: (contributorsLength) ->
        return if contributorsLength - @MAX_CONTRIBUTORS_SHOW == 1 then @MAX_CONTRIBUTORS_SHOW + 1 else @MAX_CONTRIBUTORS_SHOW

    _getNotificationContext: (userId, changes, waves, blips, contributors) ->
        digest = []
        userChangesLimit = @_getUserChangesLimit(changes.length)
        for change, i in changes
            # будем выводить только для первых USER_CHANGES_LIMIT изменений
            break if i >= userChangesLimit
            wave = waves[change.wave_id]
            rootBlip = blips[wave.rootBlipId]
            changedBlip = blips[change.blip_id]
            clength = changedBlip.contributors.length
            allContributorsCount = 0
            ctbrs = []
            for c in changedBlip.contributors when c.id != userId or clength == 1
                allContributorsCount++
            maxContributorsShow = @_getMaxContributorsShow(allContributorsCount)
            for c in changedBlip.contributors when c.id != userId or clength == 1
                ctbrs.push(contributors[c.id])
                break if ctbrs.length >= maxContributorsShow
            title = rootBlip.getTitle()
            title = title[0..@MAX_TITLE_LENGTH] + '…' if title.length > @MAX_TITLE_LENGTH
            otherContributorsCount = allContributorsCount - maxContributorsShow
            otherContributorsCount = 0 if otherContributorsCount < 0
            digest.push({
                waveUrl: change.wave_url
                title: title
                contributors: ctbrs
                otherContributorsCount: otherContributorsCount
                blipId: change.blip_id
            })
        otherChangesCount = if changes.length > userChangesLimit then changes.length - userChangesLimit else 0
        context =
            digest: digest
            otherChangesCount: otherChangesCount
        return context

    _notificateUsers: (users, digests, waves, blips, contributors, callback) ->
        return callback(null, {}) if _.isEmpty(digests)
        notifications = []
        for userId, changes of digests
            context = @_getNotificationContext(userId, changes, waves, blips, contributors)
            user = users[userId]
            if not user
                @_logger.warn("Bugcheck. User not found. UserId: #{userId}")
                continue
            if not context.digest.length
                @_logger.warn('Bugcheck. Notification with no changes detected. User:', user)
                continue
            notifications.push({user, context})
        @_logger.info("To send notifications #{notifications.length} users")
        Notificator.notificateUsers(notifications, "#{@DIGEST_TYPE}_changes_digest", (err, errState) ->
            return callback(err, null) if err
            errs = {}
            for err, i in errState
                errs[notifications[i].user.id] = err
            callback(null, errs)
        )

    _saveLastDigestSent: (users, callback) ->
        action = (model, callback) ->
            model.lastDigestSent = DateUtils.getCurrentTimestamp()
            callback(null, true, model, false)
        UserCouchProcessor.bulkSaveResolvingConflicts(users, action, callback)


    _notificateUsersAndSaveLastDigestSent: (users, digests, waves, blips, contributors, callback) ->
        tasks = [
            (callback) =>
                @_saveLastDigestSent(_.values(users), (err, res) =>
                    return callback(err) if err
                    updatedUsers = []
                    usersToNotificate = {}
                    for userId, row of res
                        if not row.error
                            updatedUsers.push(userId)
                            usersToNotificate[userId] = users[userId]
                        else
                            @_logger.error(row.error)
                    @_logger.info("Succesfully updated lastDigestSent #{updatedUsers.length} users: #{updatedUsers.join(', ')}")
                    callback(null, usersToNotificate)
                )
            (usersToNotificate, callback) =>
                @_notificateUsers(usersToNotificate, digests, waves, blips, contributors, (err, errState) =>
                    return callback(err, null) if err
                    notificatedUsers = []
                    for own userId, user of usersToNotificate
                        err = errState[userId]
                        if err and err.code != USER_DENY_NOTIFICATION
                            @_logger.error(err)
                        else
                            notificatedUsers.push(userId)
                    @_logger.info("Succesfully notificated #{notificatedUsers.length} users: #{notificatedUsers.join(', ')}")
                    callback(null)
                )
        ]
        async.waterfall(tasks, callback)

    _getContributors: (digests, blips, users, callback) ->
        ###
        Згружает пользователей контрибуторов измененных блипов и добавляет их в общий объект пользователей
        ###
        contributorIds = {}
        contributors = {}
        for userId, changes of digests
            userChangesLimit = @_getUserChangesLimit(changes.length)
            for change, i in changes
                # будем загружать контрибуторов только для первых USER_CHANGES_LIMIT изменений
                break if i >= userChangesLimit
                blip = blips[change.blip_id]
                for contributor in blip.contributors
                    if not users[contributor.id]
                        contributorIds[contributor.id] = contributor.id
                    else
                        contributors[contributor.id] = users[contributor.id]
        contributorIds = _.keys(contributorIds)
        return callback(null, contributors) if not contributorIds.length
        UserCouchProcessor.getByIdsAsDict(contributorIds, (err, loadedContributors) ->
            return callback(err) if err
            contributors = _.extend(contributors, loadedContributors)
            callback(null, contributors)
        )

    run: (callback) ->
        ###
        users = SELECT * FROM user WHERE lastVisitTime < now - week AND digestSentTime < now - week
        changes = SELECT DISTINCT userId, topic, lastChangedBlip, lastChangeAuthor
                    FROM topics and blips
                    WHERE userIds IN userIds
                    AND topic.participants.length < 30
                    AND blip.contentTimestamp > now - week
        for user in users
            userCahnges = changes[user.id]
            sendDigest(user, userCahnges)
            saveUserDigestSentTime(user)
        ###
        @_logger.info('Started')
        Notificator.initTransports()
        tasks = [
            (callback) =>
                @_getUsersForDigest((err, users) =>
                    @_logger.info("Loaded #{_.values(users).length} users for digest") if not err
                    callback(err, users)
                )
            (users, callback) =>
                return callback('no_users') if _.isEmpty(users)
                @_getChangesByUsers(users, (err, changes) =>
                    @_logger.info("Loaded changes for #{_.values(changes).length} users") if not err
                    callback(err, users, changes)
                )
            (users, changes, callback) =>
                [digests, waveIds, blipIds] = @_prepareStructuresForLoadingData(changes)
                return callback(null, users, digests, {}, blipIds) if not waveIds.length
                CouchWaveProcessor.getByIdsAsDict(waveIds, (err, waves) =>
                    return callback(err, null) if err
                    @_logger.info("Loaded waves #{_.values(waves).length}")
                    callback(null, users, digests, waves, blipIds)
                )
            (users, digests, waves, blipIds, callback) =>
                for waveId, wave of waves
                    blipIds.push(wave.rootBlipId)
                blipIds = _.uniq(blipIds)
                return callback(null, users, digests, waves, {}) if not blipIds.length
                CouchBlipProcessor.getByIdsAsDict(blipIds, (err, blips) =>
                    return callback(err, null) if err
                    @_logger.info("Loaded blips #{_.values(blips).length}")
                    callback(null, users, digests, waves, blips)
                )
            (users, digests, waves, blips, callback) =>
                @_getContributors(digests, blips, users, (err, contributors) =>
                    return callback(err, null) if err
                    @_logger.info("Loaded contributors #{_.values(contributors).length}")
                    callback(null, users, digests, waves, blips, contributors)
                )
            (users, digests, waves, blips, contributors, callback) =>
                @_notificateUsersAndSaveLastDigestSent(users, digests, waves, blips, contributors, callback)
        ]
        async.waterfall(tasks, (err) =>
            Notificator.closeTransports()
            if err
                if err == 'no_users'
                    err = null
                else
                    @_logger.error(err)
            @_logger.info('Finished')
            callback?(err)
        )

class WeeklyChangesDigestNotificator extends ChangesDigestNotificator
    constructor: () ->
        super()
        @DIGEST_PERIOD = 60 * 60 * 24 * 7 # неделя
        @DIGEST_TYPE = "weekly"

class DailyChangesDigestNotificator extends ChangesDigestNotificator
    constructor: () ->
        super()
        @DIGEST_PERIOD = 60 * 60 * 24 # сутки
        @DIGEST_TYPE = "daily"

module.exports =
    WeeklyChangesDigestNotificator: new WeeklyChangesDigestNotificator()
    DailyChangesDigestNotificator: new DailyChangesDigestNotificator()
    ChangesDigestNotificator: ChangesDigestNotificator
