###
  Role initializes and starts REST and SockJS API endpoints.
###

# /wave/ page
require('./web_wave')

# root router
RootRouter = require('../common/root_router')
router = new RootRouter()

# SockJS init
app = require('./web_base').app
require('../common/network').init(router, app)

# notifications
Notificator = require('../notification/').Notificator
Notificator.initTransports()

process.on('exit', (err) ->
    Notificator.closeTransports()
)
process.on('uncaughtException', (err) ->
    Notificator.closeTransports()
)
