window.getLogger = () ->
    return console
RootRouter =  require('./modules/root_router').RootRouter

router = new RootRouter()
module.exports.router = router