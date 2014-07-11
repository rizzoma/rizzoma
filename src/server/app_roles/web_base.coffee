###
Базовая роль для всех веб приложений (ролей).
Сама отдельно не запускается.
###

# conf
Conf = require('../conf').Conf

# authentication
passport = require('passport')
require('../auth/configurator')
require('../user/prepare_merge_controller').init()
loggedIn = require('../utils/middleware/logged_in').loggedIn
everyauthToPassportMigration = require('../utils/middleware/everyauth_to_passport_migration').everyauthToPassportMigration

# express server
express = require('express')
app = express.createServer()

# переопределим console на наш логгер
replaceConsole = require('../common/logger/utils').replaceConsole
replaceConsole(Conf.getLogger('console'))

userInfoMiddleware = require('../utils/middleware/user-info-middleware').userInfoMiddleware

loggerConf = Conf.getLoggerConf()
connectLogger = require('../common/logger/utils').connectLogger

app.configure ->
    if loggerConf.useXForwardedFor
        connectXForwardedFor = require('node-connect-x-forwarded-for')
        app.use(connectXForwardedFor({trustedAddress: loggerConf.trustedAddress}))
    app.use(connectLogger(Conf.getLogger('http')))
    app.use(express.favicon(__dirname + '/../../static/img/logo/favicon.ico'))
    app.use(require('../utils/middleware/jquery_form_limit').jqueryFormLimit('10mb'))
    app.use(express.bodyParser())
    app.use(express.cookieParser())
    app.use(express.session(Conf.getSessionConf()))
    app.use(passport.initialize())
    app.use(everyauthToPassportMigration)
    app.use(passport.session())
    app.use(loggedIn)
    app.use(userInfoMiddleware)
    #app.use(express.static(__dirname + '/../../lib/static'))
    app.use(app.router)
    # last line should be error handler
    #app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))
    app.use(express.errorHandler({ dumpExceptions: true, showStack: false }))
    # это лучше сделать в Nginx:
    # app.use('/gadgets/', require('../utils/middleware/proxy-middleware').proxy(Conf.get('gadget').shindigUrl + '/gadgets'))

# dev: testing interface
reportView = require('../test')
app.get "/dev/tests/", reportView.reportView

# status
app.get "/status/version.txt", (req, res) ->
    res.send Conf.getVersionInfo().versionString || '-'

# networking
process.nextTick ->
    listenPort = Conf.getAppListenPort()
    app.listen listenPort
    Conf.getLogger().info("Server listening at http://localhost:#{listenPort}/")

module.exports.app = app
