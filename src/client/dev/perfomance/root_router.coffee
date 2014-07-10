###
@package: volna
@autor: quark, 2011
###

BaseRouter = require('../../../share/base_router').BaseRouter
NetworkRouter = require('./network/network_router').PerfomanceNetworkRouter

class PerfomanceRootRouter extends BaseRouter
    ###
    Класс, представляющий корневой роутер. Знает о всех корневых модулях и всех корневых роутерах.
    ###

    constructor: (url='http://localhost:8000/', expressSessionId=null) ->
        super()
        @_addModule('network', new NetworkRouter(@, url, expressSessionId))
        
    setExpressSessionId: (id) ->
        @_getModuleByName('network').setExpressSessionId(id)

module.exports.PerfomanceNetworkRouter = PerfomanceRootRouter