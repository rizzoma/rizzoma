BaseModule = require('../../share/base_module').BaseModule
History = require('../utils/history_navigation')
UrlUtil = require('../utils/url')
{Request} = require('../../share/communication')
{LocalStorage} = require('../utils/localStorage')
{trackTopicCreatedAndUserAdded} = require('../analytics/ping')
{WAVE_SHARED_STATE_PUBLIC,WAVE_SHARED_STATE_LINK_PUBLIC,WAVE_SHARED_STATE_PRIVATE} = require('../wave/model')
WaveViewModel = require('../wave/index_base').WaveViewModelBase

class WaveBase extends BaseModule
    constructor: (rootRouter, @__waveContainer) ->
        super(rootRouter)
        query = UrlUtil.getQuery()
        if query.grant_access_to?
            window.grantAccess = {user: query.grant_access_to}
        @__openCount = 0
        @__waveProcessor = require('../wave/processor').instance
        @_initSessionPings()
        if not module.exports.instance
            module.exports.instance = @

    _initSessionPings: ->
        setInterval ->
            r = new XMLHttpRequest()
            r.open('GET', "/ping/?t=#{Date.now()}")
            r.send(null)
        , window.expressSession.refreshInterval or 1200000

    _updateBlipIdInUrl: (blipId) -> History.changeBlipId(blipId)

    __showWaveLoadingError: (err) ->
        ###
        Отображает сообщение об ошибке загрузки топика
        ###
        throw new Error('not implemented')

    __showWaveCreatingError: (err) ->
        ###
        Отображает сообщение об ошибке создания топика
        ###
        throw new Error('not implemented')

    __showWave: (waveData, waveBlips, socialSharingUrl) ->
        ###
        Строит отображение волны в DOM. Должен вернуть экземпляр текущей волны
        @returns WaveViewModel
        ###
        throw new Error('not implemented')

    __showTopicCreatingWait: ->
        throw new Error('not implemented')

    __showTopicLoadingWait: ->
        throw new Error('not implemented')

    __createWaveButtonHandler: (e, analyticsProp) =>
        ###
        Обрабатывает событие нажатия кнопки CreateWave. Создает волну и сразу ее открывает
        ###
        _gaq.push(['_trackEvent', 'Topic creation', 'Create topic', analyticsProp, 1])
        doCreate = =>
            @__waveProcessor.createWave (err, waveId) =>
                @__processCreateWaveResponse(err, waveId, doCreate)
            @__showTopicCreatingWait()
        doCreate()
        e.stopPropagation()

    __processCreateWaveResponse: (err, waveId, retry) =>
        ###
        Обрабатывает ответ на операцию создания волны
        ###
        return @__showWaveCreatingError(err, retry) if err
        @__processCreateWaveSuccessResponse(waveId)

    __processCreateWaveSuccessResponse: (waveId) ->
        @__newWave = true
        trackTopicCreatedAndUserAdded(0, 1)
        LocalStorage.incTopicsCreated()
        History.navigateTo(waveId)

    __openWave: (waveId, serverBlipId) ->
        if not @__openCount
            @_firstTopicLoadStartTime = new Date()
        @__openCount += 1
        @_cancelNetworkRequest(@_curWaveOpenRequest) if @_curWaveOpenRequest?
        @_curWaveOpenRequest = @__waveProcessor.getWaveWithBlips waveId, (err, waveData, waveBlips, socialSharingUrl) =>
            @_curWaveOpenRequest = null
            return @__processOpenWaveErrorResponse(err, waveId, serverBlipId) if err
            @__processOpenWaveSuccessResponse(waveId, serverBlipId, waveData, waveBlips, socialSharingUrl)

    _cancelNetworkRequest: (requestToCancel) ->
        if not requestToCancel.callId
            console.error("Tried to cancel network request, but it does not have callId", requestToCancel)
            return
        request = new Request {callId: requestToCancel.callId}, (err) ->
            console.warn("Could not remove network request", err) if err
        @_rootRouter.handle('network.wave.removeCall', request)

    __processOpenWaveErrorResponse: (err, waveId, serverBlipId) ->
        switch err.code
            when 'wave_permission_denied'
                prefix = '/permissiondenied/topic/'
            when 'wave_document_does_not_exists'
                prefix = '/notfound/topic/'
            when 'wave_anonymous_permission_denied'
                prefix = '/unauthorized/topic/'
            else prefix = '/'+err.code+'/topic/'
        _gaq.push(['_trackPageview', prefix+waveId+'/'+document.location.search])
        _gaq.push(window.cleanupAnalytics) if document.location.search and window.cleanupAnalytics
        @__showWaveLoadingError(err, waveId, serverBlipId)

    __processOpenWaveSuccessResponse: (waveId, serverBlipId, waveData, waveBlips, socialSharingUrl) ->
        curWave = @__showWave(waveData, waveBlips, socialSharingUrl)
        curWave.on(WaveViewModel.Events.ACTIVE_BLIP_CHANGE, @_updateBlipIdInUrl)
        sharedState = curWave.getModel().getSharedState()
        prefix = '/unknown'
        switch sharedState
            when WAVE_SHARED_STATE_PRIVATE
                prefix = '/private' if window.loggedIn
            when WAVE_SHARED_STATE_PUBLIC
                if window.loggedIn
                    prefix = '/public'
                else
                    prefix = '/anonymous'
                    @__showLikeButtons()
            when WAVE_SHARED_STATE_LINK_PUBLIC
                prefix = '/bylink' if window.loggedIn
        _gaq.push(['_trackPageview', prefix+'/topic/'+waveId+'/'+document.location.search])

        if not window.loggedIn
            if sharedState is WAVE_SHARED_STATE_PUBLIC
                mixpanel.track('Visit landing', {"landing name": 'public'})
            else
                mixpanel.track('Visit landing', {"landing name": '/topic/id'})

        serverBlipId ||= curWave.getRootBlipId()
        _this = @
        if @__openCount is 1 and (access = window.grantAccess)?
            waveServerId = curWave.getModel().serverId
            setTimeout =>
                curWave.showGrantAccessForm access.user, (role, callback) =>
                    @__waveProcessor.addParticipant(waveServerId, access.user, parseInt(role), callback)
                delete window.grantAccess
            , 250
        if @__openCount is 1
            time = new Date() - @_firstTopicLoadStartTime
            label = Math.round(time / 250) * 250 # Разбиваем на временные интервалы по 250мс
            _gaq.push(['_trackEvent', 'Timings', 'Get topic by url', label+'', time])
        processWaveLoaded = ->
            _this.__processWaveLoadedEvent(@, waveId, serverBlipId)
            @removeListener('waveLoaded', processWaveLoaded)
        curWave.on('waveLoaded', processWaveLoaded)

    __showLikeButtons: () ->

    __processWaveLoadedEvent: (curWave, waveId, serverBlipId) ->
        History.setPageTitle(curWave.getTitle())
        unless curWave.hasLoadedBlip(serverBlipId)
            @showWaveWarning("Requested location not found.")
            serverBlipId = curWave.getRootBlipId()
        curWave.activateBlip(serverBlipId)
        if @__newWave or UrlUtil.getQuery().enableEditMode is '1'
            curWave.focusActiveBlip()
            @__newWave = false

    __closeCurWave: ->
        ###
        Закрывает текущий открытый топик и сообщение на месте топика
        ###
        @__curWave?.destroy()
        delete @__curWave
        @__curMessage?.destroy()
        delete @__curMessage

    __activateBlip: (wave, blipId) ->
        ###
        Активирует блип, когда он будет загружен
        @param wave: WaveViewModel
        @param blipId: string
        ###
        wave.onBlipLoaded blipId, =>
            wave.activateBlip(blipId)

    getWaveContainer: -> $('#wave')[0]

    getCurrentWave: -> @__curWave

    getCurWave: (request, args, callback)->
        # TODO: find better name to see that it's async method
        request.callback(@__curWave)

    showWaveWarning: (message) -> throw "Must be implemented"

    showWaveError: (err) -> throw "Must be implemented"

    showTopicCreatingWait: -> @__showTopicCreatingWait()


exports.WaveBase = WaveBase
