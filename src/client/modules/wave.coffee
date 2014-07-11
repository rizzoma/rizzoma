WaveBase = require('./wave_base').WaveBase
WaveViewModel = require('../wave/index').WaveViewModel
{WaveWarning} = require('../wave/notification/warning')
{WaveError} = require('../wave/notification/error')
{WaveMessage} = require('../wave/message')
WAVE_SHARED_STATE_PUBLIC = require('../wave/model').WAVE_SHARED_STATE_PUBLIC
renderLikesForAnonymousPublic = require('../wave/template').renderLikesForAnonymousPublic
Request = require('../../share/communication').Request
MicroEvent = require('../utils/microevent')
BrowserSupport = require('../utils/browser_support')
BrowserEvents = require('../utils/browser_events')
KeyCodes = require('../utils/key_codes').KeyCodes
History = require('../utils/history_navigation')
UrlUtil = require('../utils/url')
TopicCreatingMaster = require('../creating_topic_wizard').TopicCreatingMaster
{renderDifferenceCreateButtons, renderCommonCreateButton, renderGDriveCreateButton} =
        require('../creating_topic_wizard/template')
ChromeAppPopup = require('../chrome_app_popup').ChromeAppPopup
LinkedinPopup = require('../linkedin_popup').LinkedinPopup
AccountSetupWizard = require('../account_setup_wizard').AccountSetupWizard
{logOut} = require('../wave/notification/log_out')
{LocalStorage} = require('../utils/localStorage')
socialUtil = require('../utils/social')
{trackTopicCreatedAndUserAdded} = require('../analytics/ping')

GOOGLE_CLIENT_ID = window.GOOGLE_CLIENT_ID

getGDriveTopicCreationUrl = ->
    origin = "#{location.protocol}//#{location.host}"
    url = "https://accounts.google.com/o/oauth2/auth?"
    scopes = "scope=" + encodeURIComponent("https://www.googleapis.com/auth/drive.file " +
            "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile")
    params = "&client_id=#{GOOGLE_CLIENT_ID}&response_type=code&access_type=offline" +
            "&state=" + encodeURIComponent('{"action":"create"}')
    redirect = "&redirect_uri=" +
            encodeURIComponent("#{origin}/drive-create")
    url + scopes + params + redirect

