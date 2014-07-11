_ = require('underscore')
passport = require('passport')
Anonymous = require('../user/anonymous')
sessionConf = require('../conf').Conf.getSessionConf()
UserModel = require('../user/model').UserModel

KEY = passport._key
USER_FIELD_NAME = passport._userProperty or 'user'

class AuthUtils
    ###
    Вспомогательный класс для авторизации по токену.
    ###
    authByToken: (token, callback) ->
        ###
        Если пользователь не авторизован вернет Anonymous.
        @param token: string
        @param callback: function(err, user: UserModel, session: Object)
        ###
        sessionConf.store.get(token, (err, session) =>
            if err
                console.warn("Session store err: #{err}")
                return callback(null, Anonymous, {})
            return callback(null, Anonymous, {}) if not session
            userKey = session[KEY]?[USER_FIELD_NAME]
            return callback(null, Anonymous, {}) if not userKey
            user = @getUserBySessionData(userKey)
            callback(null, user, session)
        )

    getUserBySessionData: (sessionData) ->
        ###
        Возвращает пользователя по содержимому сесси.
        @param sessionData: object
        @returns: UserModel
        ###
        if _.isString(sessionData)
            sessionData = {id: sessionData, alternativeIds: []}
        user = new UserModel(sessionData.id)
        user.setAlternativeIds(sessionData.alternativeIds)
        user.setPermissions(sessionData.permissions)
        return user

    getSessionUserData: (user) ->
        return {
            id: user.id
            alternativeIds: user.getAlternativeIds()
            permissions: user.getPermissions()
        }

    setSessionUserData: (session, user) ->
        session[KEY]?[USER_FIELD_NAME] = @getSessionUserData(user)

module.exports.AuthUtils = new AuthUtils()
