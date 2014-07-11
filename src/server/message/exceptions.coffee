ExternalError = require('../common/exceptions').ExternalError

class MessageError extends ExternalError
    ###
    Ошибка при работе с сообщением.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'MessageError'

module.exports.MessageError = MessageError
