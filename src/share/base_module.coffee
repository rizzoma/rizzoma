###
@package: volna
@autor: quark, 2011
###
ProcedureNotFoundError = require('./exceptions').ProcedureNotFoundError
BadParams = require('./exceptions').BadParams
PermissionError = require('./exceptions').PermissionError
VerificationError = require('./exceptions').VerificationError
Response = require('./communication').Response

class BaseModule
    ###
    Класс, представляющий базовый модуль.
    ###
    constructor: (@_rootRouter, @_responceClass=Response) ->

    handle: (procedureName, request) ->
        ###
        Обрабатывает запрос на выполнение процедуры.
        @param procedureName: string
        @param request: Request    
        ###
        return if not @_callMethod(procedureName, request)
        err = new ProcedureNotFoundError("Procedure #{procedureName} not found")
        request.callback(@_createResponse(err, null, request.user?.id))

    v: (name, expectedArgs=[], permissions) ->
        ###
        Устанавливает параметры верификации вызова процедуры.
        @param name: string
        @param expectedArgs: array - список обязательных аргументов
        @param permissions: int - права, требуемые для вызова (по умолчанию не требуются)
        ###
        procedure = @[name]
        return if not procedure
        procedure.isVerified = true
        procedure.expectedArgs = expectedArgs
        procedure.permissions = permissions

    _verifyArgs: (request, expectedArgs=[]) ->
        for arg in expectedArgs
            notNull = false
            if arg.indexOf('(not_null)')
                arg = arg.replace('(not_null)', '')
                notNull = true
            return new BadParams("Expected arg #{arg}") if request.args[arg] == undefined
            return new BadParams("Arg #{arg} must be not null") if notNull and request.args[arg] == null
        return

    _verifyPermissions: (request, permissions) ->
        return if not permissions
        return new PermissionError("Access denied") if not request.user.checkPermissions(permissions)

    _callMethod: (name, request) ->
        userId = request.user?.id
        procedure = @[name]
        return true if not procedure
        argsErr = @_verifyArgs(request, procedure.expectedArgs)
        permissionsErr = @_verifyPermissions(request, procedure.permissions)
        err = argsErr or permissionsErr
        if err
            request.callback(@_createResponse(err, null, userId))
            return
        onRequestProcessed = (err, data) =>
            request.callback(@_createResponse(err, data, userId))
        callId = request.args?.callId
        listenerId = if callId then "#{request.sessionId}#{callId}" else null
        procedure.call(@, request, request.args, onRequestProcessed, listenerId)
        return

    _createResponse: (args...) ->
        return new @_responceClass(args...)

module.exports.BaseModule = BaseModule
