###
@package: volna
@autor: quark, 2011
Содержит классы rpc-запросов/ответов
###

class Convertible
    ###
    Базовый класс.
    ###
    constructor: () ->
        @_properties = []

    setProperty: (name, value) ->
        ###
        Добавляет свойство в объект по имени.
        ###
        @_properties.push(name)
        @[name] = value

    serialize: () ->
        ###
        Преобразует инстанс в объект годный для передачи по сети (плоский объект без методов).
        @return: object
        ###
        result = {}
        for propertie in @_properties
          result[propertie] = @[propertie]
        return result


class Request extends Convertible
    ###
    Класс запроса.
    ###
    constructor: (@args, @callback) ->
        ###
        @param args: object
        @param callback: function
        ###
        super()
        @_init()

    _init: () ->
        @_properties = ['args']


class Response extends Convertible
    ###
    Класс ответа.
    ###
    constructor: (@err, @data) ->
        ###
        @param data: object - содержимое ответа.
        ###
        super()
        @_init()

    _init: () ->
        @_properties = ['err', 'data']

module.exports =
    Convertible: Convertible
    Request: Request
    Response: Response
