ExternalError = require('../common/exceptions').ExternalError

class AuthError extends ExternalError
    ###
    Ошибка авторизации.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'AuthError'

module.exports =
    AuthError: AuthError
    INVALID_CONFIRM_KEY: "invalid_confirm_key"
    ALREADY_CONFIRMED: "already_confirmed"
    INTERNAL_ERROR: "internal_error"
    INVALID_FORGOT_PASSWORD_KEY: "invalid_forgot_password_key"
    EXPIRED_CONFIRM_KEY: "expired_confirm_key"
    EXPIRED_FORGOT_PASSWORD_KEY: "expired_forgot_password_key"
    EMPTY_EMAIL_ERROR: 'empty_email'
