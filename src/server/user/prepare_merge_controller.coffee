_ = require('underscore')
passport = require('passport')
Strategies =
    google: require('passport-google-oauth').OAuth2Strategy
    facebook: require('passport-facebook').Strategy
async = require('async')
Conf = require('../conf').Conf
DateUtils = require('../utils/date_utils').DateUtils
IdUtils = require('../utils/id_utils').IdUtils
UserCouchProcessor = require('./couch_processor').UserCouchProcessor
Notificator = require('../notification/').Notificator
UserModel = require('./model').UserModel
isEmail = require('../../share/utils/string').isEmail
authFactory = require('../auth/factory').authFactory
MergeError = require('./exceptions').MergeError

CODE_LENGTH = 16
DELIMITER = require('./constants').MERGE_DIGEST_DELIMITER
MERGE_STRATEGY_NAME_PREFIX = require('./constants').MERGE_STRATEGY_NAME_PREFIX
SENDING_HOLD_PERIOD = 60 * 5 #Если запрос на слияние будет повторен менбше, чем через 5 минут, то слать ничего не будем.
EMAIL_CONFIRM_CALLBACK_URL = Conf.get('accountsMerge').emailConfirmCallbackUrl

_authCallback = (req, accessToken, refreshToken, profile, callback) ->
    auth = authFactory(profile.provider, profile._json)
    emails = auth.getAlternativeEmails()
    emails.push(auth.getEmail())
    req.session.mergingValidationData =
        userId: req.user.id
        emailsToMerge: emails
        code: IdUtils.getRandomId(CODE_LENGTH)
    callback(null, auth.getProfile())

init = () ->
    for own strategyName, StrategyClass of Strategies
        settings = Conf.getAuthSourceConf(strategyName)
        settings = _.extend(settings, Conf.get('accountsMerge')[strategyName])
        settings.passReqToCallback = true
        passport.use("#{MERGE_STRATEGY_NAME_PREFIX}#{strategyName}", new StrategyClass(settings, _authCallback))


class PrepareMergeController
    constructor: () ->

    prepareMerge: (user, emailToMerge, callback) ->
        ###
        Генерирует дойджест и посылает письмо с подтверждением.
        @param user: UserModel
        @param emailToMerge: string
        @param callback: function
        ###
        return callback(new MergeError('Invalid email')) if not isEmail(emailToMerge)
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                UserCouchProcessor.getByEmail(emailToMerge, (err, userToMerge) ->
                    if not err
                        return callback(new MergeError('Already merged')) if user.isMyEmail(emailToMerge)
                        return callback(null, user, userToMerge)
                    return callback(err) if err.message != 'not_found'
                    userToMerge = new UserModel()
                    userToMerge.setEmail(emailToMerge)
                    #костыль для нотификатора @see: isNewUser. Исключант лишнее обращение к фс.
                    userToMerge.firstVisit = 1
                    callback(null, user, userToMerge)
                )
            (user, userToMerge, callback) =>
                user.mergingValidationData[userToMerge.email] ||= {}
                mergingValidationData = user.mergingValidationData[userToMerge.email]
                mergingValidationData.code ||= IdUtils.getRandomId(CODE_LENGTH)
                now = DateUtils.getCurrentTimestamp()
                if now - (mergingValidationData.sendDate or 0) > SENDING_HOLD_PERIOD
                    code = mergingValidationData.code
                    context = {digest: @_getDigest(user, userToMerge.email, code), from: user, mergeUrl: EMAIL_CONFIRM_CALLBACK_URL}
                    Notificator.notificateUser(userToMerge, 'merge', context, (err) ->
                        console.log err
                    )
                mergingValidationData.sendDate = now
                UserCouchProcessor.save(user, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err)
        )

    _getDigest: (user, emailToMerge, code) ->
        return (new Buffer([user.id, emailToMerge, code].join(DELIMITER))).toString('base64')

module.exports =
    PrepareMergeController: new PrepareMergeController()
    init: init