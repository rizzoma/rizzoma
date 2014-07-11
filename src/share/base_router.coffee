###
@package: volna
@autor: quark, 2011
###

BaseModule = require('./base_module').BaseModule
ModuleNotFoundError = require('./exceptions').ModuleNotFoundError
Response = require('./communication').Response

class BaseRouter extends BaseModule
    ###
    Класс, представляющий базовый роутер.
    ###

    constructor: (args...) ->
        super(args...)
        @_moduleRegister = {}

    handle: (procedureName, request) ->
        ###
        Находит нужный модуль и вызывает процедуру.
        @param procedureName: string
        @param request: share.communication.Request	
        ###
        if not @_executeProcedure(procedureName, request)
            err = new ModuleNotFoundError("Module #{ procedureName } not found")
            request.callback(new Response(err, null, request.user?.id))

    handleBroadcast: (procedureName, request) ->
        ###
        Вызывает процедуру у всех модулей.
        @param procedureName: string
        @param request: Request
        ###
        for name, module of @_moduleRegister
            module.handle(procedureName, request)

    _executeProcedure: (procedureName, request) ->
        ###
        Разбирает название процедуры и вызывает ее/передает другому роутеру.
        В случае успеха возвращает true
        @param procedureName: string
        @param request: share.communication.Request
        @return: bool
        ###
        parts = procedureName.split('.')
        if parts.length < 2
            return false
        prefix = parts[0]
        module = @_getModuleByName(prefix)
        if not module
            return
        @_call(module, @_reduceProcedureName(parts), request)
        return true

    _reduceProcedureName: (parts) ->
        parts[1...parts.length].join('.')

    _call: (module, procedureName, request) ->
        module.handle(procedureName, request)

    _addModule: (name, module)->
        ###
        Добавляет модуль в реестр.
        @param name: string
        @param module: object
        ###
        @_moduleRegister[name] = module

    _getModuleByName: (moduleName)->
        ###
        Возвращает модуль по его имени.
        @param moduleName: string
        @return: object
        ###
        @_moduleRegister[moduleName]

module.exports.BaseRouter = BaseRouter
