{WaveViewModelBase, STATE_LOADED} = require('./index_base')
WaveView = require('./view_mobile').WaveView

class WaveViewModel extends WaveViewModelBase

    __initView: (processor, participants, container) ->
        @__view = new WaveView(@, processor, participants, container)
        Session = require('../session/module').Session
        @__view.on('sign-in-click', ->
            Session.setAsLoggedOut()
        )

    __initBlipProcessor: ->
        @__blipProcessor = require('../blip/processor_mobile').instance

    setBlipAsRead: (serverBlipId) ->
        return if not @_unreadBlips.hasOwnProperty(serverBlipId)
        super(serverBlipId)
        window.androidJSInterface?.onBlipReadStateChange?(@_model.serverId, serverBlipId, true)
        @_processor.updateBlipIsRead(@_model.serverId, serverBlipId, true)

    setBlipAsUnread: (serverBlipId) ->
        return if @_unreadBlips.hasOwnProperty(serverBlipId)
        super(serverBlipId)
        window.androidJSInterface?.onBlipReadStateChange?(@_model.serverId, serverBlipId, false)
        @_processor.updateBlipIsRead(@_model.serverId, serverBlipId, false)

    __updateUnreadBlipsCount: ->
        return if @_state isnt STATE_LOADED
        super()
        # notify android app that blip was read
        window.androidJSInterface?.onBlipReadOrAdded?(@_model.serverId, @getUnreadBlipsCount(), @getTotalUsableBlipsCount())
        @_processor.updateSearchUnreadCount(@_model.serverId, @getUnreadBlipsCount(), @getTotalUsableBlipsCount())

    __updateTotalBlipsCount: ->
        return if @_state isnt STATE_LOADED
        # notify android app that blip was read
        window.androidJSInterface?.onBlipReadOrAdded?(@_model.serverId, @getUnreadBlipsCount(), @getTotalUsableBlipsCount())
        @_processor.updateSearchUnreadCount(@_model.serverId, @getUnreadBlipsCount(), @getTotalUsableBlipsCount())


exports.WaveViewModel = WaveViewModel
