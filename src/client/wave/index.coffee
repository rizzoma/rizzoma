{WaveViewModelBase, STATE_LOADED} = require('./index_base')
WaveView = require('./view').WaveView
{LocalStorage, BLIP_READ_STATE} = require('../utils/localStorage')
{BlipMenu} = require('../blip/menu')

class WaveViewModel extends WaveViewModelBase

    __initView: (processor, participants, container) ->
        @__view = new WaveView(@, processor, participants, container)

    __initBlipProcessor: ->
        @__blipProcessor = require('../blip/processor').instance

    __initLocalStorage: ->
        LocalStorage.on(BLIP_READ_STATE, @_processRemoteBlipStateChange)

    __deinitLocalStorage: ->
        LocalStorage.removeListener(BLIP_READ_STATE, @_processRemoteBlipStateChange)

    _processRemoteBlipStateChange: (params) =>
        ###
        Отмечает прочитанным блип, который был прочитан из другой вкладки
        ###
        return if not params
        {waveId, blipId, isRead} = params
        return if @_model.serverId isnt waveId
        return if not blipId?
        blip = @_getChildBlipByServerId(blipId)
        return if not blip
        if isRead
            blip.getView().markAsRead()
        else
            blip.getView().markAsUnread()

    __initLoadedWave: ->
        @__updateTotalBlipsCount()

    __updateTotalBlipsCount: ->
        return if @_state isnt STATE_LOADED
        eventParams =
            waveId: @_model.serverId
            unreadBlipsCount: @getUnreadBlipsCount()
            totalBlipsCount: @getTotalUsableBlipsCount()
        LocalStorage.updateBlipReadState(eventParams)

    __activateNextUnreadBlip: ->
        lastActive = @__model.getActiveBlip()
        super()
        if (newActive = @__model.getActiveBlip()) isnt lastActive
            newActive.focus()

    getBlipMenu: -> @_blipMenu ?= new BlipMenu()

    destroy: ->
        super()
        if @_blipMenu
            @_blipMenu.destroy()
            delete @_blipMenu

exports.WaveViewModel = WaveViewModel
