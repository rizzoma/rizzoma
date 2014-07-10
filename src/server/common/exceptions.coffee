BaseError = require('../../share/exceptions').BaseError
IdUtils = require('../utils/id_utils').IdUtils

class ServerError extends BaseError
    ###
    Базовый класс серверных исключений.
    ###
    constructor: (args...) ->
        super(args...)
        @_generateLogId()

    _generateLogId: () ->
        ###
        Создает строку для передачи на клиент, чтобы можно было идентифицировать соответствующую запись в логе
        @param err: error
        ###
        code = @code
        logId = 'int'
        if code and typeof(code) == 'string' and code.length
            logId = ''
            logId += part[0] for part in code.split('_')
        @logId = "#{logId}#{IdUtils.getRandomId(4)}".toUpperCase()

    toClient: () ->
        return {
            type: @name
            message: @message
            code: @code
            logId: @logId
        }

class InternalError extends ServerError
    ###
    Базовый класс исключений, не передаваемых на клиента.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'InternalError'
        if not @code
            @code = 'internal_error'

    toClient: () ->
        result = super()
        result.type = 'InternalError'
        result.message = 'InternalError'
        return result

class ExternalError extends ServerError
    ###
    Базовый класс исключений, передаваемых на клиента.
    ###
    constructor: (args...) ->
        super(args...)
        @name = 'ExternalError'

module.exports =
    InternalError: InternalError
    INTERNAL_ERROR: 'internal_error'
    ExternalError: ExternalError
