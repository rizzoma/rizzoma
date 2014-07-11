async = require('async')
passport = require('passport')
Conf = require('../../conf').Conf
isEmail = require('../../../share/utils/string').isEmail

{AuthCouchProcessor} = require('../couch_processor')
{AuthController} = require('../controller')
{UserModel} = require('../../user/model')
{UserCouchProcessor} = require('../../user/couch_processor')
{PasswordAuth} = require('./model')
{Notificator} = require('../../notification')
{
    AuthError
    INVALID_CONFIRM_KEY
    ALREADY_CONFIRMED
    EXPIRED_CONFIRM_KEY
    INVALID_FORGOT_PASSWORD_KEY
    INTERNAL_ERROR
} = require('../exceptions')
authFactory = require('../factory').authFactory

forgotPasswordChangeTpl = Conf.getTemplate().compileFile('auth/password/forgot_password_change.html')

MIN_PASS_LENGTH = 6

class AuthPasswordViews

    constructor: () ->
        @_logger = Conf.getLogger('auth')

    jsonSignIn: (req, res, next) =>
        err = @_checkJsonSignInParams(req)
        return @_sendJsonRes(res, {error: err}) if err
        req.session.timezone = req.cookies.tz
        req.session.authSource = 'password'
        passport.authenticate('password', (err, user, info) =>
            return @_sendJsonRes(res, {error: new AuthError("Internal server error", "internal_error")}) if err
            return @_sendJsonRes(res, {error: info}) if not user
            req.login(user, (err) =>
                return @_sendJsonRes(res, {error: new AuthError("Internal server error", "internal_error")}) if err
                # return "accessToken" when requested from mobile app, "user" when from website (desktop and mobile)
                isMobile = req.query?.isMobile
                data = if isMobile then {accessToken: @_getAccessToken(res)} else {user: user.toObject(true)}
                @_sendJsonRes(res, data)
            )
        )(req, res, next)

    _getAccessToken: (res) ->
        return encodeURIComponent(res.req.sessionID)

    _checkJsonSignInParams: (req) ->
        username = req.param("username").trim()
        return new AuthError("Empty email","empty_email") if not username
        return new AuthError("Invalid email","invalid_email") if not isEmail(username)
        return new AuthError("Empty password", "empty_password") if not req.param("password").trim()
        return new AuthError("Are you robot?", "robot") if not req.param("no_robots").trim()
        return null

    _sendJsonRes: (res, data) ->
        res.send(JSON.stringify(data))

    jsonRegister: (req, res) =>
        ###
        Процесс регистрации нового пользователя чз ajax
        ###
        email = req.param('username').trim()
        name = req.param('name').trim()
        pass = req.param('password').trim()
        noRobots = req.param('no_robots').trim()
        tasks = [
            (callback) =>
                err = @_checkRegisterParams(email, pass, name, noRobots)
                return callback(err) if err
                authFromSource = authFactory("password", { email: email })
                AuthCouchProcessor.getById(authFromSource.getId(), (err, auth) =>
                    return callback(err) if err and err.message != 'not_found'
                    if auth and auth.isConfirmed()
                        return callback(new AuthError("Email already registered", "already_registered"), null)
                    callback(null, auth or authFromSource, not auth or auth.isConfirmKeyExpired())
                )
            (auth, needSaveAuth, callback) ->
                UserCouchProcessor.getOrCreateByAuth(auth, (err, user, isAuthUserIdChanged) ->
                    callback(err, auth, needSaveAuth, user)
                )
            (auth, needSaveAuth, user, callback) =>
                return callback(null, auth, user) if not needSaveAuth
                @_saveOrUpdateAuth(auth, email, name, pass, user, callback)
            (auth, user, callback) =>
                @_sendConfirmNotification(auth, user, callback)
        ]
        async.waterfall(tasks, (err) =>
            return @_sendJsonRes(res, {ok: "ok"}) if not err
            return @_sendJsonRes(res, {error: err}) if err instanceof AuthError
            @_logger.error(err)
            @_sendJsonRes(res, {error: new AuthError("Internal server error", "internal_error")})
        )

    _checkRegisterParams: (email, pass, name, noRobots) ->
        ###
        Возвращает ошибку если какого либо параметра не хватает иначе null
        ###
        return new AuthError("Empty email", "empty_email") if not email
        return new AuthError("Invalid email","invalid_email") if not isEmail(email)
        return new AuthError("Empty password", "empty_password") if not pass
        return new AuthError("Password must be at least #{MIN_PASS_LENGTH} symbols long", "short_password") if pass.length < MIN_PASS_LENGTH
        return new AuthError("Empty name", "empty_name") if not name
        return new AuthError("Are you robot?", "robot") if not noRobots
        return null

    _sendConfirmNotification: (auth, user, callback) ->
        context =
            key: new Buffer("#{auth.getEmail()}_#{auth.getConfirmKey()}", "utf-8").toString("base64")
        Notificator.notificateUser(user, "register_confirm", context, callback)

    _saveOrUpdateAuth: (auth, email, name, pass, user, callback) ->
        action = (auth, callback) ->
            auth.setEmail(email)
            auth.setName(name)
            auth.generateConfirmKey()
            auth.setPassword(pass)
            auth.setUserId(user.id)
            callback(null, true, auth, false)
        AuthCouchProcessor.saveResolvingConflicts(auth, action, (err, status) ->
            callback(err, auth, user)
        )

    registerConfirm: (req, res) =>
        ###
        вьюшка для подтверждения регистрации
        ###
        key = req.param('key')
        [email, confirmKey] = new Buffer(key, "base64").toString("utf-8").split('_')
        email = email.trim()
        confirmKey = confirmKey.trim()
        tasks = [
            (callback) =>
                err = @_checkRegisterConfirmParams(email, confirmKey)
                return callback(err) if err
                authFromSource = authFactory("password", { email: email })
                AuthCouchProcessor.getById(authFromSource.getId(), (err, auth) =>
                    return callback(err) if err and err.message != 'not_found'
                    err = @_checkRegisterConfirmKey(confirmKey, auth)
                    return callback(err) if err
                    callback(null, auth)
                )
            (auth, callback) ->
                action = (auth, callback) ->
                    auth.setConfirmKey(null)
                    callback(null, true, auth, false)
                AuthCouchProcessor.saveResolvingConflicts(auth, action, (err, status) ->
                    callback(err, auth)
                )
            (auth, callback) ->
                # сразу залогиним его
                AuthController.afterAuthActions(req, auth, auth, null, callback)
            (user, callback) ->
                req.login(user, callback)
        ]
        async.waterfall(tasks, (err) =>
            if err
                if not (err instanceof AuthError)
                    @_logger.error(err)
                    err = new AuthError("Internal server error", "internal_error")
                res.redirect("/topic/?notice=#{encodeURIComponent(err.code)}")
                return
            res.redirect("/topic/")
        )

    _checkRegisterConfirmParams: (email, confirmKey) ->
        ###
        Возвращает ошибку если какого либо параметра не хватает иначе null
        ###
        return new AuthError("Invalid confirmation, please sign up again", INVALID_CONFIRM_KEY) if not email or not isEmail(email) or not confirmKey
        return null

    _checkRegisterConfirmKey: (confirmKey, auth) ->
        ###
        Проверяет валидность ключа подтверждения
        ###
        return new AuthError("Invalid confirmation, please sign up again", INVALID_CONFIRM_KEY) if not auth
        return new AuthError("Confirmation is already accepted", ALREADY_CONFIRMED) if auth.isConfirmed()
        if auth.getConfirmKey() and auth.isConfirmKeyExpired()
            return new AuthError("Sign up confirmation expired, please sign up again", EXPIRED_CONFIRM_KEY)
        return new AuthError("Invalid confirmation, please sign up again", INVALID_CONFIRM_KEY) if auth.getConfirmKey() != confirmKey
        return null

    jsonForgotPassword: (req, res) =>
        email = req.param('username').trim()
        tasks = [
            (callback) =>
                err = @_checkForgotPasswordParams(email, req.param('no_robots').trim())
                return callback(err) if err
                authFromSource = authFactory("password", { email: email })
                AuthCouchProcessor.getById(authFromSource.getId(), (err, auth) =>
                    return callback(err) if err and err.message != 'not_found'
                    return callback(new AuthError("User not found", "user_not_found")) if not auth or not auth.isConfirmed()
                    callback(null, auth)
                )
            (auth, callback) ->
                UserCouchProcessor.getById(auth.getUserId(), (err, user) ->
                    callback(err, auth, user)
                )
            (auth, user, callback) ->
                # если ключ не протух проссто вышлем еще раз письмо
                return callback(null, auth, user) if auth.getForgotPasswordKey() and not auth.isForgotPasswordKeyExpired()
                action = (auth, callback) ->
                    auth.generateForgotPasswordKey()
                    callback(null, true, auth, false)
                AuthCouchProcessor.saveResolvingConflicts(auth, action, (err, status) ->
                    callback(err, auth, user)
                )
            (auth, user, callback) =>
                @_sendForgotPasswordNotification(auth, user, callback)
        ]
        async.waterfall(tasks, (err) =>
            return @_sendJsonRes(res, {ok: "ok"}) if not err
            return @_sendJsonRes(res, {error: err}) if err instanceof AuthError
            @_logger.error(err)
            @_sendJsonRes(res, {error: new AuthError("Internal server error", "internal_error")})
        )

    _checkForgotPasswordParams: (email, noRobots) ->
        ###
        Возвращает ошибку если какого либо параметра не хватает иначе null
        ###
        return new AuthError("Empty email", "empty_email") if not email
        return new AuthError("Invalid email","invalid_email") if not isEmail(email)
        return new AuthError("Are you robot?", "robot") if not noRobots
        return null

    _sendForgotPasswordNotification: (auth, user, callback) ->
        context =
            key: new Buffer("#{auth.getEmail()}_#{auth.getForgotPasswordKey()}", "utf-8").toString("base64")
        Notificator.notificateUser(user, 'forgot_password', context, callback)

    forgotPasswordChange: (req, res) =>
        key = req.param('key').trim()
        @_checkForgotPasswordChangeKey(key, (err, auth) =>
            return @_processForgotPasswordChangeError(res, err) if err
            res.send forgotPasswordChangeTpl.render({ key: key })
        )

    _processForgotPasswordChangeError: (res, err) ->
        if err
            if not (err instanceof AuthError)
                @_logger.error(err)
                err = new AuthError("Internal server error", "internal_error")
            res.redirect("/topic/?notice=#{encodeURIComponent(err.code)}")

    processForgotPasswordChange: (req, res) =>
        key = req.param('key').trim()
        @_checkForgotPasswordChangeKey(key, (err, auth) =>
            return @_processForgotPasswordChangeError(res, err) if err
            tasks = [
                (callback) ->
                    return new AuthError("Are you robot?", "robot") if not req.param('no_robots')
                    newPassword = req.param('new_password').trim()
                    return callback(new AuthError("Empty password", "empty_passowrd")) if not newPassword
                    return callback(new AuthError("Password must be at least #{MIN_PASS_LENGTH} symbols long", "short_password")) if newPassword.length < MIN_PASS_LENGTH
                    action = (auth, callback) ->
                        auth.setPassword(newPassword)
                        auth.setForgotPasswordKey(null)
                        callback(null, true, auth, false)
                    AuthCouchProcessor.saveResolvingConflicts(auth, action, (err, status) ->
                        callback(err)
                    )
            ]
            async.waterfall(tasks, (err) ->
                if err
                    if not (err instanceof AuthError)
                        @_logger.error(err)
                        err = new AuthError("Internal server error", "internal_error")
                    res.send forgotPasswordChangeTpl.render({ err: err, key: key })
                else
                    res.redirect("/topic/?notice=password_changed")
            )
        )

    _checkForgotPasswordChangeKey: (key, callback) ->
        [email, forgotPasswordKey] = new Buffer(key, "base64").toString("utf-8").split('_')
        email = email.trim()
        forgotPasswordKey = forgotPasswordKey.trim()
        err = @_checkForgotPasswordChangeParams(email, forgotPasswordKey)
        return callback(err) if err
        authFromSource = authFactory("password", { email: email })
        AuthCouchProcessor.getById(authFromSource.getId(), (err, auth) =>
            return callback(err) if err and err.message != 'not_found'
            if not auth or not auth.isConfirmed()
                return callback(new AuthError("Invalid password reset, please request it again", INVALID_FORGOT_PASSWORD_KEY))
            if not auth.getForgotPasswordKey() or auth.getForgotPasswordKey() != forgotPasswordKey
                return callback(new AuthError("Invalid password reset, please request it again", INVALID_FORGOT_PASSWORD_KEY))
            if auth.isForgotPasswordKeyExpired()
                return callback(new AuthError("Expired password reset, please request it again", EXPIRED_FORGOT_PASSWORD_KEY))
            callback(null, auth)
        )

    _checkForgotPasswordChangeParams: (email, key) ->
        ###
        Возвращает ошибку если какого либо параметра не хватает иначе null
        ###
        return new AuthError("Invalid password reset, please request it again", INVALID_FORGOT_PASSWORD_KEY) if not email or not isEmail(email) or not key
        return null


module.exports =
    AuthPasswordViews: new AuthPasswordViews()
    MIN_PASS_LENGTH: MIN_PASS_LENGTH
