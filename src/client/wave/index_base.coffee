WaveModel = require('./model').WaveModel
WaveView = require('./view_base')
BlipViewModel = require('../blip/index_base')
MicroEvent = require('../utils/microevent')
{ROLE_OWNER, ROLE_EDITOR, ROLE_NO_ROLE} = require('./participants/constants')
{WAVE_SHARED_STATE_PUBLIC} = require('./model')

STATE_LOADING = 0
STATE_LOADED = 1
STATE_CLOSING = 2
# Минимальное количество блипов, которое надо пометить прочитанными в публичном топике, чтобы автоматически добавится
# в участники
MIN_BLIP_COUNT_SET_READ_TO_FOLLOW = 3

class WaveViewModel
    @Events:
        ACTIVE_BLIP_CHANGE: 'activeBlipChange'
        BLIP_DESTROYED: 'blipDestroyed'

    constructor: (waveProcessor, waveData, waveBlips, socialSharingUrl, parent) ->
        @_init(waveProcessor, waveData, waveBlips, socialSharingUrl, parent)

    _init: (@_processor, waveData, @blipCache, socialSharingUrl, @_parent) ->
        @_unreadBlipsCount = 0
        @_totalBlipsCount = 0
        @_unloadBlipsCount = 0
        @_state = STATE_LOADING

        # Блипы по серверному id
        @_unreadBlips = {}
        @_loadedBlips = {}
        @_requestedBlips = {}
        @_loadBlipsCallbacks = {}

        # Блипы по клиентскому id
        @_childBlips = {}

        @_userProcessor = require('../user/processor').instance
        @_userProcessor.on('update', @_processUsersInfoUpdate)
        # TODO: remove @_model variable
        @__model = @_model = new WaveModel(waveData, socialSharingUrl)
        @__view = null
        @__initView(@_processor, waveData.snapshot.participants, @_parent.getWaveContainer())
        @on @constructor.Events.BLIP_DESTROYED, (blip) ->
            @_removeChildBlip(blip)

        @__view.on('goToNextUnread', @goToNextUnreadBlip)
        @__view.on(WaveView.Events.READ_ALL, @_readAllBlips)

        @__model.on WaveModel.EDITABLE_CHANGE, (editable) =>
            @__view.processEditableChange?(editable)
        .on WaveModel.ACTIVE_BLIP_CHANGE, (newActive, lastActive) =>
            @__emitActiveBlipIdChange(newActive)

        waveData.on 'remoteop', @_processRemoteOps
        @_waveData = waveData
        @__initBlipProcessor()
        @__initLocalStorage()
        @_blipsSetAsRead  = {}
        @_blipsSetAsReadCount = 0

    _getNextUnreadBlip: (blip, startIndex = 0) ->
        while blip
            unreadBlip = blip.getNextUnread(startIndex)
            return unreadBlip if unreadBlip
            parent = blip.getParent()
            return null unless parent
            startIndex = parent.getChildIndex(blip) + 1
            blip = parent
        null

    __initLocalStorage: ->
        # should be implemented if necessary

    __initView: (processor, participants, container) ->
        # should be implemented

    __initBlipProcessor: ->
        throw new Error('not implemented')

    _processRemoteOps: (ops) =>
        for op in ops
            root = op.p.shift()
            if root is 'participants'
                @__view.applyParticipantOp op
                @emit('participant-update')
            if root in ['sharedState', 'defaultRole']
                @__view.updatePublicState()
                @updateParticipants()
                @__view.updateInterfaceAccordingToRole()

    _processUsersInfoUpdate: (userIds) =>
        ###
        Проксирует событие обновление пользователей от процессора в событие 'usersInfoUpdate'
        ###
        @emit('usersInfoUpdate', userIds)

    __activateBlip: (blip) -> @__view.activateBlip(blip)

    __activateNextUnreadBlip: ->
        activeBlip = @__model.getActiveBlip()
        unreadBlip = null
        if activeBlip
            index = activeBlip.getCursorIndex()
            startIndex = if index then index + 1 else 0
            unreadBlip = @_getNextUnreadBlip(activeBlip, startIndex)
        if not unreadBlip
            unreadBlip = @_getNextUnreadBlip(@__view.getRootBlip(), 0)
        return unless unreadBlip
        @__activateBlip(unreadBlip)

    __focusBlip: (blip) ->
        return unless blip
        blip.focus()
        # TODO: runCheckRange will be removed in the future
        @__view.runCheckRange()

    __emitActiveBlipIdChange: (blip) ->
        blipId = blip.getNearestServerId()
        @emit(@constructor.Events.ACTIVE_BLIP_CHANGE, blipId)

    activateBlip: (blipId) ->
        blip = @_loadedBlips[blipId]
        @__activateBlip(blip) if blip

    focusActiveBlip: -> @__focusBlip(@__model.getActiveBlip())

    goToNextUnreadBlip: => @__activateNextUnreadBlip()

    getUser: (userId, force=no) ->
        ###
        Возвращает модель пользователя
        @param userId: string, идентификатор пользователя
        @returns: User
        ###
        @getUsers([userId], force)[0]

    getUsers: (userIds, force=no) =>
        ###
        Возвращает массив моделей пользователя
        @param userIds: [string], массив идентификаторов пользователей
        @returns: [User]
        ###
        @_userProcessor.getUsers(userIds, @_model.serverId, force)

    getParticipants: ->
        ###
        Возвращает пользователей волны
        @return: [User]
        ###
        @getUsers(@__view.getParticipantIds())

    updateParticipants: ->
        @getUsers(@__view.getParticipantIds(), true)

    getParticipantByEmail: (email) ->
        ###
        Возвращает пользователя волны по его email.
        @param email: string
        @return: User|null
        ###
        participants = @getParticipants()
        email = email.toLowerCase()
        for p in participants
            return p if p.getEmail().toLowerCase() is email
        return null

    updateUserInfo: (user) ->
        @_userProcessor.addOrUpdateUsersInfo([user])

    getView: ->
        # TODO: deprecated
        @__view

    getModel: ->
        ###
        Возвращает модель блипа
        @return WaveModel
        ###
        # TODO: deprecated
        @_model

    getId: -> @_model.id

    getServerId: -> @_model.serverId

    getRootBlipId: -> @__model.getRootBlipId()

    showGrantAccessForm: (user, add) ->
        @__view.showGrantAccessForm(@getTitle(), user, @_model.getDefaultRole(), add)

    enableEditing: ->
        # TODO: use in desktop
        @__model.setEditable(yes)
        @__model.getActiveBlip()?.setEditable(yes)
        # TODO: focus blip

    hasLoadedBlip: (blipId) -> blipId of @_loadedBlips

    destroy: ->
        @_state = STATE_CLOSING
        @_processor.closeWave(@_model.serverId, @_subscriptionCallId, @_model.id) if @_subscriptionCallId
        @_userProcessor.removeListener('update', @_processUsersInfoUpdate)
        @removeListeners('usersInfoUpdate')
        @removeListeners('waveLoaded')
        @removeAllListeners()
        if @__view.rootBlip
            @__view.rootBlip.destroy()
        delete @_unreadBlips
        delete @_loadedBlips
        delete @_requestedBlips
        for blipId of @_loadBlipsCallbacks
            delete @_loadBlipsCallbacks[blipId]
        delete @_loadBlipsCallbacks
        delete @_childBlips
        try
            @__view.destroy()
        catch e
            console.warn 'WaveView closed with error'
            console.warn e.stack
        delete @__view
        @_model.destroy()
        delete @_model
        delete @__model
        @_waveData.removeListener('remoteop', @_processRemoteOps)
        delete @_waveData
        @__deinitLocalStorage()

    # TODO: review all bottom methods

    __deinitLocalStorage: ->
        # should be implemented if necessary

    _getChildBlipByServerId: (id) ->
        for blipId, blip of @_childBlips
            return blip if blip.getModel().serverId is id

    setBlipAsRead: (serverBlipId) ->
        return if not @_unreadBlips.hasOwnProperty(serverBlipId)
        delete @_unreadBlips[serverBlipId]
        @_unreadBlipsCount -= 1
        @__updateUnreadBlipsCount()

    _needCheckPublicFollow: ->
        ###
        Возвращает true, если в топике нужно следить за прочитанными блипами для автоматического добавления в него
        ###
        return false if not window.loggedIn
        return false if @_hasAddedSelf
        return false if @_model.getSharedState() isnt WAVE_SHARED_STATE_PUBLIC
        if not @_userWasAdded
            @_userWasAdded = @_model.getRole(window.userInfo.id, false)?
        return false if @_userWasAdded
        return true

    checkBlipSetAsRead: (serverBlipId) ->
        ###
        Если пользовтель прочитает в публичном топике определенное количество блипов, то добавится в участники
        ###
        return if serverBlipId is @__model.getRootBlipId()
        return if not @_needCheckPublicFollow()
        @_blipsSetAsReadCount++
        @_blipsSetAsRead[serverBlipId] = true
        if @_blipsSetAsReadCount >= MIN_BLIP_COUNT_SET_READ_TO_FOLLOW
            @_followPublicTopic()

    _followPublicTopic: ->
        @_hasAddedSelf = true
        @_processor.addParticipant @_model.serverId, window.userInfo.email, @_model.getDefaultRole(), (err) ->
            return if err
            _gaq.push(['_trackEvent', 'Topic content', 'Follow topic', 'Make followed public auto'])

    setBlipAsUnread: (serverBlipId) ->
        return if @_unreadBlips.hasOwnProperty(serverBlipId)
        @_unreadBlips[serverBlipId] = ''
        @_unreadBlipsCount += 1
        @__updateUnreadBlipsCount()

    getUnreadBlipsCount: -> @_unreadBlipsCount

    __updateUnreadBlipsCount: ->
        ###
        Устанавливает количество непрочитанных сообщений
        @param count: int
        ###
        return if @_state isnt STATE_LOADED
        @emit('unread-blips-count', @_unreadBlipsCount)

    setBlipAsLoaded: (blip) ->
        ###
        Помечает блип загруженным, вызывает зарегистрированные обработчики
        @param blip: BlipViewModel
        ###
        blipId = blip.getModel().serverId
        return if blipId of @_loadedBlips
        @_loadedBlips[blipId] = blip
        @_subscribeBlip(blip)
        @_totalBlipsCount += 1
        @__updateTotalBlipsCount()
        @_unloadBlipsCount -= 1
        if @_unloadBlipsCount < 1
            if @_state is STATE_LOADING
                @_state = STATE_LOADED
                @emit('waveLoaded')
                @_subscribe()
                @blipCache = {}
                @__initLoadedWave()
            @__updateUnreadBlipsCount()
            @removeListeners('waveLoaded')
        return if not (blipId of @_loadBlipsCallbacks)
        callback(blip) for callback in @_loadBlipsCallbacks[blipId]
        delete @_loadBlipsCallbacks[blipId]

    _subscribeBlip: (blip) ->
        @__blipProcessor.subscribeBlip(blip.getModel(), @_subscriptionCallId) if @_state is STATE_LOADED

    __initLoadedWave: ->
        # implement if needed

    __updateTotalBlipsCount: ->
        ###
        Оповещает все компоненты об изменившемся количестве блипов в топике
        @param count: int
        ###
        #need to be implemented

    getTotalUsableBlipsCount: ->
        # Не учитываем containerBlip
        @_totalBlipsCount - 1

    _subscribe: ->
        ###
        Подписывается на изменения этой волны
        ###
        @_subscriptionCallId = @_processor.subscribeForWaveData(@)

    getWaveAndBlipsVersions: ->
        ###
        Возвращает объект с версиями волны и блипов, необходимые для подписки
        @return: object {wave: {id, version}, blips: {blipId: blipVersion}}
        ###
        versions =
            wave:
                id: @_model.serverId
                version: @_model.getVersion()
            blips: {}
        for blipId, blip of @_loadedBlips
            model = blip.getModel()
            continue if not model.serverId?
            versions.blips[model.serverId] = model.getVersion()
        return versions

    setBlipAsRemoved: (serverBlipId) ->
        ###
        Помечает блип удаленным
        @param serverBlipId: string
        ###
        if serverBlipId not of @_requestedBlips
            return console.warn("Blip #{serverBlipId} set as removed but it was not requested")
        delete @_requestedBlips[serverBlipId]
        delete @_loadedBlips[serverBlipId]
        @_totalBlipsCount -= 1
        @setBlipAsRead(serverBlipId)
        @__updateTotalBlipsCount()

    setBlipAsRequested: (serverBlipId) ->
        @_unloadBlipsCount += 1
        @_requestedBlips[serverBlipId] = true

    addChildBlip: (blip) ->
        blipId = blip.getModel().id
        if not blip.getModel().serverId?
            blip.on 'set-server-id', =>
                # Обновим url, когда блип получит серверный идентификатор
                @__emitActiveBlipIdChange(blip) if @__model.getActiveBlip() is blip
        blip.on 'remote-ops', =>
            @__view?.updateRangePos?()
        blip.on BlipViewModel.Events.DESTROYED, (blip) =>
            @emit(@constructor.Events.BLIP_DESTROYED, blip)
        @_childBlips[blipId] = blip

    _removeChildBlip: (blipViewModel) ->
        serverId = blipViewModel.getServerId()
        @setBlipAsRead(serverId) if serverId
        blipId = blipViewModel.getModel().id
        delete @_childBlips[blipId]

    isBlipRequested: (serverBlipId) ->
        serverBlipId of @_requestedBlips

    onBlipLoaded: (serverBlipId, callback) ->
        ###
        Вызовет callback, когда будет загружен блип с серверным id serverBlipId
        Если этот блип уже загружен, вызовет callback сразу
            callback(BlipViewModel)
        @param serverBlipId: string
        @param callback: function
        ###
        if serverBlipId of @_loadedBlips
            callback(@_loadedBlips[serverBlipId])
            return
        @_loadBlipsCallbacks[serverBlipId] = [] if not (serverBlipId of @_loadBlipsCallbacks)
        @_loadBlipsCallbacks[serverBlipId].push(callback)

    getLoadedBlip: (blipId) ->
        # TODO: deprecated
        return @_loadedBlips[blipId] if blipId of @_loadedBlips

    getTitle: ->
        @_loadedBlips[@getModel()?.getRootBlipId()]?.getModel()?.title || ''

    getRole: ->
        ###
        Возвращает роль текущего залогиненного участника
        ###
        return ROLE_OWNER if window.testAsOwner
        return ROLE_NO_ROLE if not window.userInfo?
        role = @_model.getRole(window.userInfo.id)
        if role is ROLE_NO_ROLE and @_model.getSharedState() is WAVE_SHARED_STATE_PUBLIC
            role = @_model.getDefaultRole()
        return role

    isLoaded: ->
        @_state isnt STATE_LOADING

    haveEmails: ->
        @getRole() in [ROLE_OWNER, ROLE_EDITOR] or
            @_model.getSharedState() isnt WAVE_SHARED_STATE_PUBLIC

    _readAllBlips: =>
        # TODO: implement the whole _readAll process
        @_processor.updateReaderForAllBlips @_model.serverId, (err) =>
            return @showWarning(err.message) if err
            rootBlip = @__view.getRootBlip()
            rootBlip.markAsReadRecursively()
            @_followPublicTopic() if @_needCheckPublicFollow()

    showWarning: (message) ->
        @_parent.showWaveWarning(message)

    showError: (err) ->
        @_parent.showWaveError(err)

    getBlipByServerId: (id) ->
        return @_loadedBlips[id]

MicroEvent.mixin(WaveViewModel)


exports.WaveViewModelBase = WaveViewModel
exports.STATE_LOADING = STATE_LOADING
exports.STATE_LOADED = STATE_LOADED
exports.STATE_CLOSING = STATE_CLOSING
