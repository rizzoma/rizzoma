async = require('async')
{Conf} = require('../conf')
{AuthCouchProcessor} = require('../auth/couch_processor')
{UserController} = require('../user/controller')
{UserCouchProcessor} = require('../user/couch_processor')

class UserDataStrategy
    ###
    Стратегия-хэлпер. Возвращает пользователя и профиль.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('settings-view')

    getName: () ->
        throw new Error('Not implemented')

    get: () =>
        throw new Error('Not implemented')


class HashUserDataStrategy extends UserDataStrategy
    ###
    Вернет пользователя и профиль по хэшу (переход на настройки из писма, пользователь может быть не аутентифицирован в системе).
    ###
    constructor: () ->
        super()

    getName: () ->
        return 'hash'

    get: (req, callback) =>
        tasks = [
            (callback) ->
                hash = req.param('hash')
                return callback(new Error('Invalid arguments'), null) if not hash
                callback(null, hash)
            (hash, callback) =>
                email = req.param('email')
                return callback(new Error('Invalid arguments'), null) if not email
                UserCouchProcessor.getByEmail(email, (err, user) =>
                    callback(err, hash, user)
                )
            (hash, user, callback) =>
                err = if user.notification.id != hash then new Error('Invalid Hash') else null
                callback(err, user, null, null)
        ]
        async.waterfall(tasks, callback)

    _getEmail: (req, hash, callback) ->
        email = req.param('email')
        return callback(null, email) if email


class SessionUserDataStrategy extends UserDataStrategy
    ###
    Вернет пользователя и профиль по содержимому сессии (переход на настройки с сайта, пользователь аутентифицирован).
    ###
    constructor: () ->
        super()

    getName: () ->
        return 'auth'

    get: (req, callback) =>
        tasks = [
            (callback) ->
                return callback(new Error('Authorization required'), null) if not req.user or req.user.isAnonymous()
                callback(null, req.user.id)
            (userId, callback) =>
                UserController.getUserAndProfile(userId, callback)
            (user, profile, callback) ->
                AuthCouchProcessor.getByUserId(user.id, (err, auths) ->
                    return callback(err) if err
                    callback(null, user, profile, auths)
                )
        ]
        async.waterfall(tasks, callback)

hashUserDataStrategy = new HashUserDataStrategy()
sessionUserDataStrategy = new SessionUserDataStrategy()

module.exports.getStrategy = (req) ->
    return sessionUserDataStrategy if req.params and req.params.length and req.params[0] == 'settings'
    return hashUserDataStrategy


