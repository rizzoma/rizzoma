_ = require('underscore')
passport = require('passport')
Conf = require('../conf').Conf
UserModel = require('../user/model').UserModel
AuthController = require('./controller').AuthController
AuthUtils = require('../utils/auth_utils').AuthUtils

passport.serializeUser((user, callback) ->
    callback(null, AuthUtils.getSessionUserData(user))
)

passport.deserializeUser((sessionUserData, callback) ->
    user = AuthUtils.getUserBySessionData(sessionUserData)
    callback(null, user)
)

_getTimezone = (req) ->
    #Допишем таймзону из сессии в профайл, как будто там и было, зато просто, хотя на самом деле, можно было
    #отнаследоваться от нужной стратегии и authenticate
    timezone = req.session.timezone
    delete req.session.timezone
    return timezone

_oAuthCallback = (req, accessToken, refreshToken, profile, callback) ->
    profile._json.timezone = _getTimezone(req)
    req.oauth = {accessToken, refreshToken, profile}
    AuthController.processOAuth(req, profile, callback)

_passwordAuthCallback = (req, email, password, callback) ->
    timezone = _getTimezone(req)
    AuthController.processPasswordAuth(req, email, password, timezone, callback)

Strategies =
    google: {strategy: require('passport-google-oauth').OAuth2Strategy, callback: _oAuthCallback}
    googleByToken: {strategy: require('./google-oauth-by-token').Strategy, callback: _oAuthCallback}
    facebook: {strategy: require('passport-facebook').Strategy, callback: _oAuthCallback}
    password: {strategy: require('passport-local').Strategy, callback: _passwordAuthCallback}

initStrategies = () ->
    for own strategyName, strategy of Strategies
        settings = Conf.getAuthSourceConf(strategyName)
        settings.passReqToCallback = true
        passport.use(strategyName, new strategy.strategy(settings, strategy.callback))

module.exports = initStrategies()
