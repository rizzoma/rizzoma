WaveBase = require('./wave_base').WaveBase
WaveViewModel = require('../wave/index_mobile').WaveViewModel
Request = require('../../share/communication').Request
BrowserSupport = require('../utils/browser_support_mobile')
History = require('../utils/history_navigation')
SessionView = require('../session/view').SessionViewMobile
{logOut} = require('../wave/notification/log_out')
{WaveError} = require('../wave/notification/error')
{WaveWarning} = require('../wave/notification/warning')
{WaveMessageMobile} = require('../wave/message')

class Wave extends WaveBase
    constructor: (rootRouter) ->
        @_waveContainer = $('.js-wave-container')
        super(rootRouter, @_waveContainer[0])
        module.exports.instance = @
        @_waveProcessor = require('../wave/processor').instance
        @_createWaveButton = document.getElementsByClassName('js-create-wave-button')[0]
        # Если пользователь в неподдерживаемом браузере или не авторизован
        if not BrowserSupport.isSupported() or !window.loggedIn
            @_createWaveButton.disabled = yes
        else
            @_createWaveButton.addEventListener('click', @__createWaveButtonHandler, false)


        @_initEvents()
        @_initHistory()
        @_openWelcomeWave()
        @_initLinkClick()
        @_notificationsContainer = $('.js-wave-notifications')[0]
        #TODO: maybe preserve this
#        $('body').on 'click', '.js-logout', (e) ->
#            e.stopPropagation();
#            e.preventDefault();
#            logOut()

    _initLinkClick: ->
        # TODO: think about making this method universal for all rizzoma links
        @_waveContainer.on 'click', '.js-link-anchor', (event) ->
            return if event.which != 1 or event.ctrlKey or event.metaKey
            currentUrl = event.currentTarget.hrefOriginal
            urlParams = History.getUrlParams(currentUrl)
            if urlParams.host and urlParams.waveId
                History.navigateTo(urlParams.waveId, urlParams.serverBlipId)
                event.preventDefault()
            event.stopPropagation()

    _initHistory: ->
        History.on('statechange', @_processURLChange)
        History.init(@_processURLChange)
        if History.analyticsRemoved
            {waveId, serverBlipId} = History.getCurrentParams()
            @_processURLChange(waveId, serverBlipId)

    _initEvents: ->
        ###
        Подписывается на события, вызываемые в результате действий пользователя
        ###
        document.body.addEventListener('focus', (event) ->
            # clear selection if focus event occurred on body element
            selection = window.getSelection()
            if selection
                selection.removeAllRanges()
        , false)

    __showWave: (waveData, waveBlips, socialSharingUrl) =>
        ###
        Отображает волну
        @param err: object, ошибка
        @param waveData: object, данные, необходимые для работы волны
        @param socialSharingUrl: String для формирования урла публикации волны
        ###
        @__closeCurWave()
        @__curWave = new WaveViewModel(@_waveProcessor, waveData, waveBlips, socialSharingUrl, @)
        @_curView = @__curWave.getView()
        @_waveContainer.find('.js-wave-notifications .js-wave-error').remove()
        @_waveContainer.find('.js-wave-notifications .js-wave-warning').remove()
        @__curWave

    __showWaveLoadingError: (err, waveId, serverBlipId) =>
        ###
        Отображает сообщение об ошибке, которое не относится к текущему открытому топику
        @param err: object, ошибка
        @param waveId: string
        ###
        @__closeCurWave()
        @__curMessage = new WaveMessageMobile($('#wave')[0])
        @__curMessage.showLoadingError err, waveId, =>
            @__openWave(waveId, serverBlipId)

    __showWaveCreatingError: (err, retry) =>
        @__closeCurWave()
        @__curMessage = new WaveMessageMobile($('#wave')[0])
        @__curMessage.showCreatingError(err, retry)

    createWaveWithParticipants: (request) ->
        ###
        Создает волну с указанными участниками текущей открытой волны
        @param request.args.userIds: Array
        ###
        @_waveProcessor.createWaveWithParticipants(@__curWave.getModel().serverId, request.args.userIds, @_processCreateWaveResponse)
   
    __createWaveButtonHandler: (e) =>
        @_createWaveButton.disabled = yes
        @showWavePanel()
        super(e, 'By common button')

    __processCreateWaveResponse: (args...) =>
        @_createWaveButton.disabled = no
        super(args...)

    _processURLChange: (waveId, serverBlipId) =>
        ###
        Обрабатывает изменение url'а
        ###
        SessionView.updateLoginUrls()
        if waveId
            @showWavePanel()
            if @__curWave?.getModel().serverId is waveId
                @__activateBlip(@__curWave, serverBlipId) if serverBlipId
            else
                @__openWave(waveId, serverBlipId)
        else
            @__openCount += 1 unless @__openCount
            @hideWavePanel()

    __openWave: (waveId, serverBlipId) ->
        ###
        Открывает волну с указанным waveId и пролистывает к блипу
        с serverBlipId, если он указан
        ###
        SessionView.hide()
        @__showTopicLoadingWait()
        super(waveId, serverBlipId)

    __processWaveLoadedEvent: (curWave, waveId, serverBlipId) ->
        needEditMode = if @__newWave or /(\?|&)enableEditMode=1(&|$)/.test(location.search) then yes else no
        super(curWave, waveId, serverBlipId)
        SessionView.updateLoginUrls()
        @_waveProcessor.getUserContacts(->) # ask for user contacts
        _gaq.push(window.cleanupAnalytics) if document.location.search and window.cleanupAnalytics
        if needEditMode
            curWave.enableEditing()

    _openWelcomeWave: () ->
        urlParams = History.getUrlParams(window.location.pathname)
        if window.welcomeWaves and window.welcomeWaves.length and not urlParams.waveId
            History.navigateTo(window.welcomeWaves[0].waveId)

    showWavePanel: ->
        document.getElementById('wave-panel').style.display = 'block'
        document.getElementById('navigation-panel').style.display = 'none'
      
    hideWavePanel: ->
        document.getElementById('wave-panel').style.display = 'none'
        document.getElementById('navigation-panel').style.display = 'block'
        require('../navigation/mobile').instance?.scrollToActiveItem()

    showWaveWarning: (message) ->
        ###
        Показывает предупреждение, связанное с волной
        @param err: object
        ###
        warnings = $(@_notificationsContainer).find('.js-wave-warning')
        if warnings.length >= 5
            $(warnings[0]).remove()
        $(@_notificationsContainer).append(new WaveWarning(message).getContainer())
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
        console.error "Wave error occurred"
        console.error err.stack

    __showTopicCreatingWait: ->
        @__closeCurWave()
        @__curMessage = new WaveMessageMobile($('#wave')[0])
        @__curMessage.showCreatingWait()

    __showTopicLoadingWait: ->
        @__closeCurWave()
        @__curMessage = new WaveMessageMobile($('#wave')[0])
        @__curMessage.showLoadingWait()


module.exports.Wave = Wave
