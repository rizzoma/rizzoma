_ = require('underscore')
ANONYMOUS_USER_ID = 'anonymous'

fixShindig = ->
    class CustomGadget extends shindig.BaseIfrGadget
        
        constructor: (params) ->
            shindig.Gadget.call(@, params)
            @setServerBase(window.gadget.shindigUrl + '/gadgets/')
        
        getTitleBarContent: (callback) ->
            callback('')
            
        getMainContent: shindig.IfrGadget.getMainContent

        finishRender: (chrome) ->
            iframe = $(chrome).find('iframe:first')
            iframe.attr('src', @getIframeUrl())
            
        getIframeUrl: shindig.IfrGadget.getIframeUrl

    class CustomLayoutManager extends shindig.LayoutManager
        
        constructor: ->
            shindig.LayoutManager.call(@)
            @_containers = {}
        
        setGadgetChrome: (gadgetId, container) ->
            @_containers[gadgetId] = container
        
        getGadgetChrome: (gadget) ->
            return @_containers[gadget.id]
            
        unsetGadgetChrome: (gadgetId) ->
            delete @_containers[gadgetId]
    
    class CustomContainer extends shindig.IfrContainer
    
        constructor: ->
            shindig.IfrContainer.call(@)
            @gadgetClass = CustomGadget
            @layoutManager = new CustomLayoutManager()
            @setNoCache(0)
            @setParentUrl("#{location.protocol}//#{window.HOST}")
    
        getGadgets: ->
            @gadgets_
            
        removeGadget: (toRemove) ->
            for key, gadget of @gadgets_
                if gadget is toRemove
                    delete @gadgets_[key]
                    break

    shindig.container = new CustomContainer()

class OpenSocial

    LOADING_TIMEOUT: 15

    constructor: ->
        @_gadgets = {}
        @_subscribeToParticipants()
        @_subscribeToWaveEnabled()
        @_subscribeToGadgetState()

    _subscribeToParticipants: ->
        userProcessor = require('../user/processor').instance
        userProcessor.on 'update', =>
            @_triggerParticipants(key) for key of @_gadgets

    _getParticipants: ->
        wave = require('../modules/wave_base').instance
        return wave.getCurrentWave()?.getParticipants()

    _getUserId: ->
        return window.userInfo?.id or ANONYMOUS_USER_ID

    _triggerParticipants: (key) ->
        participants = @_getParticipants()
        return if not participants
        userId = @_getUserId()
        data =
            myId: userId
            authorId: userId
            participants: {}
        for participant in participants
            id = participant.getId()
            data.participants[id] = 
                id: id
                displayName: participant.getName()
                thumbnailUrl: participant.getAvatar()
        gadgets.rpc.call(key, 'wave_participants', null, data)
        
    _triggerMode: (key) ->
        editMode = if @_gadgets[key].editMode then '1' else '0'
        gadgets.rpc.call key, 'wave_gadget_mode', null,
            '${playback}': '0'
            '${edit}':  editMode

    _triggerState: (key) ->
        state = @_gadgets[key].state
        gadgets.rpc.call(key, 'wave_gadget_state', null, state)

    _triggerGadgetLoaded: (key) ->
        @_gadgets[key].gadget.onLoad()

    _subscribeToWaveEnabled: ->
        self = @
        gadgets.rpc.register 'wave_enable', ->
            key = @f
            self._triggerParticipants(key)
            self._triggerMode(key)
            self._triggerState(key)
            self._triggerGadgetLoaded(key)
            self._stopLoadingCheck(key)

    _subscribeToGadgetState: ->
        self = @
        gadgets.rpc.register 'wave_gadget_state', (data) ->
            info = self._gadgets[@f]
            return if not info
            userId = self._getUserId()
            return if userId is ANONYMOUS_USER_ID
            info.gadget.emit('update', data)

    _getGadgetKey: (gadget) ->
        for key, item of @_gadgets
            return key if gadget is item.gadget
        return null

    _getGadgetInfo: (gadget) ->
        key = @_getGadgetKey(gadget)
        return @_gadgets[key]

    _startLoadingCheck: (key) ->
        info = @_gadgets[key]
        info.checkTimeout = setTimeout ->
            _gaq.push(['_trackEvent', 'Error', 'Client error', 'Gadget loading timeout'])
            info.gadget.onError()
        , @LOADING_TIMEOUT * 1000

    _stopLoadingCheck: (key) ->
        clearTimeout(@_gadgets[key].checkTimeout)

    loadGadget: (url, state, editMode, gadget) ->
        container = shindig.container
        shindigGadget = container.createGadget(specUrl: url)
        shindigGadget.getAdditionalParams = ->
            return '&wave=1&waveId=1'
        container.addGadget(shindigGadget)
        container.layoutManager.setGadgetChrome(shindigGadget.id, gadget.getGadgetContainer())
        container.renderGadget(shindigGadget)
        key = shindigGadget.getIframeId()
        @_gadgets[key] =
            gadget: gadget
            shindig: shindigGadget
            url: url
            state: state
            editMode: editMode
        @_startLoadingCheck(key)

    reloadGadget: (gadget) ->
        info = @_getGadgetInfo(gadget)
        @unloadGadget(gadget)
        @loadGadget(info.url, info.state, info.editMode, gadget)

    unloadGadget: (gadget) ->
        info = @_getGadgetInfo(gadget)
        container = shindig.container
        container.layoutManager.unsetGadgetChrome(info.shindig.id)
        container.removeGadget(info.shindig)
        key = @_getGadgetKey(gadget)
        @_stopLoadingCheck(key)
        delete @_gadgets[key]

    _updateInitialState: (state, delta) ->
        _.extend(state, delta)
        for key, value of state
            delete state[key] if value is null

    setStateDelta: (gadget, delta) ->
        key = @_getGadgetKey(gadget)
        @_updateInitialState(@_gadgets[key].state, delta)
        gadgets.rpc.call(key, 'wave_state_delta', null, delta)

    setMode: (gadget, editMode) ->
        key = @_getGadgetKey(gadget)
        @_gadgets[key].editMode = editMode
        @_triggerMode(key)

if window.gadget.enabled
    fixShindig()

openSocial = null
exports.get = ->
    if window.gadget.enabled and not openSocial
        openSocial = new OpenSocial()
    return openSocial
