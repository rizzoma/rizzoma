_ = require('underscore')
Model = require('../common/model').Model
UserUtils = require('../user/utils').UserUtils
IdUtils = require('../utils/id_utils').IdUtils
logger = require('../conf').Conf.getLogger('auth')

ALL_PROFILE_FIELDS = require('../../share/constants').PROFILE_FIELDS
{
    PROFILE_FIELD_EMAIL
    PROFILE_FIELD_NAME
    PROFILE_FIELD_AVATAR
    PROFILE_FIELD_TIMEZONE
    PROFILE_FIELD_SOURCE
} = require('../../share/constants')

class AuthModel extends Model
    ###
    Базовая модель авторизации.
    ###
    constructor: (@_source, sourceUser, sourceId) ->
        ###
        @param source: string - источник авторизации
        @param sourceUser: object - объект данных который вернула авторизация
        ###
        @id = "#{@_source}_#{sourceId}" if sourceId
        @userId = null
        @_timezone = sourceUser.timezone if sourceUser
        @_name = null
        @_email = null
        @_avatar = null
        @_alternativeEmails = []
        @_userCompilationParams = ALL_PROFILE_FIELDS if not @_userCompilationParams
        @_extra = {}
        super('auth')

    getId: () ->
        return @id

    getExternalId: () ->
        return @id.split('_')[1]

    getEmail: () ->
        ###
        Возвращает нормализованный email.
        ###
        return @_email

    getNormalizedEmail: () ->
        return UserUtils.normalizeEmail(@_email)

    setEmail: (@_email) ->

    getName: () ->
        return @_name

    setName: (@_name) ->

    getAvatar: () ->
        return UserUtils.fixAvatarProtocol(@_avatar)

    setAvatar: (@_avatar) ->

    getTimezone: () ->
        return parseInt(@_timezone, 10)

    getUserId: () ->
        return @userId

    getAlternativeEmails: () ->
        return @_alternativeEmails

    setUserId: (id) ->
        @userId = id if id

    isUserSpecified: () ->
        return !!@userId

    getUserCompilationParams: () ->
        return @_userCompilationParams

    setUserCompilationParams: (params) ->
        ###
        Сеттер @_userCompilationParams
        @param params: array
        @returns: bool - вернет true, если поле было изменено.
        ###
        return if not params
        if _.difference(@_userCompilationParams, params).length + _.difference(params, @_userCompilationParams).length
            @_userCompilationParams = params
            return true
        return false
        
    getSource: ->
        return @id.split('_')[0]

    getHash: () ->
        return [
            @getName()
            @getEmail()
            @getAvatar()
            @getTimezone()
            @getAlternativeEmails().join()
        ].join()

    getProfile: () ->
        profile = {}
        profile[PROFILE_FIELD_EMAIL] = @getEmail()
        profile[PROFILE_FIELD_NAME] = @getName()
        profile[PROFILE_FIELD_AVATAR] = @getAvatar()
        profile[PROFILE_FIELD_TIMEZONE] = @getTimezone()
        profile[PROFILE_FIELD_SOURCE] = @getSource()
        return profile

    updateUser: (user) ->
        inUserCompilationParams = (param) =>
            return param in @_userCompilationParams
        user.setEmail(@getEmail()) if inUserCompilationParams(PROFILE_FIELD_EMAIL)
        user.setExternalId(@_source, @getExternalId())
        user.setName(@getName()) if inUserCompilationParams(PROFILE_FIELD_NAME)
        user.setAvatar(@getAvatar()) if inUserCompilationParams(PROFILE_FIELD_AVATAR)
        user.setTimezone(@getTimezone()) if inUserCompilationParams(PROFILE_FIELD_TIMEZONE)

    getExtra: () -> @_extra

    setExtra: (@_extra) ->


class GoogleAuth extends AuthModel
    ###
    Реализация google авторизации
    ###
    constructor: (sourceUser) ->
        return super('google') if not sourceUser
        super('google', sourceUser, sourceUser.id)
        @_email = sourceUser.email
        @_name = sourceUser.name
        @_avatar = sourceUser.picture.replace(/(.*googleusercontent.*)(photo\.jpg)/, '$1s65-c-k/$2') if sourceUser.picture


class FacebookAuth extends AuthModel
    ###
    Реализация facebook авторизации
    ###
    constructor: (sourceUser) ->
        return super('facebook') if not sourceUser
        super('facebook', sourceUser, sourceUser.id)
        logger.warn("Incorrect facebook source user", {sourceUser}) if not sourceUser.id
        @_email = sourceUser.email
        @_name = sourceUser.name
        updatedTime = (new Date(sourceUser.updated_time)).getTime()
        @_avatar = "https://graph.facebook.com/#{sourceUser.id}/picture?width=65&height=65&r=#{updatedTime}"
        username = sourceUser.username
        return if not username
        alternativeEmail = "#{username}@facebook.com"
        if not @_email
            logger.info("Auth for user without email was created, user=#{alternativeEmail}", {source: 'facebook', user: alternativeEmail})
            return @_email = alternativeEmail
        @_alternativeEmails.push(alternativeEmail)


class TwitterAuth extends AuthModel
    ###
    Реализация twitter авторизации
    ###
    constructor: (sourceUser) ->
        return super('twitter') if not sourceUser
        super('twitter', sourceUser)
        @_name = sourceUser.name
        @_avatar = sourceUser.profile_image_url


class AutoAuth extends AuthModel
    ###
    Автоматически создаваемая. Залогиниться через нее в принципе нельзя, нужна только как контейнер для данных.
    @see: UserController._getNotPresentedAuthList
    ###
    constructor: () ->
        super('auto', null, IdUtils.getRandomId())

module.exports =
    AuthModel: AuthModel
    GoogleAuth: GoogleAuth
    FacebookAuth: FacebookAuth
    TwitterAuth: TwitterAuth
    AutoAuth: AutoAuth

