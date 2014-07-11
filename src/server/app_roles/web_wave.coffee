###
Роль для запуска страницы /wave/.
###
Conf = require('../conf').Conf
app = require('./web_base').app
async = require('async')
urlModule = require('url')
createHash = require('crypto').createHash
UserController = require('../user/controller').UserController
WaveProcessor = require('../wave/processor').WaveProcessor
WaveController = require('../wave/controller').WaveController
BlipProcessor = require('../blip/processor').BlipProcessor
TipListController = require('../tip_list/controller').TipListController
IdUtils = require('../utils/id_utils').IdUtils
AuthUtils = require('../utils/auth_utils').AuthUtils
anonymous = require('../user/anonymous')
isRobot = require('../utils/http_request').isRobot
loadMarkup = require('../export/controller').loadMarkup
toEmbeddedHtml = require('rizzoma-export').toEmbeddedHtml
ServerResponse = require('../common/communication').ServerResponse
TeamController = require('../team/controller').TeamController

# /wave/ url
appVersion = Conf.getVersion()
waveUrl = Conf.getWaveUrl()
waveEmbeddedUrl = Conf.getWaveEmbeddedUrl()
waveDriveUrl = Conf.getWaveDriveUrl()
embeddedAuthUrl = Conf.get('auth').embeddedAuthUrl
googleClientId = Conf.getAuthSourceConf('google').clientID

isMobile = (ua, requested_mode) ->
    return no if requested_mode is 'desktop'
    return yes if requested_mode is 'mobile'
    ua.search(/Android|BlackBerry|iPhone|iPod|IEMobile|Kindle|SymbianOS|Symbian|MeeGo/i) > -1

{
    NOT_LOGGED_IN
    MERGED_SUCCESSFUL
    INVALID_CODE_FORMAT
    INVALID_USER
    INVALID_CODE
    MERGING_NOT_REQUESTED
    CODE_IS_DELAYED
    INTERNAL_MERGE_ERROR
} = require('../user/exceptions')

{
    INVALID_CONFIRM_KEY
    ALREADY_CONFIRMED
    EXPIRED_CONFIRM_KEY
    INTERNAL_ERROR
    INVALID_FORGOT_PASSWORD_KEY
    EXPIRED_FORGOT_PASSWORD_KEY
    EMPTY_EMAIL_ERROR
} = require('../auth/exceptions')

waveTemplate = Conf.getTemplate().compileFile('wave.html')
waveEmbeddedTemplate = Conf.getTemplate().compileFile('wave_embedded.html')
waveTemplateMobile = Conf.getTemplate().compileFile('wave_mobile.html')

