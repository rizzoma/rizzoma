ExternalError = require('../common/exceptions').ExternalError

class NotificationError extends ExternalError
    ###
    Ошибка при отправке сообщения.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'NotificationError'

module.exports =
    NotificationError:NotificationError
    USER_DENY_NOTIFICATION: 'user_deny_notification'
