###
Модуль для отправки ошибок, возникших на клиенте, на сервер
###
{BaseModule} = require('../../share/base_module')

MAX_ERROR_LOGS = 10 # Максимальное количество логов ошибок, отправляемых на сервер за указанный ниже период
MAX_ERROR_LOGS_PERIOD = 10 * 60 * 1000 # Период, после которого счетчик ошибок обнуляется

sendToServer = (data) ->
    settings =
        type: 'POST'
        contentType: 'application/json'
        data: JSON.stringify(data)
        processData: false
    $.ajax('/client-log/', settings)

class ErrorLogger extends BaseModule
    constructor: (args...) ->
        super(args...)
        @_errorsLogged = 0
        @_lastErrorLoggedRefreshTime = Date.now()
        window.onerror = (message, url, line) =>
            data = @_getErrorData(message)
            return if not data?
            data.isUncaught = true
            data.source = (url || '')+':'+(line || '0') if url? or line?
            @_logData(data)
            try console.error("Uncaught error:", message, url, line)
            # do not stop error processing by browser
            return false

    logError: (e) ->
        data = @_getErrorData(e)
        return if not data?
        @_logData(data)

    _logData: (data) ->
        if Date.now() - @_lastErrorLoggedRefreshTime > MAX_ERROR_LOGS_PERIOD
            @_errorsLogged = 0
            @_lastErrorLoggedRefreshTime = Date.now()
        return if @_errorsLogged >= MAX_ERROR_LOGS
        @_errorsLogged++
        sendToServer(data)

    _getErrorData: (e) ->
        if e instanceof Error
            data =
                code: e.code
                message: e.message
                stacktrace: e.stack
        else if typeof(e) is 'string'
            data = {message: e}
        return null if not data?
        data.codeVersion = window.versionString
        return data


module.exports = {ErrorLogger}