app.get new RegExp("^(#{waveUrl}|#{waveEmbeddedUrl}|#{waveDriveUrl})([a-f0-9]+)?"), (req, res) ->
    authSource = req.session.authSource
    if req.query.notice is MERGED_SUCCESSFUL
        successfulMerge = true
    else
        notice = ''
        noticeMessages =
            auth_timeout_error: 'Auth took too long. Try again.'
            auth_error: 'Auth error occurred. Try again.'
            auth_canceled: 'Auth was canceled.'
        noticeMessages[EMPTY_EMAIL_ERROR] = "Can't auth user without any email"
        noticeMessages[NOT_LOGGED_IN] = 'Please sign in into Rizzoma.com before requesting account merge and try again.'
        noticeMessages[INVALID_CODE_FORMAT] = 'Invalid request to merge accounts.'
        noticeMessages[INVALID_USER] = 'Unable to merge accounts for signed in user. Please sign in using one of merged accounts and try again.'
        noticeMessages[INVALID_CODE] = 'Invalid merging request information.'
        noticeMessages[MERGING_NOT_REQUESTED] = 'Sorry, this is unknown merge request.'
        noticeMessages[CODE_IS_DELAYED] = 'Sorry, this request to merge accounts was cancelled.'
        noticeMessages[INTERNAL_MERGE_ERROR] = 'Internal error. Please try again some later.'
        notice = noticeMessages[req.query.notice] or ''
    if req.query.notice
        # нотисы от авторизации по паролю
        switch req.query.notice
            when INVALID_CONFIRM_KEY then notice = "Invalid confirmation, please sign up again"
            when ALREADY_CONFIRMED then notice = "Confirmation is already accepted"
            when EXPIRED_CONFIRM_KEY then notice = "Sign up confirmation expired, please sign up again"
            when INTERNAL_ERROR then notice = "Internal server error"
            when INVALID_FORGOT_PASSWORD_KEY then notice = "Invalid password reset, please request it again"
            when EXPIRED_FORGOT_PASSWORD_KEY then notice = "Expired password reset, please request it again"
            when "password_changed" then notice = "Password has been changed"

    referalEmailHash = req.query.referalEmailHash
    tasks = [
        (callback) ->
            return callback(null, null, null) if not req.loggedIn
            UserController.getUserAndProfile(req.user.id, (err, user, profile) ->
                if err
                    console.warn("Bugcheck. Can not get logged in user #{req.user.id}")
                    req.logout()
                    return callback(null, null, null)
                AuthUtils.setSessionUserData(req.session, user)
                user.authSource = authSource
                callback(null, user, profile)
            )
        (user, profile, callback) ->
            TipListController.getTipList((err, tipList) ->
                callback(err, user, profile, tipList)
            )
        (user, profile, tipList, callback) ->
            waveUrlToLoad = req.params[1]
            if not isRobot(req) or not waveUrlToLoad
                return callback(null, user, profile, tipList, null)
            loadMarkup(user or anonymous, waveUrlToLoad, (error, markup) ->
                if error
                    return callback(null, user, profile, tipList, null)
                pregenerated =
                    title: markup.title
                    url: markup.url
                    content: toEmbeddedHtml(markup, {tagSearchUrl: Conf.getTagSearchUrl()})
                callback(null, user, profile, tipList, pregenerated)
            )
        (user, profile, tipList, pregenerated, callback) ->
            waveUrlToLoad = req.params[1]
            return callback(null, user, profile, tipList, pregenerated, []) if waveUrlToLoad or not user?
            TeamController.getTeamTopics(req.user, no, yes, (err, result) ->
                console.warn("Error while loading team topics: #{err}") if err
                callback(null, user, profile, tipList, pregenerated, result or [])
            )
        (user, profile, tipList, pregenerated, teamTopics, callback) ->
            waveUrlToLoad = req.params[1]
            # Пропускаем этот шаг, если есть данные для робота либо нет waveUrl для загрузки
            return callback(null, user, profile, tipList, pregenerated, teamTopics, null) if pregenerated or not waveUrlToLoad
            WaveController.getClientWaveWithBlipsByUrl(waveUrlToLoad, user or anonymous, referalEmailHash, (err, data) ->
                response = new ServerResponse(err, data, (user or anonymous).id)
                response.setProperty('callId', 'html')
                serializedTopicData = {}
                serializedTopicData[waveUrlToLoad] = response.serialize()
                callback(null, user, profile, tipList, pregenerated, teamTopics, serializedTopicData)
            )
        (user, profile, tipList, pregenerated, teamTopics, serializedTopicData, callback) ->
            # registration
            welcomeWaves = req.session['welcomeWaves']
            delete req.session['welcomeWaves'] if welcomeWaves
            firstVisit = req.session['firstVisit']
            delete req.session['firstVisit'] if firstVisit

            # first login per session
            firstSessionLoggedIn = false
            if req.loggedIn and not req.session['alreadyLoggedIn']
                firstSessionLoggedIn = true
                req.session['alreadyLoggedIn'] = true

            justLoggedIn = req.session['justLoggedIn']
            delete req.session['justLoggedIn'] if justLoggedIn

            daysAfterFirstVisit = null
            if user? and user.firstVisit? and user.firstVisit
                daysAfterFirstVisit = Math.floor((new Date() - new Date(user.firstVisit*1000))/(1000*60*60*24))

            welcomeTopicJustCreated = req.session['welcomeTopicJustCreated']
            delete req.session['welcomeTopicJustCreated'] if welcomeTopicJustCreated
            wavePrefix = req.params[0]
            isEmbedded = wavePrefix is waveEmbeddedUrl
            showAccountSelectionWizard = user and not user.isAccountTypeSelected() and not isEmbedded
            # render
            params =
                session:
                    id: req.sessionID
                    refreshInterval: Conf.getSessionConf().refreshInterval
                loggedIn: req.loggedIn
                host: req.headers['host']
                wavePrefix: wavePrefix
                isEmbedded: isEmbedded
                waveUrl: waveUrl
                waveEmbeddedUrl: waveEmbeddedUrl
                waveDriveUrl: waveDriveUrl
                embeddedAuthUrl: embeddedAuthUrl
                siteAnalytics: Conf.get('siteAnalytics')
                uiConf: Conf.get('ui')
                socialSharingConf: Conf.get('socialSharing')
                notice: notice
                successfulMerge: successfulMerge
                user: user
                profile: profile
                mergedIds: user?.getAllIds() or []
                installedStoreItems: user?.getInstalledStoreItems() or []
                appVersion: appVersion
                versionString: Conf.getVersionInfo().versionString
                appSignatureType: Conf.get('app').signatureType
                showIfUnsupportedBrowserCookie: Conf.get('app').showIfUnsupportedBrowserCookie
                fileUuid: IdUtils.getRandomId(16)
                welcomeWaves: welcomeWaves
                firstVisit: firstVisit
                cl: req.session.cl
                firstSessionLoggedIn: firstSessionLoggedIn
                justLoggedIn: justLoggedIn
                daysAfterFirstVisit: daysAfterFirstVisit
                welcomeTopicJustCreated: welcomeTopicJustCreated
                showAccountSelectionWizard: showAccountSelectionWizard
                googleClientId: googleClientId
                hangoutAppId: Conf.getHangoutConf().appId
                referalEmailHash: referalEmailHash
                openSearchQuery: req.query['search-query'] or ''
                tipList: tipList.toClientObject()
                gadget: Conf.get('gadget')
                pregenerated: pregenerated
                heartbeatInterval: Conf.get('sockjs').heartbeat_delay
                serializedTopicData: serializedTopicData
                teamsCacheKey: user?.getActiveBonusTypes().join(',')
                teamTopics: teamTopics
            if isMobile(req.headers['user-agent'] || '', req.query?.mode)
                template = waveTemplateMobile
            else
                if isEmbedded
                    template = waveEmbeddedTemplate
                else
                    template = waveTemplate
            try
                res.send template.render(params)
            catch e
                Conf.getLogger('http').error(e)
                res.send 500
            callback(null)
    ]
    async.waterfall(tasks)

