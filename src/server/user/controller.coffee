_ = require('underscore')
async = require('async')

AutoAuth = require('../auth/model').AutoAuth
AuthCouchProcessor = require('../auth/couch_processor').AuthCouchProcessor
UserCouchProcessor = require('./couch_processor').UserCouchProcessor
WaveController = require('../wave/controller').WaveController
StoreItemCouchProcessor = require('../store/couch_processor').StoreItemCouchProcessor
AuthUtils = require('../auth/utils').AuthUtils

{
    ITEM_INSTALL_STATE_INSTALL
    ITEM_INSTALL_STATE_UNINSTALL
} = require('./constants')

ACTION_FULL_PROFILE_ACCESS = require('../wave/constants').ACTION_FULL_PROFILE_ACCESS

{
    PROFILE_FIELD_EMAIL
    PROFILE_FIELD_NAME
    PROFILE_FIELD_AVATAR
} = require('../../share/constants')

class UserController

    getMyProfile: (user, callback) ->
        UserCouchProcessor.getById(user.id, (err, user) ->
            callback(err, user.toObject())
        )

    getUsersInfo: (url, user, userIds, callback) ->
        tasks = [
            async.apply(WaveController.getWaveByUrl, url, user)
            (wave, callback) ->
                permittedIds = (id for id in userIds when wave.hasParticipantById(id))
                UserCouchProcessor.getByIdsAsDict(permittedIds, (err, users) ->
                    return callback(err) if err
                    err = wave.checkPermission(user, ACTION_FULL_PROFILE_ACCESS)
                    usersInfo = []
                    for own id, usr of users
                        infoItem = usr.toObject(not err)
                        infoItem.id = id
                        usersInfo.push(infoItem)
                    callback(null, usersInfo)
                )
        ]
        async.waterfall(tasks, callback)

    getUserAndProfile: (id, callback) =>
        ###
        Возвращает пользователя и профиль - данные из всех его авторизаций (имя, почта, юзерпик).
        @params id: string
        @params callback: function(err, user: UserModel, profile: object)
        ###
        @_getUserAndAuthList(id, (err, user, authList) =>
            return callback(err) if err
            @_getNotPresentedAuthList(user, authList, (err, notPresentedAuthList) ->
                authList = authList.concat(notPresentedAuthList) if not err
                profile = AuthUtils.convertAuthListToProfile(authList)
                callback(null, user, profile)
            )
        )

    _getNotPresentedAuthList: (user, authList, callback) ->
        ###
        Нужно для следующей ситуации:
        Есть 2 и более объединенных аккаунта, среди которых имеется, тот, через который зати не возможно (
        просто мыло). Т.к. механизм объединения был спроектирован так, что создаются только пользователи, а Auth-документы
        объединяются только имеющиеся в профиле мы видим не все данные. Этот код проверит совпадает ли список уникальных email-ов
        из Auth-документов со списком normalizedEmails у primary-пользователя (а он, по идее, должен содержать все адреса
        имеющие к юзеру хоть какое-то отношение). Если списки различаются, то недостающие Auth-документы досоздадутся.
        @param user: UserModel
        @param authList: array of Auth
        @param callback: function
        ###
        uniqEmails = []
        for auth in authList
            email = auth.getNormalizedEmail()
            uniqEmails.push(email) if email not in uniqEmails
        return callback(null, []) if user.normalizedEmails.length == uniqEmails.length
        onUsersGot = (err, mergedUsers) ->
            if err
                console.debug('Bug check. Error while getting merged users'. err)
                return callback(null, [])
            notPresentedAuthList = []
            for mergedUser in mergedUsers
                continue if mergedUser.getNormalizedEmail() in uniqEmails
                auth = new AutoAuth()
                auth.setUserId(user.id)
                auth.setEmail(mergedUser.email)
                auth.setUserCompilationParams([])
                notPresentedAuthList.push(auth)
            callback(null,notPresentedAuthList)
            AuthCouchProcessor.bulkSave(notPresentedAuthList, (err) ->
                console.warn('Bug check. Error while saving not presented auth list', err) if err
            )
        UserCouchProcessor.getByIds(user.getAlternativeIds(), onUsersGot, true)

    changeProfile: (user, email, name, avatar, callback) ->
        ###
        Изменяет профиль пользователя.
        @param user:UserModel
        @param email, name, avatar: string - id авторизации из которой нужно взять соответствующее поле профиля.
        @param callback: function(err, UserModel)
        ###
        isAuthIdExist = (auths, id) ->
            for auth in auths
                return true if auth.getId() is id
            return false
        getAuthIdByField = (auths, field) ->
            for auth in auths
                return auth.getId() if field in auth.getUserCompilationParams()
            return null
        tasks = [
            async.apply(@_getUserAndAuthList, user.id)
            (user, authList, callback) ->
                fields = [PROFILE_FIELD_EMAIL, PROFILE_FIELD_NAME, PROFILE_FIELD_AVATAR]
                fieldsByAuthId = {}
                for authId, i in [email, name, avatar]
                    field = fields[i]
                    authId = getAuthIdByField(authList, field) if not isAuthIdExist(authList, authId)
                    fieldsByAuthId[authId] ||= []
                    fieldsByAuthId[authId].push(field)
                action = (auth, callback) ->
                    params = fieldsByAuthId[auth.getId()] or []
                    auth.setUserCompilationParams(params)
                    callback(null, true, auth, false)
                AuthCouchProcessor.bulkSaveResolvingConflicts(authList, action, (err) ->
                    callback(err, user, authList)
                )
            (user, authList, callback) ->
                action = (user, callback) ->
                    auth.updateUser(user) for auth in authList
                    callback(null, true, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, (err) ->
                    callback(err, user)
                )
        ]
        async.waterfall(tasks, (err, user) ->
            callback(err, if err then null else user.toObject(true))
        )

    _getUserAndAuthList: (id, callback) =>
        tasks = [
            async.apply(UserCouchProcessor.getById, id)
            async.apply(AuthCouchProcessor.getByUserId, id)
        ]
        async.parallel(tasks, (err, result) ->
            callback(err, result...)
        )

    processPing: (id, callback) ->
        ###
        Обрабатывает ping от клиента
        @params id: string
        @params callback: function
        ###
        tasks = [
            async.apply(UserCouchProcessor.getById, id)
            (user, callback) ->
                action = (user, callback) ->
                    user.updateLastActivity()
                    callback(null, true, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, callback)
        ]
        async.waterfall(tasks, callback)

    _saveUserField: (user, action, callback) ->
        ###
        Делает что-нибудь в action с пользователем и сохраняет в бд результат
        ###
        return callback(new Error('User is anonymous'), null) if user.isAnonymous()
        tasks = [
            (callback) ->
                UserCouchProcessor.getById(user.id, callback)
            (user, callback) ->
                UserCouchProcessor.saveResolvingConflicts(user, action, callback)
        ]
        async.waterfall(tasks, callback)

    setUserSkypeId: (user, skypeId, callback) ->
        ###
        Устанавливает пользователю skype
        ###
        action = (model, callback) ->
            model.skypeId = skypeId
            callback(null, true, model, false)
        @_saveUserField(user, action, callback)

    setUserClientOption: (user, optName, optValue, callback) ->
        ###
        Устанавливает пользователю клиентскую настройку
        ###
        action = (model, callback) ->
            model.setClientOption(optName, optValue)
            callback(null, true, model, false)
        @_saveUserField(user, action, callback)


    changeItemInstallState: (user, itemId, state, callback) ->
        ###
        Инсталлирует/деинсталлирует позицию пользователю.
        @param user: UserModel
        @param itemId: string
        @param state: int
        @param callback: function
        ###
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                StoreItemCouchProcessor.getById(itemId, (err, item) ->
                    callback(err, user, item)
                )
            (user, item, callback) ->
                action = (user, item, callback) ->
                    changed = false
                    changed = user.installStoreItem(item) if state == ITEM_INSTALL_STATE_INSTALL
                    changed = user.uninstallStoreItem(item) if state == ITEM_INSTALL_STATE_UNINSTALL
                    callback(null, changed, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, item, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err)
        )

    giveBonus: (user, bonusType, callback) ->
        ###
        Добавляет пользователю бонус определенного типа.
        @param user: UserModel
        @param bonusType: int
        @param callback: function
        ###
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                action = (user, bonusType, callback) ->
                    [err, changed] = user.giveBonus(bonusType)
                    callback(err, changed, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, bonusType, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err)
        )

module.exports.UserController = new UserController()