class Wave extends WaveBase
    HIDE_WIZARD_COOKIE = "h_w_c"
    constructor: (rootRouter) ->
        @_$waveContainer = $('.js-wave-container')
        @_addParticipantToPublicFlag = true
        super(rootRouter, @_$waveContainer[0])
        if not module.exports.instance
            module.exports.instance = @
        @_waveProcessor = require('../wave/processor').instance
        @_topicMaster = null
        # Если пользователь в неподдерживаемом браузере или не авторизован
        if not BrowserSupport.isSupported() or !window.loggedIn
            $('.js-create-wave').attr('disabled', 'disabled')
        @_welcomeTopicLoading = false
        @_topicsCreatedByWizard = {}
        @_topicsCreatedWithThisTeam = {}
        @_createWaveButtons = $('.js-create-wave-buttons')
        @_tabsContainer = $(".js-tabs-container")
        @__init()

    __init: ->
        @_initViewSwitchButtons()
        @_initTopicTips()
        @__initLoadContacts()
        @__renderCreateButtons()
        @__initEvents()
        @__initContactsUpdater()
        @_initHistory()
        @_initAnalytics()
        @_initAccountWizardOptions()
        @_openWelcomeWave()
        @_openTeamTopicWave()
        @_initLinkClick(@_$waveContainer)
        LocalStorage.increaseLoginCount()
        @_initChromeAppPopup()
        @_initLinkedinPopup()
        @_notificationsContainer = $('.js-wave-notifications')[0]
        $('body').on 'click', '.js-logout', (e) ->
            e.stopPropagation()
            e.preventDefault()
            logOut()

    _getUserContacts: =>
        #запрашиваем контакты с сервера
        @_waveProcessor.getUserContacts (err, users) =>
            return console.warn('Failed to load contacts', err) if err or not users
        , true

    __initLoadContacts: ->
        @_getUserContacts()
        setTimeout @_getUserContacts, 120000

    _initChromeAppPopup: ->
        return if not window.userInfo?
        if BrowserSupport.isDesktopChrome() and window.firstSessionLoggedIn and (LocalStorage.getLoginCount() is 3)
            new ChromeAppPopup()

    _initLinkedinPopup: ->
        return if not window.userInfo?
        loginCount = LocalStorage.getLoginCount()
        return if loginCount? and loginCount < 6
        return if !window.firstSessionLoggedIn
        if !LocalStorage.getLinkedinPopupShowed()
            new LinkedinPopup()

    _initAccountWizardOptions: ->
        #выставляем переменную для отображения баннера в топике
        window.showAccountSelectionBanner = window.showAccountSelectionWizard and window.loggedIn and !window.firstSessionLoggedIn
        urlParams = History.getUrlParams(window.location.pathname)
        return if !window.showAccountSelectionWizard or !window.firstSessionLoggedIn or urlParams.waveId
        @openAndInitAccountWizard()

    openAndInitAccountWizard: =>
        @_saw = new AccountSetupWizard(@_waveProcessor)
        @_saw.on 'closeAndOpenTopic', (waveId) =>
            @_saw.destroy()
            History.navigateTo(waveId) if waveId?

    _initAnalytics: ->
        $(document.body).delegate '.js-local-next-unread', 'click', ->
            _gaq.push(['_trackEvent', 'Topic content', 'Next unread click', 'Next unread message'])

    _initLinkClick: ($container) ->
        # Обработка клика на ссылку в @_$container
        $container.on 'click', 'a', (event) ->
            return if event.which != 1 or event.ctrlKey or event.metaKey
            inLinkPopup = $(event.target).closest('.js-link-anchor').length != 0
            editorParent = $(event.target).parent().parent('.js-editor')
            return if editorParent.length == 0 and !inLinkPopup # ссылка не в редакторе и не в LinkPopup
            contenteditable = editorParent.attr('contenteditable') if editorParent.attr('contenteditable')?
            contenteditable = contenteditable == 'true' if contenteditable?
            return if !inLinkPopup and contenteditable # ссылка не в contenteditable области и не в LinkPopup
            urlParams = History.getUrlParams(event.currentTarget.href)
            if urlParams.host and urlParams.waveId
                History.navigateTo(urlParams.waveId, urlParams.serverBlipId)
                event.preventDefault()
            else
                $(event.currentTarget).attr('target', '_blank')
            event.stopPropagation()

    _initHistory: ->
        History.on('statechange', @_processURLChange)
        History.init(@_processURLChange)

    __initContactsUpdater: ->
        window.updateContacts = (contacts) =>
            # Получаем объект не напрямую, а через json, поскольку IE удаляет объекты, созданные в другом окне
            contacts = JSON.parse(contacts)
            @_waveProcessor.updateUserContacts(contacts)

    _createTopicMaster: (e, analyticsProp = 'other button') =>
        e.stopPropagation()
        if @_topicMaster
            if @_topicMaster.getContainer().is(':visible')
                @_topicMaster.hide()
            else
                @_topicMaster.setPosition(e.currentTarget)
                @_topicMaster.show()
                _gaq.push(['_trackEvent', 'Wizard usage', 'Show wizard', analyticsProp]);
        else
            @_topicMaster = new TopicCreatingMaster($(document.body)[0], e.currentTarget, @, @_waveProcessor, @_processCreateWaveByWizardResponse, @__initCreateButtons, @__renderCreateButtons, HIDE_WIZARD_COOKIE)
            _gaq.push(['_trackEvent', 'Wizard usage', 'Show wizard', analyticsProp]);

    __renderCreateButtons: =>
        @_createWaveButtons.empty()
        if History.isGDrive()
            return @_createWaveButtons.append(renderGDriveCreateButton(url: getGDriveTopicCreationUrl()))
        if $.cookie(HIDE_WIZARD_COOKIE)
            @_createWaveButtons.append(renderDifferenceCreateButtons())
        else
            @_createWaveButtons.append(renderCommonCreateButton())

    __initEvents: ->
        ###
        Подписывается на события, вызываемые в результате действий пользователя
        ###
        document.body.addEventListener BrowserEvents.FOCUS_EVENT, ->
            # clear selection if focus event occurred on body element
            selection = window.getSelection()
            if selection
                selection.removeAllRanges()
        , no
        if BrowserSupport.isMozilla()
            # block escape globally to save connection
            document.addEventListener BrowserEvents.KEY_DOWN_EVENT, (event) ->
                return if event.keyCode isnt KeyCodes.KEY_ESCAPE
                event.preventDefault()
            , no
        if BrowserSupport.isSupported() and window.loggedIn
            # Если пользователь под Chrome и авторизован
            @__initCreateButtons()
        document.body.spellcheck = no
        $(window).bind('load', @_updateLoginUrl)

    __initCreateButtons: =>
        @_tabsContainer.find(".js-create-wave").off("click")
        $(".js-create-wave-by-wizard").off("click")
        @_$waveContainer.off("click.createWave")
        if $.cookie(HIDE_WIZARD_COOKIE)
            @_tabsContainer.find(".js-create-wave").on("click", (e) =>
                @__createWaveButtonHandler(e, 'By common button')
            )
            @_$waveContainer.on("click.createWave", ".js-create-wave", (e) =>
                @__createWaveButtonHandler(e, 'By button when empty')
            )
        else
            @_tabsContainer.find(".js-create-wave").on("click", (event) =>
                    $(".js-create-wave-by-wizard").trigger('click', 'common')
            )
            @_$waveContainer.on("click.createWave", ".js-create-wave", (event) =>
                $(".js-create-wave-by-wizard").trigger('click', 'when empty')
            )
        $(".js-create-wave-by-wizard").on("click", @_createTopicMaster)

    _openAuthWindow: (source, redirectUrl, e) ->
        e.preventDefault()
        e.stopPropagation()
        {contactsUpdateWindowParams} = require('../wave/processor')
        params = contactsUpdateWindowParams[source]
        window.open("/auth/#{source}/?url=#{encodeURIComponent(redirectUrl)}",
                'Loading', "width=#{params.width},height=#{params.height}")

    _updateLoginUrl: =>
        ###
        Обновляет ссылку для входа,
        ###
        redirectUrl = History.getLoginRedirectUrl()
        if History.isEmbedded()
            window.AuthDialog.setNext(location.pathname)
            $('.js-google-login-link').off('click').on 'click', (e) =>
                @_openAuthWindow('google', redirectUrl, e)
            $('.js-facebook-login-link').off('click').on 'click', (e) =>
                @_openAuthWindow('facebook', redirectUrl, e)
        else
            window.AuthDialog.setNext(redirectUrl)

    __showWave: (waveData, waveBlips, socialSharingUrl) =>
        ###
        Отображает волну
        @param err: object, ошибка
        @param waveData: object, данные, необходимые для работы волны
        @param socialSharingUrl: String для формирования урла публикации волны
        ###
        urlWaveId = History.getUrlParams(location.href)?.waveId || ''
        if @__curWave and @__curWave.getModel()?.serverId is urlWaveId
            return @__curWave
        @__closeCurWave()
        @__curWave = new WaveViewModel(@_waveProcessor, waveData, waveBlips, socialSharingUrl, @)
        @_curView = @__curWave.getView()
        @_showNextTip()
        @_$waveContainer.find('.js-wave-notifications .js-wave-error').remove()
        @_$waveContainer.find('.js-wave-notifications .js-wave-warning').remove()
        @_curView.on('wave-view-change', @_updateViewSwitchButtonsState)
        @emit('wave-change', @__curWave)
        @__curWave

    __showWaveLoadingError: (err, waveId, serverBlipId) =>
        @__closeCurWave()
        @__curMessage = new WaveMessage($('#wave')[0])
        @__curMessage.showLoadingError err, waveId, =>
            @__openWave(waveId, serverBlipId)
        @_updateLoginUrl()

    __showWaveCreatingError: (err, retry) =>
        @__closeCurWave()
        @__curMessage = new WaveMessage($('#wave')[0])
        @__curMessage.showCreatingError(err, retry)

    createWaveWithParticipants: (request) ->
        ###
        Создает волну с указанными участниками текущей открытой волны
        @param request.args.userIds: Array
        ###
        topicServerId = @__curWave.getModel().serverId
        userIds = request.args.userIds
        doCreate = =>
            @_waveProcessor.createWaveWithParticipants topicServerId, userIds, (err, waveId) =>
                @_processCreateWaveWithThisTeamResponse(err, waveId, doCreate)
            @__showTopicCreatingWait()
        doCreate()

    _processCreateWaveByWizardResponse: (err, waveId, retry) =>
        if not err
            @_topicsCreatedByWizard[waveId] = true
        @__processCreateWaveResponse(err, waveId, retry)

    _processCreateWaveWithThisTeamResponse: (err, waveId, retry) =>
        if not err
            @_topicsCreatedWithThisTeam[waveId] = true
        @__processCreateWaveResponse(err, waveId, retry)

    __processCreateWaveSuccessResponse: (waveId) ->
        @_topicMaster.destroy() if @_topicMaster
        @_topicMaster = null
        super(waveId)

    _processURLChange: (waveId, serverBlipId) =>
        ###
        Обрабатывает изменение url'а
        ###
        if not waveId
            # Перешли на начальную страницу без открытой волны, но могла остаться надпись loading
            @__openCount += 1 unless @__openCount
            @__closeCurWave()
            if not window.loggedIn
                window.AuthDialog.initAndShow(false, History.getLoginRedirectUrl())
            else
                _gaq.push(['_trackPageview'])
                _gaq.push(window.cleanupAnalytics) if window.cleanupAnalytics and document.location.search
                @__curMessage = new WaveMessage($('#wave')[0])
                @__curMessage.showCreateTopicButton()
            # переключаем флаг, чтобы больше не добавлять в публичные топики
            @_addParticipantToPublicFlag = false
            return
        if @__curWave?.getModel().serverId is waveId
            @__activateBlip(@__curWave, serverBlipId) if serverBlipId
        else
            @__openWave(waveId, serverBlipId)

    __openWave: (waveId, serverBlipId) ->
        ###
        Открывает волну с указанным waveId и пролистывает к блипу
        с serverBlipId, если он указан
        ###
        @__showTopicLoadingWait()
        super(waveId, serverBlipId)

    __showLikeButtons: ->
        socialUtil.addFacebookScript()
        $publicLikesContainer = $('.js-right-logo-public-likes')
        return if $publicLikesContainer.children().length >= 3
        $publicLikesContainer.append(renderLikesForAnonymousPublic())
        _subscribe = ->
            FB.Event.subscribe 'edge.create', (targetUrl) ->
                _gaq.push(['_trackSocial', 'facebook', 'Like', targetUrl, 'public anonymous']);
                _gaq.push(['_trackEvent', 'Social', 'Like', 'public anonymous']);
        if window.fbAsyncInit
            prevAI = window.fbAsyncInit
            window.fbAsyncInit = ->
                prevAI()
                _subscribe()
        else
            window.fbAsyncInit = ->
                _subscribe()

    __processWaveLoadedEvent: (curWave, waveId, serverBlipId)->
        if @__newWave or UrlUtil.getQuery().enableEditMode is '1'
            # включаем режим редактирования топика
            curWave.getView().setEditModeEnabled(yes)
        super(curWave, waveId, serverBlipId)
        $('.js-anonymous-notification-container').remove() if not window.loggedIn
        if @_welcomeTopicLoading and window.ymId? and window.ymId
            window["yaCounter#{window.ymId}"].hit(window.History.getState().cleanUrl, null, null)
            @_welcomeTopicLoading = false
        if @_topicsCreatedByWizard[waveId] or @_topicsCreatedWithThisTeam[waveId]
            users = @__curWave.getParticipants()
            countNew = 0
            countExisting = 0
            for user in users when user.getId() isnt window.userInfo?.id
                if user.isNewUser() then countNew++
                else countExisting++
            if @_topicsCreatedByWizard[waveId] then reason = 'By wizard' else reason = 'By create with this team'
            _gaq.push(['_trackEvent', 'Topic participants', 'Add participant new', reason, countNew]) if countNew > 0
            _gaq.push(['_trackEvent', 'Topic participants', 'Add participant existing', reason, countExisting]) if countExisting > 0
            if countNew*countExisting > 0
                userType = 'new and existing'
            else if countNew > 0
                userType = 'new'
            else
                userType = 'existing'
            mixpanel.track("Add participant", {"participant type": userType, "added via": reason, "count": countNew+countExisting, "count new": countNew, "count existing": countExisting}) if countNew+countExisting > 0
            if countNew > 0
                trackTopicCreatedAndUserAdded(countNew, 0)
                LocalStorage.incUsersAdded(countNew)
            delete @_topicsCreatedByWizard[waveId]
            delete @_topicsCreatedWithThisTeam[waveId]
        @__addParticipantToPublic(curWave)
        _gaq.push(window.cleanupAnalytics) if document.location.search and window.cleanupAnalytics
        @_updateLoginUrl()

    __addParticipantToPublic: (curWave) ->
        if @_addParticipantToPublicFlag and window.justLoggedIn and window.userInfo? and curWave.getModel().getSharedState() == WAVE_SHARED_STATE_PUBLIC and !curWave.getView().isExistParticipant(window.userInfo.email)
            @_waveProcessor.addParticipant(curWave.getModel().serverId, window.userInfo.email, curWave.getModel().getDefaultRole(), curWave.getView().processAddParticipantResponse)
        @_addParticipantToPublicFlag = false

    _openWelcomeWave: ->
        urlParams = History.getUrlParams(window.location.pathname)
        if window.welcomeWaves and window.welcomeWaves.length and not urlParams.waveId
            _gaq.push(['_setCustomVar', 4, 'videowizard', 'notshowvideo', 2])
            @_welcomeTopicLoading = true
            History.navigateTo(window.welcomeWaves[0].waveId)

    _openTeamTopicWave: ->
        return if window.welcomeWaves and window.welcomeWaves.length
        return if not window.userInfo
        return if not window.userInfo.teamTopics
        urlParams = History.getUrlParams(window.location.pathname)
        if window.userInfo.teamTopics.topics and
           window.userInfo.teamTopics.topics.length != 0 and
           not urlParams.waveId
            lastCollectionTopicId = LocalStorage.getLastCollectionTopicId()
            topicUrl = lastCollectionTopicId or window.userInfo.teamTopics.topics[0].url
            History.navigateTo(topicUrl)

    _showNextTip: (force=false) ->
        return if not @_tips.length
        return if not @_curView.showTip?
        @_curView.showTip(@_tips[@_tipNumToShow].text, @_lastTipDate, force)
        @_tipNumToShow = (@_tipNumToShow + 1) % @_tips.length

    showNextTip: (request) ->
        @_showNextTip(request.args.force)

    _initTopicTips: ->
        @_tips = []
        return if not window.tipList?.tips?.length
        @_tips = window.tipList.tips
        @_tips.sort (a, b) ->
            b.creationDate - a.creationDate
        @_tipNumToShow = 0
        @_lastTipDate = @_tips[0].creationDate

    _initViewSwitchButtons: ->
        @_$rightToolsPanel = $('.js-right-tools-panel')
        @_$rightToolsPanel.find('.js-text-view').click =>
            @__curWave?.getView().setTextView()
        @_$rightToolsPanel.find('.js-mindmap-view').click =>
            @__curWave?.getView().setMindmapView()
        @_$rightToolsPanel.find('.js-mindmap-short-view').click =>
            @_$mindmapSwitchButtonContainer.removeClass('long-mindmap-view')
            @__curWave?.getView().setShortMindmapView()
        @_$rightToolsPanel.find('.js-mindmap-long-view').click =>
            @_$mindmapSwitchButtonContainer.addClass('long-mindmap-view')
            @__curWave?.getView().setLongMindmapView()
        @_$mindmapSwitchButtonContainer = @_$rightToolsPanel.find('.js-mindmap-view-switch-buttons')

    _updateViewSwitchButtonsState: =>
        curView = @__curWave?.getView().getCurView()
        if curView is 'mindmap'
            @_$rightToolsPanel.addClass('mindmap-view')
            @_$mindmapSwitchButtonContainer.removeClass('unvisible')
        else
            @_$rightToolsPanel.removeClass('mindmap-view')
            @_$mindmapSwitchButtonContainer.addClass('unvisible')
        if not @__curWave?
            @_$mindmapSwitchButtonContainer.removeClass('long-mindmap-view')

    __closeCurWave: ->
        @emit('wave-close', @__curWave) if @__curWave?
        super()
        @_updateViewSwitchButtonsState()
        @emit('wave-change', null)

    showWaveWarning: (message) ->
        ###
        Показывает предупреждение, связанное с волной
        @param err: object
        ###
        warnings = $(@_notificationsContainer).find('.js-wave-warning')
        if warnings.length >= 5
            $(warnings[0]).remove()
        $(@_notificationsContainer).append(new WaveWarning(message).getContainer())
        $(window).trigger 'resize'
        console.warn message

    showWaveError: (err) ->
        ###
        Показывает ошибку, связанную с волной
        @param err: object
        ###
        waveError = new WaveError(err)
        errors = $(@_notificationsContainer).find('.js-wave-error')
        if errors.length >= 5
            $(errors[0]).remove()
        $(@_notificationsContainer).append(waveError.getContainer())
        $(window).trigger 'resize'
        console.error "Wave error occurred"
        console.error err.stack

    __showTopicCreatingWait: ->
        @__closeCurWave()
        @__curMessage = new WaveMessage($('#wave')[0])
        @__curMessage.showCreatingWait()

    __showTopicLoadingWait: ->
        @__closeCurWave()
        @__curMessage = new WaveMessage($('#wave')[0])
        @__curMessage.showLoadingWait()


MicroEvent.mixin Wave
module.exports.Wave = Wave