module.exports.init = (rootRouter, app) ->
    ###
    Инициализирует транспорты.
    @param rootRouter: BaseRouter
    @param app: object - express'овский app (@see server/app.coffee)
    ###
    transports = [
        sockjs = require './transports/sockjs'
        rest = require './transports/rest'
    ]
    for transport in transports
        new transport(rootRouter, app)

