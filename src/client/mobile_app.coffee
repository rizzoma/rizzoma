RootRouter =  require('./modules/root_router_mobile').RootRouter

exports.startApp = ->
    router = new RootRouter()
