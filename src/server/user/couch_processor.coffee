_ = require('underscore')
async = require('async')
CouchProcessor = require('../common/db/couch_processor').CouchProcessor
UserCouchConverter = require('./couch_converter').UserCouchConverter
UserGenerator = require('./generator').UserGenerator
UserUtils = require('./utils').UserUtils
isEmail = require('../../share/utils/string').isEmail
UserModel = require('./model').UserModel
Anonymous = require('./anonymous')
InvalidEmail = require('./exceptions').InvalidEmail

CREATION_REASON_AUTH = require('./constants').CREATION_REASON_AUTH
PACK_SIZE = 1000

class UserCouchProcessor extends CouchProcessor
    ###
    Класс, представляющий couch processor для модели пользователя.
    ###
    constructor: () ->
        super()
        @converter = UserCouchConverter
        @_cache = @_conf.getCache('user')

    getByIdsAsDict: (ids, callback, includeMerged=false, disableIdMasking=false, args...) ->
        ###
        Load users by their ids.
        Returns object { user_id: user object, ... }
        Id of either primary or merged user account allowed. Rules are:
        1. for ids of primary account returns { user_primary_id: primary user object }
        2. for ids of merged account returns:
        2.1. includeMerged=true - { user_merged_id: merged user object }
        2.2. includeMerged=false, disableIdMasking=false - { user_primary_id: primary user object }
        2.2. includeMerged=false, disableIdMasking=true - { user_merged_id: primary user object }
        @param ids: array
        @param callback: function
        @param includeMerged: bool - @see: @_getByIdsAsDictIncludeMerged/@_getByIdsAsDictOnlyPrimary
        @param disableIdMasking: bool - @see @_getByIdsAsDictOnlyPrimary, used only if includeMerged==false
        ###
        ids = _.compact(ids)
        includeAnonymous = false
        #Анонимуса в базе нет, исключим, потом добавим
        if Anonymous.inList(ids)
            ids = _.without(ids, Anonymous.id)
            includeAnonymous = true
        onUsersGot = (err, users) ->
            return callback(err) if err
            users[Anonymous.id] = Anonymous if includeAnonymous
            callback(null, users)
        getFunction = if includeMerged then @_getByIdsAsDictIncludeMerged else @_getByIdsAsDictOnlyPrimary
        getFunction(ids, onUsersGot, disableIdMasking, args...)

    _getByIdsAsDictIncludeMerged: (ids, callback, disableIdMasking, args...) =>
        ###
        Просто вернет пользователей по id, независимо от merged или primaty.
        ###
        @_callParentGetByIdsAsDict(ids, callback, args...)

    _getByIdsAsDictOnlyPrimary: (ids, callback, disableIdMasking, args...) =>
        ###
        Вернет только primary пользователей, если передан id merged пользователя, то загрузит его primary.
        ###
        onUsersGot = (err, users) =>
            return callback(err) if err
            allUsers = {}
            mergedByPrimary = {}
            for own id, user of users
                if user.isMerged()
                    primaryId = user.getPrimaryId()
                    continue if not primaryId
                    mergedByPrimary[primaryId] = id
                    continue
                allUsers[id] = user
            return callback(null, allUsers) if _.isEmpty(mergedByPrimary)
            onPrimaryUsersGot = (err, users) ->
                return callback(err) if err
                for own id, user of users
                    mergedId = mergedByPrimary[id]
                    continue if not mergedId
                    #Добавим primary к результату, по id его merged- либо primary-пользователя
                    hashKey = if disableIdMasking then mergedId else user.id
                    allUsers[hashKey] = user
                callback(null, allUsers)
            #Загрузим primary-пользователь для merged-пользователей
            @_callParentGetByIdsAsDict(_.keys(mergedByPrimary), onPrimaryUsersGot, args...)
        #на прямую обращаемся к родительскому классу.
        @_callParentGetByIdsAsDict(ids, onUsersGot, args...)

    _callParentGetByIdsAsDict: (args...) ->
        UserCouchProcessor.__super__.getByIdsAsDict.apply(@, args)

    getOrCreateByAuth: (auth, callback) ->
        ###
        Загружает пользователя по Auth, id
        @param uath: AuthModel
        @param callback(err, user: UserModel, isAuthUserIdChanged: bool) - третий параметр говорит о том, что авторизация изменилась
        и неплохо бы ее сохранить.
        ###
        byId = () =>
            #Пользователь к нам уже приходил, к нему привязана авторизация
            @getById(auth.getUserId(), (err, user) ->
                if err
                    console.warn("Bug check. Error #{err} while getting user #{auth.getUserId()} for auth #{auth.getId()}")
                callback(err, user)
            )
        byEmail = () =>
            #Пользователь не приходил, авторизация создана только что и не привязана
            @getOrCreateByEmail(auth.getEmail(), CREATION_REASON_AUTH, (err, user) ->
                #Get будет если пользователя создали при, например, добавлении в топик. Create, если сам пришел.
                return callback(err) if err
                auth.setUserId(user.id)
                callback(err, user, true)
            )
        if auth.isUserSpecified() then byId() else byEmail()

    getByEmail: (email, callback) =>
        ###
        Возвращает пользователя по его почте. Одна почта - один пользователь,
        иначе ошибка.
        @param email: string
        @param callback: function
        ###
        email = UserUtils.normalizeEmail(email)
        return callback(new InvalidEmail(email), null) if not isEmail(email)
        viewParams = {key: email}
        @getOne('user_by_email_1/get', viewParams, callback)

    getByNotificationId: (notificationId, callback) =>
        ###
        Возвращает пользователя по его notificationId. Один id - один пользователь,
        иначе ошибка.
        @param email: string
        @param callback: function
        ###
        viewParams = {
            key: notificationId
        }
        @getOne('user_by_notification_id/get', viewParams, callback)

    getByEmails: (emails, callback) =>
        ###
        Загружает указанных пользователей по email
        @param emails: array
        @returns: object - {email1: user1, email2: user2}
        ###
        normalizedEmails = (UserUtils.normalizeEmail(email) for email in emails when isEmail(email))
        @viewWithIncludeDocs('user_by_email_1/get', {keys: _.uniq(normalizedEmails)}, (err, users) =>
            return callback(err, null) if err
            usersByEmail = {}
            for user in users
                for email in user.normalizedEmails
                    continue if email not in normalizedEmails
                    @_logger.warn("Duplicate users detected in getByEmails: #{email}") if usersByEmail[email]
                    usersByEmail[email] = user
            callback(null, usersByEmail)
        )

    _testFilter: (user, filter) ->
        ###
        Проверяет подходит ли пользователь под фильтр активности
        @param filter: string - active|inactive|all
        ###
        return true if filter == 'all'
        return not user.firstVisit if filter == 'inactive'
        return not not user.firstVisit if filter == 'active'

    getAllByFilter: (filter='active', callback) ->
        ###
        Достает всех пользователей, подходящих под фильтр активности
        @param filter: string - active|inactive|all
        ###
        emails = {}
        filteredUsers = []
        processPack = (users, callback) =>
            for user in users
                continue if not @_testFilter(user, filter)
                email = user.normalizedEmail
                if emails[email]
                    @_logger.warn("Duplicate users detected in getAllByFilter: #{email}")
                    continue
                filteredUsers.push(user)
                emails[email] = email
            callback()
        @viewWithIncludeDocsPacks('user_by_email_1/get', processPack, (err, users) ->
            return callback(err, null) if err
            callback(null, filteredUsers)
        )

    viewWithIncludeDocsPacks: (view, processPack, finish) ->
        @view view, {}, (err, res) =>
            return finish(err) if err
            userIds = {}
            for row in res
                userIds[row.id] = row.id
            userIds = _.keys(userIds)
            @_logger.info("Totally #{userIds.length} users to analyze")
            packStart = 0
            test = -> packStart < userIds.length
            getAndProcessPack = (callback) =>
                ids = userIds[packStart...packStart+PACK_SIZE]
                @_logger.info("Processing  #{packStart} - #{packStart + ids.length} of #{userIds.length}")
                @getByIds ids, (err, models) ->
                    return callback(err) if err
                    processPack models, (err) ->
                        # nextTick, чтобы разорвать call stack
                        process.nextTick(async.apply(callback, err))
                packStart += PACK_SIZE
            async.whilst test, getAndProcessPack, finish

    getOrCreateByEmail: (email, creationReason, callback) =>
        ###
        Загружает пользователя по email
        Если пользователь не найден создает его
        @param email: string
        @param creationReason: string - причина создания пользователя
        @callback: function
        ###
        email = UserUtils.normalizeEmail(email)
        return callback(new InvalidEmail(email)) if not isEmail(email)
        @getOrCreateByEmails([email], creationReason, (err, users) ->
            return callback(err, null) if err
            callback(null, users[email])
        )

    getOrCreateByEmails: (emails, creationReason, callback) =>
        ###
        Загружает указанных пользователей из бд по email
        Если пользователь не найден создает его
        @param emails: Array
        @param creationReason: string - причина создания пользователя
        @param callback: function
            err: Error
            object: {email1: UserModel, ...}
        ###
        tasks = [
            (callback) =>
                @getByEmails(emails, (err, users) ->
                    return callback(err, null) if err
                    toCreate = []
                    for email in emails
                        normalizedEmail = UserUtils.normalizeEmail(email)
                        continue if users[normalizedEmail]
                        toCreate.push(email)
                    callback(null, users, toCreate)
                )
            (users, toCreate, callback) =>
                return callback(null, users) if not toCreate.length
                @createByEmails(toCreate, creationReason, (err, createdUsers) ->
                    return callback(err, null) if err
                    for own email, user of createdUsers when user
                        users[email] = user
                    callback(null, users)
                )
        ]
        async.waterfall(tasks, callback)

    createByEmail: (email, creationReason, callback) ->
        ###
        Создает пользователя по email'у.
        @param email: string
        @param creationReason: string - причина создания пользователя
        @param callback: function
        ###
        return callback(new InvalidEmail(email)) if not isEmail(email)
        @createByEmails([email], creationReason, callback)

    createByEmails: (emails, creationReason, callback) =>
        ###
        Создает пользователей по списку email'ов.
        @param emails: Array
        @param creationReason: string - причина создания пользователя
        @param callback: function
        ###
        emails = _.uniq(emails)
        UserGenerator.getNextRange(emails.length, (err, ids) =>
            usersByEmail = {}
            for id, count in ids
                email = emails[count]
                user = @_createUserInstance(id, email, creationReason)
                usersByEmail[email] = user if user
            @bulkSave(_.values(usersByEmail), (err) ->
                callback(err, if err then null else usersByEmail)
            )
        )

    _createUserInstance: (id, email, creationReason) ->
        ###
        Возвращает частично заполненную модель пользователя.
        @param id: string
        @param email: string
        @param creationReason: string
        @returns UserModel
        ###
        return if not isEmail(email)
        normalizedEmail = UserUtils.normalizeEmail(email)
        user = new UserModel(id)
        user.setEmail(email.trim())
        user.setCreationCondition(creationReason)
        return user

    getByDigestDate: (toDate, limit, digestType, callback) ->
        ###
        Возвращает список пользователей, у которых время предыдущего входа и время предыдущей отправки дайджеста
        раньше, чем toDate. Т.е. пользователей, которым надо отправлять дайджест с изменениями.
        @param toDate: timestamp in sec
        @param callback: function
        ###
        params =
            startkey: [digestType, @MINUS_INF]
            endkey: [digestType, toDate]
        params.limit = limit if limit
        @viewWithIncludeDocsAsDict('user_by_digest_3/get', params, callback)

    getByFirstVisitNotNotificated: (fromDate, toDate, limit, callback) ->
        ###
        Возвращает список пользователей, у которых время предыдущего входа и время предыдущей отправки дайджеста
        раньше, чем toDate. Т.е. пользователей, которым надо отправлять дайджест с изменениями.
        @param toDate: timestamp in sec
        @param callback: function
        ###
        params =
            startkey: [false, fromDate]
            endkey: [false, toDate]
        params.limit = limit if limit
        @viewWithIncludeDocsAsDict('user_by_first_visit/get', params, callback)

module.exports.UserCouchProcessor = new UserCouchProcessor()
