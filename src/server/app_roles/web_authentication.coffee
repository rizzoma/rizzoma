passport = require('passport')
app = require('./web_base').app
Conf = require('../conf').Conf
authConf = Conf.get('auth')
AuthError = require('../auth/exceptions').AuthError

WAVE_URL = Conf.getWaveUrl()
AUTH_URL = authConf.authUrl
CALLBACK_URL = authConf.callbackUrl
GOOGLE_AUTH_BY_TOKEN_URL = authConf.googleAuthByTokenUrl
LOGOUT_URL = authConf.logoutUrl
AJAX_LOGOUT_URL = authConf.ajaxLogoutUrl
EMBEDDED_AUTH_URL = authConf.embeddedAuthUrl
embeddedAuthTemplate = Conf.getTemplate().compileFile('embedded_auth.html')

_logger = Conf.getLogger('auth')

_getSource = (req) ->
    return  req.params[0]

app.get(AUTH_URL, (req, res, next) ->
    source = _getSource(req)
    url = req.query?.url
    isMobile = req.query?.isMobile
    req.session.isMobile = isMobile if isMobile
    if url and url.match(/^\//)
        urlBeforeAuth = decodeURIComponent(url)
    else
        urlBeforeAuth = WAVE_URL
        Conf.getLogger().info("Wave URL does not start with slash. Remote address is #{req.connection?.remoteAddress?}, url is #{url}")
    req.session.timezone = req.cookies.tz
    req.session.urlBeforeAuth = urlBeforeAuth
    req.session.authSource = source
    params = {}
    scope = Conf.getAuthSourceConf(source).scope
    params.scope = scope if scope
    passport.authenticate(source, params)(req, res, next)
)

app.get(EMBEDDED_AUTH_URL, (req, res) ->
    try
        res.send embeddedAuthTemplate.render()
    catch e
        Conf.getLogger('http').error(e)
        res.send 500
)

_getMobileUrl = (err, accessToken) ->
    ###
    Ссылка для редиректа при авторизации с Android-устройств.
    ###
    return "rizzoma://auth.done?ACCESS_TOKEN=#{encodeURIComponent(accessToken)}#{if err then '&ERROR='+err else ''}"

_getRedirectUrl = (req, isMobile) ->
    sidKey = Conf.getSessionConf().key
    return _getMobileUrl(null, req.cookies[sidKey]) if isMobile
    url = req.session.urlBeforeAuth or WAVE_URL
    delete req.session.urlBeforeAuth
    return url

_facebookRedirect = (req, res) ->
    ###
    Редирект на клиентсайде. Выризаем #_=_ из урла.
    ###
    page = """
        <script>
            if(window.location.hash == '#_=_') {
                window.location.hash=''
            }
            document.location.href='#{_getRedirectUrl(req)}'
        </script>
    """
    res.end(page)

_errorRedirect = (req, res, err, isMobile) ->
    notice = 'auth_error'
    if err
        _logger.error('Error while authentication: ', err)
        notice = err.code if err instanceof AuthError
    else
        notice = 'auth_canceled'
    if isMobile
        return res.redirect(_getMobileUrl(notice, null))
    url = _getRedirectUrl(req)
    url = "#{url}#{if /\?/.test(url) then '&' else '?'}notice=#{notice}"
    res.redirect(url)

app.get(CALLBACK_URL,(req, res) ->
    source = _getSource(req)
    isMobile = req.session.isMobile
    delete req.session.isMobile
    passport.authenticate(source, (err, user, info) ->
        return _errorRedirect(req, res, info, isMobile) if not user
        req.login(user, (err) ->
            return _errorRedirect(req, res, err, isMobile) if err
            return _facebookRedirect(req, res) if source == 'facebook' and not isMobile
            res.redirect(_getRedirectUrl(req, isMobile))
        )
    )(req, res, (err) ->
        return _errorRedirect(req, res, err, isMobile)
    )
)

app.get(GOOGLE_AUTH_BY_TOKEN_URL,(req, res) ->
    isMobile = req.session.isMobile
    delete req.session.isMobile
    passport.authenticate('googleByToken', (err, user, info) ->
        return _errorRedirect(req, res, info, isMobile) if not user
        req.login(user, (err) ->
            return _errorRedirect(req, res, err, isMobile) if err
            res.redirect(_getRedirectUrl(req, isMobile))
        )
    )(req, res, (err) ->
        return _errorRedirect(req, res, err, isMobile)
    )
)

app.get(LOGOUT_URL, (req, res) ->
    req.logout()
    res.redirect('/topic/')
)

app.get(AJAX_LOGOUT_URL, (req, res) ->
    req.logout()
    res.end()
)

# password auth and register
AuthPasswordViews = require('../auth/password/views').AuthPasswordViews
app.post('/auth/password/json/', AuthPasswordViews.jsonSignIn)
app.post("/auth/register/json/", AuthPasswordViews.jsonRegister)
app.get("/auth/register/confirm/", AuthPasswordViews.registerConfirm)
app.post("/auth/forgot_password/json/", AuthPasswordViews.jsonForgotPassword)
app.get("/auth/forgot_password/change/", AuthPasswordViews.forgotPasswordChange)
app.post("/auth/forgot_password/change/", AuthPasswordViews.processForgotPasswordChange)

# в rzweb никто не инициализирует нотификатор сделаем это o_O
# notifications
Notificator = require('../notification/').Notificator
Notificator.initTransports()

process.on('exit', (err) ->
    Notificator.closeTransports()
)
process.on('uncaughtException', (err) ->
    Notificator.closeTransports()
)