# redirect /wave/xxx to /topic/xxx
app.get new RegExp("^/wave/"), (req, res) ->
    redirect_url = req.url.replace(new RegExp('^/wave/'), waveUrl)
    res.redirect(redirect_url)

# /wave and /topic redirect: append slash
app.get new RegExp('^/(wave|topic)$'), (req, res) ->
    res.redirect(waveUrl)

# страница с предупреждением о том, что браузер не поддерживается или не полностью поддерживается
supportedBrowsersTemplate = Conf.getTemplate().compileFile('supported_browsers.html')
app.get "/supported_browsers/", (req, res) ->
    redirectUrl = req.query.redirectUrl || waveUrl
    # разрешаем только относительные url
    redirectUrl = waveUrl if redirectUrl.charAt(0)!='/'
    params =
        showIfUnsupportedBrowserCookie: Conf.get('app').showIfUnsupportedBrowserCookie
        redirectUrl: redirectUrl
    try
        res.send supportedBrowsersTemplate.render(params)
    catch e
        Conf.getLogger('http').error(e)
        res.send 500

#xml-ка для opensearch
openSearchXMLTemplate = Conf.getTemplate().compileFile('rizzomasearch.xml')
app.get "/rizzomasearch.xml", (req, res) ->
    params =
        url: Conf.get('baseUrl')
    try
        res.setHeader('Content-Type', 'text/xml')
        res.send openSearchXMLTemplate.render(params)
    catch e
        Conf.getLogger('http').error(e)
        res.send 500

# страница с названием топика для расшаривания в социальных сетях и для редиректа пользователей, зашедших по ссылкам
waveShareTemplate = Conf.getTemplate().compileFile('share_wave.html')
app.get /^\/!\/([a-z0-9]{32})([a-z0-9]{6})\/[a-zA-Z0-9]{2}$/, (req, res) ->
    utm = ''
    if req.headers.referer
        url = urlModule.parse(req.headers.referer)
        if url.host.search('facebook.com') != -1
            utm = 'fb'
        if url.host.search('google.com') != -1
            utm = 'G+'
        if url.host.search('t.co') != -1
            utm = 'tw'
    waveId = req.params[0]
    sign = req.params[1]
    tasks = [
        (callback) ->
            url = waveId + Conf.get('socialSharing').signSalt
            shasum = createHash('sha1')
            shasum.update(url)
            socialSharingUrl = shasum.digest('hex')
            if socialSharingUrl.substr(0, Conf.get('socialSharing').signLength) != sign
                err = new Error("Invalid sign")
                return callback(err, null, null)
            WaveProcessor.getWaveByUrl(waveId, callback)
        (wave, callback) ->
            waveNotShared = false
            if not wave.sharedToSocial
                waveNotShared = true
                return callback(null, wave, null, false)
            if Date.now() - wave.sharedToSocialTime > Conf.get('socialSharing').timeout*1000
                waveNotShared = true
                return callback(null, wave, null, false)
            else
                BlipProcessor.getBlip(wave.rootBlipId, (err, blip) ->
                    callback(err, wave, blip, true)
                )
        (wave, blip, needSave, callback) ->
            if needSave
                return WaveProcessor.setSocialSharing(wave, false, (err, res) ->
                    callback(err, wave, blip)
                )
            callback(null, wave, blip)
    ]
    async.waterfall(tasks, (err, wave, blip) ->
        if err and not wave
            params = {}
        else if wave and not blip
            params =
                waveUrl: "#{waveUrl}#{wave.getUrl()}/"
                utm: utm
        else
            params =
                waveUrl: "#{waveUrl}#{wave.getUrl()}/"
                utm: utm
                waveTitle: blip.getTitle()
                waveSnippet: blip.getSnippet()
        try
            res.send waveShareTemplate.render(params)
        catch e
            Conf.getLogger('http').error(e)
            res.send 500
    )

