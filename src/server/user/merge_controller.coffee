_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
AuthCouchProcessor = require('../auth/couch_processor').AuthCouchProcessor
UserCouchProcessor = require('./couch_processor').UserCouchProcessor
ContactsController = require('../contacts/controller').ContactsController
isEmail = require('../../share/utils/string').isEmail
DateUtils = require('../utils/date_utils').DateUtils

CREATION_REASON_MERGE = require('./constants').CREATION_REASON_MERGE

DELIMITER = require('./constants').MERGE_DIGEST_DELIMITER
CODE_VALIDITY_PERIOD = 60 * 60 * 48 #Код действует 48 часов.

{
    MergeError
    INVALID_CODE_FORMAT
    INVALID_USER
    INVALID_CODE
    MERGING_NOT_REQUESTED
    CODE_IS_DELAYED
} = require('./exceptions')

class MergeController
    constructor: () ->
        @_logger = Conf.getLogger('merge-controller')

    mergeByOauth: (user, session, code, callback) ->
        mergingValidationData = session.mergingValidationData
        delete session.mergingValidationData
        return callback(new MergeError('Merging not requested', MERGING_NOT_REQUESTED)) if not mergingValidationData
        return callback(new MergeError('Invalid code', INVALID_CODE)) if mergingValidationData.code != code
        UserCouchProcessor.getById(mergingValidationData.userId, (err, user) =>
            @mergeByEmails(user, mergingValidationData.emailsToMerge, (err, user) ->
                callback(err, if err then null else user.toObject(true))
            )
        )

    mergeByEmails: (primaryUser, emailsToMerge, callback, skipPrimarySaving) ->
        ###
        @param primaryUser: UserModel
        @param emailToMerge: array
        @param callback: function
        ###
        UserCouchProcessor.getOrCreateByEmails(emailsToMerge, CREATION_REASON_MERGE, (err, usersToMergeByEmail) =>
            return callback(err) if err
            uniqueUsersToMerge = []
            uniqueUsersToMerge.push(user) for user in _.values(usersToMergeByEmail) when not user.inList(uniqueUsersToMerge)
            @_merge(primaryUser, uniqueUsersToMerge, callback, skipPrimarySaving)
        )

    _merge: (primaryUser, usersToMerge, callback, skipPrimarySaving=false) ->
        return callback() if not usersToMerge.length
        uniqUsersToMerge = (user for user in usersToMerge when not (primaryUser.isEqual(user)))
        return callback(new MergeError('Already merged')) if not uniqUsersToMerge.length
        tasks = [
            (callback) ->
                #Если хотим присоединить primary-юзеров, то нужно что бы их merged указывали на нового primary.
                alreadyMergedIds = (user.getAlternativeIds() for user in uniqUsersToMerge when user.isPrimary())
                onAlreadyMergedUsers = (err, alreadyMergedUsers) ->
                    return callback(err) if err
                    uniqUsersToMerge = uniqUsersToMerge.concat(alreadyMergedUsers)
                    callback(null)
                UserCouchProcessor.getByIds([].concat(alreadyMergedIds...), onAlreadyMergedUsers, true)
            (callback) =>
                @_mergeAccaunts(primaryUser, uniqUsersToMerge)
                @_mergeAuth(primaryUser, uniqUsersToMerge, (err) ->
                    callback(err, primaryUser, uniqUsersToMerge)
                )
            (primaryUser, usersToMerge, callback) =>
                @_mergeContacts(primaryUser, usersToMerge, (err) ->
                    callback(err, primaryUser, usersToMerge)
                )
            (primaryUser, mergedUsers, callback) =>
                users = if skipPrimarySaving then mergedUsers else mergedUsers.concat([primaryUser])
                UserCouchProcessor.bulkSave(users, (err) ->
                    callback(err, primaryUser)
                )
        ]
        async.waterfall(tasks, (err, primaryUser) =>
            @_logMergeResult(err, primaryUser, uniqUsersToMerge)
            callback(err, primaryUser)
        )

    _logMergeResult: (err, primaryUser, mergedUsers) ->
        ids = []
        logObject = {}
        for user in [primaryUser].concat(mergedUsers)
            id = user.id
            ids.push(id)
            logObject[id] = {emails: user.normalizedEmails}
        if err
            @_logger.error("Error while merging #{err}. Accounts: #{ids}", logObject)
        else
            @_logger.debug("Accounts merged successfully: #{ids}", logObject)

    _mergeAccaunts: (primaryUser, usersToMerge) ->
        primaryUserId = primaryUser.id
        user.makeMerged(primaryUserId) for user in usersToMerge
        primaryUser.makePrimary(usersToMerge)

    _mergeAuth: (primaryUser, usersToMerge, callback) ->
        ###
        Все авторизации будут указывать на primary-пользователя.
        @param primaryUser: UserModel
        @param usersToMerge: array
        @param callback: function
        ###
        tasks = [
            (callback) ->
                ids = (user.id for user in usersToMerge)
                AuthCouchProcessor.getByUserIds(ids, (err, authList) ->
                    return callback(err) if err
                    for auth in authList
                        auth.setUserId(primaryUser.id)
                        #Когда сделаем выбор из какой авторизации что брать нужно будет заполнять массив
                        auth.setUserCompilationParams([])
                        auth.updateUser(primaryUser)
                    callback(null, authList)
                )
            (authLits, callback) ->
                AuthCouchProcessor.bulkSave(authLits, callback)
        ]
        async.waterfall(tasks, callback)

    _mergeContacts: (primaryUser, usersToMerge, callback) ->
        ###
        Добавляет в контакты к primary-пользователю контакты объединяемых с ним.
        @param primaryUser: UserModel
        @param mergedUsers: arrya of UserModel
        @param callback: function
        ###
        ContactsController.mergeContacts(primaryUser, usersToMerge, callback)

    mergeByDigest: (user, digest, callback) ->
        ###
        Объединяет аккаунты на основе дайджеста из письма-подтверждения.
        @see app_roles/web_accounts_merge
        @param user: UserModel
        @param digest: string - ссылка из письма-подтверждения.
        ###
        tasks = [
            async.apply(@_getUsersFromDigest, user, digest)
            (primaryUser, emailToMerge, userToMerge, callback) =>
                if userToMerge
                    @_merge(primaryUser, [userToMerge], callback)
                else
                    @mergeByEmails(primaryUser, [emailToMerge], callback)
        ]
        async.waterfall(tasks, callback)

    _getUsersFromDigest: (user, digest, callback) =>
        ###
        @param user: UserModel - это пользователь от кого поступил запрос, должен быть равен primary, но возможно и merged пользователю
        @param digest: string
        @param callback: function(err, primaryUser: UserModel, emailToMerge: string,  userToMerge: UserModel) -
        3 параметр опциональный, будет возвращаен, если по ссылке пришел пользователь обозначенай, как mergeed
        ###
        return callback(new MergeError('Invalid code format', INVALID_CODE_FORMAT)) if not digest
        [primaryId, emailToMerge, code] = (new Buffer(digest, 'base64').toString('ascii')).split(DELIMITER)
        if not (primaryId and emailToMerge and code and isEmail(emailToMerge))
            return callback(new MergeError('Invalid code format', INVALID_CODE_FORMAT))
        id = user.id
        UserCouchProcessor.getByIdsAsDict([primaryId, id], (err, users) ->
            primaryUser = users[primaryId]
            user = users[id]
            return callback(new MergeError('Invalid code format', INVALID_CODE_FORMAT)) if not (primaryUser and user)
            #Пришел непонятно кто
            if not (user.isEqual(primaryUser) or user.isMyEmail(emailToMerge))
                return callback(new MergeError('Invalid user', INVALID_USER))
            mergingValidationData = primaryUser.mergingValidationData[emailToMerge]
            #Нет данных о том, что запрашивалось объединение
            return callback(new MergeError('Merging not requested', MERGING_NOT_REQUESTED)) if not mergingValidationData
            delete primaryUser.mergingValidationData[emailToMerge]
            return callback(new MergeError('Invalid code', INVALID_CODE)) if mergingValidationData.code != code
            isCodeDelayed = DateUtils.getCurrentTimestamp() - mergingValidationData.sendaDate > CODE_VALIDITY_PERIOD
            return callback(new MergeError('Code is delayed', CODE_IS_DELAYED)) if isCodeDelayed
            callback(null, primaryUser, emailToMerge, if user.isMyEmail(emailToMerge) then user else null)
        )

module.exports.MergeController = new MergeController()
