{Request} = require('../../share/communication')

class BlipProcessorBase
    constructor: (@_rootRouter) ->
        @_init()

    _init: ->
        @_otProcessor = require('../ot/processor').instance

    __constructBlip: (blipData, waveViewModel, container, parentBlip, BlipViewModel) ->
        ###
        @param blipData: Object, данные блипа
        @param waveViewModel: WaveViewModel
        @param container: HTMLElement, контейнер, в котором будет отрисовываться блип
        @param parentBlip: BlipViewModel|null
        @param BlipViewModel: BlipViewModelClass
        @returns: BlipViewModel
        ###
        blipId = Math.random().toString()
        shareDoc = @_otProcessor.makeDoc(blipId, blipData, waveViewModel.getId())
        isRead = blipData.meta.isRead
        waveId = blipData.meta.waveId
        timestamp = blipData.meta.ts
        title = blipData.meta.title
        return new BlipViewModel(waveViewModel, @, shareDoc, container, parentBlip, isRead, waveId, timestamp, title)

    _processOp: (err, op, callId) =>
        if err
            @showPageError(err)
        else
            try
                @_otProcessor.processOp(op, callId)
            catch e
                @showPageError(e)

    openBlip: (waveViewModel, blipId, container, parentBlip, callback) ->
        ###
        Отправляет на сервер запрос на открытие блипа.
        Подписывается на изменение данных блипа, если он открылся без ошибок
        Если произошла ошибка, покажет сообщение об ошибке на странице,
        callback не будет вызван
        @param waveViewModel: WaveViewModel
        @param blipId: string
        @param container: HTMLElement, контейнер, в котором будет отрисовываться блип
        @param parentBlip: BlipViewModel|null
        @param callback: function
            callback(err, BlipViewModel)
        ###
        try
            if waveViewModel.isBlipRequested(blipId)
                return console.error "Blip #{blipId} is already loaded"
        catch e
            return console.warn('Wave for request blip is already closed', blipId)
        waveViewModel.setBlipAsRequested(blipId)
        setBlipAsLoaded = (blipViewModel) ->
            callback(null, blipViewModel)
            waveViewModel.addChildBlip(blipViewModel)
            waveViewModel.setBlipAsLoaded(blipViewModel)

        if blipId of waveViewModel.blipCache
            # Блип в кеше волны
            # Обработаем на следующий тик, чтобы успела создаться view волны
            window.setTimeout =>
                return unless waveViewModel.getModel() # Wave was closed before blip construct call
                blipData = waveViewModel.blipCache[blipId]
                blipViewModel = @__constructBlip(blipData, waveViewModel, container, parentBlip)
                setBlipAsLoaded(blipViewModel)
            , 0
            return

        # Запросим блип по сети
        request = new Request {blipId}, (err, blipData) =>
            return @showPageError(err) if err
            return console.warn('Wave was closed before blip construct call', blipId) unless waveViewModel.getModel()
            blipViewModel = @__constructBlip(blipData, waveViewModel, container, parentBlip)
            setBlipAsLoaded(blipViewModel)
        request.setProperty('recallOnDisconnect', true)
        @_sendGetBlipRequest(waveViewModel, request)

    _sendGetBlipRequest: (waveViewModel, request) ->
        @_rootRouter.handle('network.wave.getBlip', request)

    subscribeBlip: (blip, callId) ->
        ###
        Подписывается на изменения блипа
        @param blip: BlipModel
        @param callId: string, идентификатор подписки, в рамках которой будут присылаться операции блипа
        ###
        args =
            blipId: blip.serverId
            version: blip.getVersion()
            callId: callId
        request = new Request args, (err) =>
            return @showPageError(err) if err
        request.setProperty('recallOnDisconnect', true)
        @_rootRouter.handle('network.wave.subscribeBlip', request)

    createBlip: (waveViewModel, container, blipParams, parentBlip) ->
        ###
        Отправляет на сервер запрос на создание блипа.
        @param waveViewModel: WaveViewModel
        @param blipId: string
        @param container: HTMLElement, контейнер, в котором будет отрисовываться блип
        @param blipParams: Object,  параметры для создаваемого блипа
        @param parentBlip: BlipViewModel|null
        ###
        blipData = @_getNewBlipData(waveViewModel.getServerId(), blipParams)
        blipViewModel = @__constructBlip blipData, waveViewModel, container, parentBlip
        request = new Request {waveId: waveViewModel.getServerId(), blipParams: blipParams}, (err, res) =>
            return if blipViewModel.isClosed()
            return @showPageError(err) if err
            blipViewModel.setServerId(res)
            waveViewModel.setBlipAsRequested(res)
            waveViewModel.setBlipAsLoaded(blipViewModel)
        request.setProperty('recallOnDisconnect', true)
        request.setProperty('close-confirm', true)
        if blipParams.sourceBlipId
            @_rootRouter.handle('network.wave.createCopiedBlip', request)
        else
            delete blipParams.contributors if blipParams.contributors?
            delete blipParams.isFoldedByDefault if blipParams.isFoldedByDefault?
            @_rootRouter.handle('network.wave.createBlip', request)
        waveViewModel.addChildBlip(blipViewModel)
        return blipViewModel

    _getNewBlipData: (serverWaveId, params) ->
        params.isFoldedByDefault ||= no
        contributors = params.contributors || []
        selfId = window.userInfo.id
        hasSelfUser = no
        for contributor in contributors
            if contributor.id is selfId
                hasSelfUser = yes
        if not hasSelfUser
            contributors.push({id: selfId})
        params.contributors = contributors
        params.content ||= [{t: ' ', params: {__TYPE: "LINE", RANDOM: Math.random().toString()}}]
        meta:
            isRead: true
            title: ''
            ts: Math.floor(Date.now() / 1000)
            waveId: serverWaveId
        snapshot:
            content: params.content
            contributors: contributors
            isFoldedByDefault: params.isFoldedByDefault
            isRootBlip: false
            pluginData: {}
        v: 0

    updateBlipReader: (blipViewModel) ->
        blipModel = blipViewModel.getModel()
        return if not blipModel.serverId?
        request = new Request({blipId: blipModel.serverId}, ->)
        request.setProperty('recallOnDisconnect', true)
        @_rootRouter.handle('network.wave.updateBlipReader', request)

    showPageError: (err) =>
        ###
        Показывает ошибку, которая требует перезагрузки страницы
        @param err: object
        ###
        console.error "Got severe blip error", new Date(), err
        console.error err.stack
        showErrRequest = new Request({error: err}, ->)
        @_rootRouter.handle('pageError.showError', showErrRequest)

    showPlaybackView: (waveId, blipId) ->
        request = new Request({waveId, blipId})
        @_rootRouter.handle('playback.showPlaybackView', request)

module.exports.BlipProcessorBase = BlipProcessorBase