waveShareWaitTemplate = Conf.getTemplate().compileFile('share_wave_wait.html')
app.get "/share_topic_wait/", (req, res) ->
    try
        res.send waveShareWaitTemplate.render()
    catch e
        Conf.getLogger('http').error(e)
        res.send 500

app.get "/ping/", (req, res) ->
    ###
    Пока используется только для продления сессии клиентом
    и обновления lastActivity
    ###
    return res.end('') if not req.loggedIn or not req.user
    UserController.processPing(req.user.id, (err) ->
        return res.end('') if not err
        Conf.getLogger('ping').error(err)
        res.send(500)
    )

###
Скрипт для автоматического перенаправления на /topic/ для залогиненных пользователей, предназначен для подключения на главной странице.

Код (diff) для подключения в index.html (уникальный URL необходим для Firefox, т.к. несмотря на заголовки он кеширует подключаемые скрипты):
-----------begin-----------
     <!-- block scripts -->
+    <script type="text/javascript">
+        document.write('<sc'+'ript type="text/javascript" src="https://rizzoma.com/auth_auto_redirect.js?t='+Date.now()+'"><\/sc'+'ript>');
+    </script>
     <script type="text/javascript" src="s/js/jquery-1.7.2.js"></script>
------------end------------

Session middleware выполняется раньше, даже для запросов, в которых сессии не было. Поэтому, чтобы не стартовать много пустых сессий,
при запросе /auth_auto_redirect.js без куки "connect.sid" Nginx сразу, без обращения к бэкенду, отдаёт пустой ответ.
###
app.get "/auth_auto_redirect.js", (req, res) ->
    if req.loggedIn
        text = "if(location.search.search('no_auth_redirect')==-1) { location.href='#{Conf.get('baseUrl')+Conf.get('app').waveUrl}'; } /* welcome back :-) */"
    else
        text = ""
    res.header('Content-Type', 'text/javascript')
    res.header('Cache-Control', 'private, no-cache, no-store, must-revalidate, max-age=0')
    res.header('Content-Length', text.length)
    res.send(text)

uiSettingsTemplate = Conf.getTemplate().compileFile('settings/ui.html')
app.get "/settings/ui/", (req, res) ->
    try
        res.send uiSettingsTemplate.render()
    catch e
        Conf.getLogger('http').error(e)
        res.send 500

###
Страница настроек.
###
SettingsView = require('../settings/view').SettingsView

#Отображает страницу настроек.
app.get(/^\/(notification\/settings|settings)\/([a-zA-Z\-]+\/([a-zA-Z\-]*))?$/, SettingsView.render)

#Принимает ajax-запросы на изменение настроек.
app.post(/^\/(notification\/settings|settings)\/([a-zA-Z\-]+)\//, SettingsView.route)

# Обновление контактов пользователя
require('./web_contacts')


###
Логирование ошибок, возникших на клиенте.
###
clientErrorFieldsToCopy = ['codeVersion', 'code', 'stacktrace', 'source', 'isMobile', 'isUncaught']
app.post "/client-log/", (req, res) ->
    if not req.isXMLHttpRequest
        serverLogger = Conf.getLogger('http')
        serverLogger.warn("Got client error request which wasn't sent with xhr")
        return res.send(403)
    if not req.body? or not req.body.message? or not req.body.codeVersion?
        serverLogger = Conf.getLogger('http')
        serverLogger.warn("Got client error request which was not parsed")
        return res.send(400)
    clientLogger = Conf.getLogger('client')
    errorData =
        ip: req.connection.remoteAddress
        userAgent: req.headers['user-agent']
        userId: req.user?.id || '0_u_0'
    for fieldName in clientErrorFieldsToCopy when req.body[fieldName]?
        errorData[fieldName] = req.body[fieldName]
    clientLogger.warn("Client error#{"/uncaught" if errorData.isUncaught}: #{req.body.message}", errorData)
    res.send('')
