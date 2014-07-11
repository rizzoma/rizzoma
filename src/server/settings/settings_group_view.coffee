{Conf} = require('../conf')

class SettingsGroupView
    ###
    Базовый класс view группы настроек.
    ###
    constructor: () ->
        ###
        У каждого наследника должен быть реализован, как минимум, метод update, выполняющий согранение настроек группы.
        ###
        @_logger = Conf.getLogger('settings-view')
        @_routes = {}
        @_routes[@getName()] = @update

    getName: () ->
        throw new Error('Not implemented')

    supplementContext: (context, user, profile, auths, callback) ->
        ###
        Дополняет контекст отрисовки страницы дополнительными атрибутами группы.
        Реализуется в наследниках.
        ###
        callback(null, context)

    update: (req, res) =>
        ###
        Обрабатывает запрос на сохранение настроек группы.
        ###
        return if req.method == 'POST'
        res.send(405)
        return true

    route: (req, res, userDataStrategy) ->
        ###
        Перенаправляет запрос на изменение настроек нужному методу класса.
        ###
        action = req.params[1]
        actionMethod = @_routes[action]
        return if not actionMethod
        actionMethod(req, res, userDataStrategy)
        return true

    _sendResponse: (res, err, data) ->
        if err
            err = err.toClient() if err.toClient
        res.json({err: err?.message, data: data})

module.exports.SettingsGroupView = SettingsGroupView
