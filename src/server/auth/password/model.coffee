crypto = require('crypto')
{AuthModel} = require('../model')
{IdUtils} = require('../../utils/id_utils')
{UserUtils} = require('../../user/utils')
{DateUtils} =  require('../../utils/date_utils')

PASSWORD_SALT_DELIMITER = '$' # разделяет в поле документа соль и соленый им хеш пароля
CONFIRM_KEY_EXPIRATION_TIMEOUT = 86400 *2 # время протухания ключа подтверждения регистрации в секундах 48 часов
FORGOT_PASSWORD_KEY_EXPIRATION_TIMEOUT = 86400 *2 # время протухания ключа сброса пароля в секундах 48 часов


class PasswordAuth extends AuthModel
    ###
    Модель авторизации по паролю
    ###
    constructor: (sourceUser) ->
        return super('password') if not sourceUser
        super("password", sourceUser, UserUtils.normalizeEmail(sourceUser.email))
        @_email = sourceUser.email
        @_name = sourceUser.name
        @setPassword(sourceUser.password)
        @setConfirmKey(sourceUser.confirmKey)

    getPasswordHash: () ->
        return @_extra.passwordHash

    setPasswordHash: (passwordHash) ->
        @_extra.passwordHash = passwordHash
        
    isPasswordValid: (password) ->
        return false if not @_extra.passwordHash
        [salt, hash] = @_extra.passwordHash.split(PASSWORD_SALT_DELIMITER)
        return false if not salt or not hash
        return @_makeSaltedPasswordHash(password, salt) is hash

    setPassword: (pass) ->
        salt = @_generatePasswordSalt()
        hash = @_makeSaltedPasswordHash(pass, salt)
        @setPasswordHash([salt,hash].join(PASSWORD_SALT_DELIMITER))

    _makeSaltedPasswordHash: (pass, salt) ->
        return crypto.createHash("md5").update(pass + salt).digest("hex")

    _generatePasswordSalt: () ->
        return IdUtils.getRandomId(16)

    generateConfirmKey: () ->
        @setConfirmKey(IdUtils.getRandomId(16))

    getConfirmKey: () -> @_extra.confirmKey

    setConfirmKey: (key, expiration=null) ->
        ###
        Чтоб удалять
        ###
        @setConfirmKeyExpirationTime(expiration)
        @_extra.confirmKey = key

    setConfirmKeyExpirationTime: (timestamp=null) ->
        ###
        Устанавливает дату протухания ключа подтверждения
        ###
        timestamp = DateUtils.getCurrentTimestamp() + CONFIRM_KEY_EXPIRATION_TIMEOUT if not timestamp?
        @_extra.confirmKeyExpirationTime = timestamp

    getConfirmKeyExpirationTime: () -> @_extra.confirmKeyExpirationTime

    isConfirmed: () ->
        return not @getConfirmKey()

    isConfirmKeyExpired: () ->
        return true if @isConfirmed()
        return DateUtils.getCurrentTimestamp() > @getConfirmKeyExpirationTime()

    generateForgotPasswordKey: () ->
        @setForgotPasswordKey(IdUtils.getRandomId(16))

    getForgotPasswordKey: () -> @_extra.forgotPasswordKey

    setForgotPasswordKey: (key, expiration=null) ->
        ###
        Чтоб удалять
        ###
        @_extra.forgotPasswordKey = key
        expiration = DateUtils.getCurrentTimestamp() + FORGOT_PASSWORD_KEY_EXPIRATION_TIMEOUT if not expiration?
        @_extra.forgotPasswordKeyExpirationTime = expiration

    isForgotPasswordKeyExpired: () ->
        ###
        Проверяет не протух ли ключ скидывания пароля
        ###
        return true if not @getForgotPasswordKey()
        return DateUtils.getCurrentTimestamp() > @_extra.forgotPasswordKeyExpirationTime



module.exports.PasswordAuth = PasswordAuth