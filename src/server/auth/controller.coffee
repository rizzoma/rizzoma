async = require('async')
Conf = require('../conf').Conf
AuthCouchProcessor = require('./couch_processor').AuthCouchProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
WelcomeWaveBuilder = require('../wave/welcome_wave').WelcomeWaveBuilder
MergeController = require('../user/merge_controller').MergeController
authFactory = require('./factory').authFactory
AuthError = require('./exceptions').AuthError

EMPTY_EMAIL_ERROR = require('./exceptions').EMPTY_EMAIL_ERROR

class AuthController

    constructor: () ->
        @_logger = Conf.getLogger('auth-controller')

    processPasswordAuth: (req, email, password, timezone, callback) ->
        ###
        Авторизация по паролю
        ###
        profile =
            provider: 'password'
            _json:
                email: email
                password: password
                timezone: timezone
        checkAuthProcessor = (authFromSource, auth) ->
            return new AuthError("User not found, please register", "user_not_found") if not auth
            return new AuthError("User not confirmed", "user_not_confirmed") if auth.getConfirmKey()
            return new AuthError("Wrong password", "wrong_password") if not auth.isPasswordValid(password)
            return null
        @_processAuth(req, profile, checkAuthProcessor, null, callback)

    processOAuth: (req, profile, callback) ->
        ###
        Авторизация через OAuth
        ###
        checkAuthProcessor = (authFromSource) ->
            return if !!authFromSource.getEmail()
            return new AuthError("Can't auth user without any email", EMPTY_EMAIL_ERROR)
        @_processAuth(req, profile, checkAuthProcessor, null, callback)

    _processAuth: (req, profile, checkAuthProcessor, options, callback) ->
        ###
        Обший процесс авторизации принимает checkAuthProcessor для различных типов проверок
        @param callback: function
        ###
        authFromSource = authFactory(profile.provider, profile._json)
        AuthCouchProcessor.getById(authFromSource.getId(), (err, auth) =>
            return callback(err) if err and err.message != 'not_found'
            fail = checkAuthProcessor?(authFromSource, auth)
            return callback(null, false, fail) if fail
            @afterAuthActions(req, authFromSource, auth, options, callback)
        )

    _updateAuthFromSource: (authFromSource, auth, callback) ->
        ###
        Обновляет модель авторизации данными из source модели
        Возвращает в колбэк обновленную модель и флажек изменилась она или нет
        ###
        return callback(null, authFromSource, true) if not auth
        authFromSource.setUserId(auth.getUserId())
        authFromSource.setName(auth.getName()) if not authFromSource.getName()
        authFromSource.setUserCompilationParams(auth.getUserCompilationParams())
        callback(null, authFromSource, auth.getHash() != authFromSource.getHash())

    afterAuthActions: (req, authFromSource, auth, options={}, callback) ->
        ###
        Действия после успешной авторизации
        ###
        tasks = [
            (callback) =>
                @_updateAuthFromSource(authFromSource, auth, callback)
            (auth, isAuthChanged, callback) ->
                UserCouchProcessor.getOrCreateByAuth(auth, (err, user, isAuthUserIdChanged) ->
                    return callback(err) if err
                    auth.updateUser(user)
                    callback(null, auth, user, isAuthChanged or isAuthUserIdChanged)
                )
            (auth, user, isAuthChanged, callback) =>
                @_useProperAlgorithm(auth, user, req, options, (err, processedUser) =>
                    @_logger.error('Error while updating authorized user', {err, user, auth}) if err
                    # возникшие ошибки (не создался Welcome topic или не смерджились аккаунты) дальше не передаем, только логгируем.
                    callback(null, auth, processedUser or user, isAuthChanged)
                )
            (auth, user, isAuthChanged, onSaveDone) =>
                action = (reloadedUser, callback) ->
                    #Будем сохранять если обробатываемый пользователь новее того, с что в базе
                    user._rev = reloadedUser._rev
                    callback(null, user.lastVisit >= reloadedUser.lastVisit, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, (err) =>
                    if err
                        @_logger.error('Error while saving authorized user', {err, user, auth})
                    else
                        @_logSucessAuth(req, auth, user)
                    callback(err, user)
                )
                return onSaveDone() if not isAuthChanged
                AuthCouchProcessor.save(auth, (err) =>
                    @_logger.error('Error while saving user auth', {err, user, auth}) if err
                    onSaveDone()
                )
        ]
        async.waterfall(tasks, (err) ->
            callback(err) if err
        )

    _logSucessAuth: (req, auth, user) ->
        sidKey = Conf.getSessionConf().key
        #Логируем часть sid-а, а не значение полностью, на случай если кто-то получит доступ к нашим логам.
        sid =  req.cookies[sidKey]?.substr(0, 10)
        logObject =
            ip: req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket?.remoteAddress
            sid: sid
            emails: user.normalizedEmails
            userId: user.id
            authId: auth.getId()
            authEmail: auth.getEmail()
            authAlternativeEmails: auth.getAlternativeEmails()
        @_logger.debug("User #{user.id} #{user.email} has logged in", logObject)

    _useProperAlgorithm: (auth, user, req, options, callback) ->
        ###
        Выбирает нужный алгоритм авторизации: первый раз пользователь пришел или заходил раньше.
        @param user: UserModel
        @param session: object
        @param callback: function
        ###
        session = req.session
        return @_processFirstAuth(auth, user, session, options, callback) if not user.firstVisit
        return @_processOrdinaryAuth(auth, user, session, options, callback)

    _processFirstAuth: (auth, user, session, options, callback) =>
        ###
        Алгоритм авторизации нового пользователя (пользователь был сосдан ранее (импорт, ручное добавление в топик),
        но раньше не авторизовался).
        ###
        user.setFirstAuthCondition(session.referer, session.channel, session.landing)
        if options.disableNotification
            user.notification.clearSettings()
        else
            user.notification.setDefaultSettings()
        session.firstVisit = true
        return @_processOrdinaryAuth(auth, user, session, options, callback) if options.skipWelcomeTopic
        WelcomeWaveBuilder.getOrCreateWelcomeWaves(user, (err, waves, isFound) =>
            if err
                @_logger.error("Error while creating welcome topic for user #{user.id}", err)
            else
                for wave in waves
                    @_logger.debug("Created welcome topic #{wave.waveId} for user #{user.id}")
                    delete wave.internalId
                session.welcomeWaves = waves
                session.welcomeTopicJustCreated = not isFound
            @_processOrdinaryAuth(auth, user, session, options, callback)
        )

    _processOrdinaryAuth: (auth, user, session, options, callback) ->
        ###
        Алгоритм авторизации существующего пользователя с существующей авторизацией (самый обычный вариант).
        ###
        session.justLoggedIn = true
        user.setVisitCondition()
        emailsToMerge = user.getNotMyEmails(auth.getAlternativeEmails())
        return callback(null, user) if not emailsToMerge.length
        @_logger.debug("Automatic merge were started user #{user.id} with #{emailsToMerge.join(', ')}")
        MergeController.mergeByEmails(user, emailsToMerge, callback, true)

module.exports.AuthController = new AuthController()