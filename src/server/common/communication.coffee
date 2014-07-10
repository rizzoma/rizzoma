Response = require('../../share/communication').Response
ExternalError = require('./exceptions').ExternalError
InternalError = require('./exceptions').InternalError
util = require('util')
Conf = require('../conf').Conf

# кол-во символов для лог сообщения ответа
LOG_MSG_LIMIT = 200

class ServerResponse extends Response
    ###
    Класс ответа.
    ###
    _init: () ->
        super()

    constructor: (err, data, @_userId) ->
        ###
        @param data: object - содержимое ответа.
        ###
        super(err, data)
        logDepth = Conf.getLoggerConf().logResponse
        @_needLog = !!logDepth
        @_logger = Conf.getLogger('response')
        @_inspect = (arg) ->
            return util.inspect(arg, false, logDepth)

    serialize: () ->
        result = super()
        log=[]
        logData =
            method: result.procedureName
            callId: result.callId
            userId: @_userId

        sourceErr = result.err
        if sourceErr
            if sourceErr not instanceof ExternalError
                err = new InternalError(sourceErr.message)
                @_logger.error("Internal error #{@_inspect(sourceErr)}, logId: #{err.logId}")
                sourceErr = err
            result.err = sourceErr.toClient()
            log.push("error: #{@_inspect(result.err)}")
            log.push("logId: #{sourceErr.logId}")
            logData.error = sourceErr
            logData.logId = sourceErr.logId
        log.push("data: #{@_inspect(result.data)}")
        logMsg = "<#{result.procedureName} (#{result.callId}, #{@_userId}, #{result.perf?.ts or '-'}): " + log.join(", ")
        logMsg = logMsg.substr(0, LOG_MSG_LIMIT) + "…" if logMsg.length > LOG_MSG_LIMIT
        logData.perf = result.perf if result.perf?
        logData.data = result.data
        @_logger.debug(logMsg, logData)

        delete result.procedureName # do not send procedureName back to client
        return result

module.exports.ServerResponse = ServerResponse
