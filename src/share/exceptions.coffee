class BaseError extends Error
    ###
    Базовый класс исключений.
    ###
    constructor: (@message, @code=0) ->
        super(@message)
        if Error.captureStackTrace
            Error.captureStackTrace(@, arguments.callee)


class NotImplementedError extends BaseError
    ###
    Метод не реализован.
    ###
    constructor: (message, code=0) ->
        super(message, code)


class ModuleNotFoundError extends BaseError
    ###
    Модуль не найден.
    ###
    constructor: (message, code=0) ->
        super(message, code)


class ProcedureNotFoundError extends BaseError
    ###
    Процедура не найдена.
    ###
    constructor: (message, code=0) ->
        super(message, code)

class BadParams extends BaseError
    ###
    Не верные аргументы вызова.
    ###
    constructor: (message, code=0) ->
        super(message, code)

class PermissionError extends BaseError
    ###
    Недотаточно прав для вызова процедуры.
    ###
    constructor: (message, code=0) ->
        super(message, code)

class VerificationError extends BaseError
    ###
    Метод не верифицирован.
    ###
    constructor: (message, code=0) ->
        super(message, code)

module.exports=
    BaseError: BaseError
    NotImplementedError: NotImplementedError
    ModuleNotFoundError: ModuleNotFoundError
    ProcedureNotFoundError: ProcedureNotFoundError
    PermissionError: PermissionError
    VerificationError: VerificationError
    BadParams: BadParams
