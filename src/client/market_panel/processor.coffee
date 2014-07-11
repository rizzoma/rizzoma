BaseRouter = require('../../share/base_router').BaseRouter
Request = require('../../share/communication').Request

class MarketProcessor extends BaseRouter
    constructor: (@_rootRouter) ->
        super(@_rootRouter)

    getVisibleItemList: (callback) ->
        request = new Request({}, callback)
        @_rootRouter.handle('network.store.getVisibleItemList', request)

    installStoreItem: (id, callback) ->
        params =
            itemId: id
        request = new Request(params, callback)
        @_rootRouter.handle('network.user.installStoreItem', request)

    uninstallStoreItem: (id, callback) ->
        params =
            itemId: id
        request = new Request(params, callback)
        @_rootRouter.handle('network.user.uninstallStoreItem', request)

    getCurrentWave: (callback) ->
        request = new Request([], callback)
        @_rootRouter.handle('wave.getCurWave', request)

module.exports =
    MarketProcessor: MarketProcessor
    instance: null