BrowserEvents = require('../utils/browser_events')
BlipThread = require('./blip_thread').BlipThread

class BlipViewBase
    constructor: ->

    # TODO: define base _render as protected
    _processUnfold: =>
        blipThread = BlipThread.getBlipThread(@__blipContainer)
        blipThread.removeListener('unfold', @_processUnfold)
        @_render()

    _decThreadUnreadBlipsCount: ->
        # TODO: maybe push _parent to BlipModel
        return if not @_parent
        # TODO: make base version of it
        @removeChildFromUnreads(@__model.getId())

    _incThreadUnreadBlipsCount: ->
        # TODO: maybe push _parent to BlipModel
        return if not @_parent
        # TODO: make base version of it
        @addChildToUnreads(@__model.getId())

    __initUnreadIndicator: ->
        c = $(@__blipContainer)
        @_unreadIndicator = c.find('.js-blip-unread-indicator')[0]
        if @__unreadIndicatorHidden
            @__hideUnreadIndicator(yes)
        else
            @__showUnreadIndicator(yes)

    __initFold: =>
        ###
        Инициализирует элементы, отвечающие за свернутость и развернутость блипа
        ###
        @__blipContainer.removeEventListener(BrowserEvents.C_BLIP_INSERT_EVENT, @__initFold, false)
        blipThread = BlipThread.getBlipThread(@__blipContainer)
        isFolded = false
        if blipThread.isFirstInThread(@__blipContainer)
            # Блип является первым в треде, он определяет свернутость треда
            isFolded = @__isFoldedWithoutRendering || @__model.isFoldedByDefault()
            blipThread.initFold(isFolded)
        else
            isFolded = blipThread.isFolded()
        if not isFolded
            @_render()
        else
            blipThread.on('unfold', @_processUnfold)

    __hideUnreadIndicator: (force=false) ->
        # TODO: think of storing @__unreadIndicatorHidden var in model
        return if not force and @__unreadIndicatorHidden
        @_decThreadUnreadBlipsCount()
        @__unreadIndicatorHidden = yes
        @_unreadIndicator?.style.display = 'none'

    __showUnreadIndicator: (force=false) ->
        # TODO: think of storing @__unreadIndicatorHidden var in model
        return if not force and not @__unreadIndicatorHidden
        @_incThreadUnreadBlipsCount()
        @__unreadIndicatorHidden = no
        @_unreadIndicator?.style.display = 'block'

    updateReadState: ->
        # TODO: remove _childBlips from here
        # TODO: maybe move it to BlipViewModel
        if @__unreadIndicatorHidden
            @_decThreadUnreadBlipsCount()
        else
            @_incThreadUnreadBlipsCount()
        for blipId, blip of @_childBlips
            blip.getView().updateReadState()

    unfold: =>
        # TODO: move __isNotInRootThread somewhere
        return unless @__isNotInRootThread
        blipThread = BlipThread.getBlipThread(@__blipContainer)
        blipThread.unfold()

    fold: ->
        # TODO: move __isNotInRootThread somewhere
        # TODO: move __isFoldedWithoutRendering somewhere
        return unless @__isNotInRootThread
        blipThread = BlipThread.getBlipThread(@__blipContainer)
        if blipThread
            blipThread.fold() if blipThread.isFirstInThread(@__blipContainer)
        else
            @__isFoldedWithoutRendering = true

    unfoldToRootBlip: ->
        # TODO: maybe push it to BlipViewModel
        # TODO: parent should be BlipViewModel
        @_parent?.unfoldToRootBlip()
        @unfold()

    selectAll: ->
        # TODO: maybe remove editor from view
        @_editor.selectAll()

    setCursorToStart: ->
        # TODO: maybe remove editor from view
        @_editor.setCursorToStart()

    getChildBlips: ->
        # TODO: _childBlips should be in BlipModel
        # TODO: remove _childBlips from here
        @_childBlips

    foldAllChildBlips: =>
        # TODO: maybe move it to BlipViewModel
        # TODO: remove _childBlips from here
        for childBlipId, childBlip of @_childBlips
            childBlip.getView().fold()
            childBlip.getView().foldAllChildBlips()

    unfoldAllChildBlips: =>
        # TODO: maybe move it to BlipViewModel
        # TODO: remove _childBlips from here
        for childBlipId, childBlip of @_childBlips
            childBlip.getView().unfold()
            childBlip.getView().unfoldAllChildBlips()

    destroy: ->
        @_decThreadUnreadBlipsCount()
        @__blipContainer.removeEventListener(BrowserEvents.C_BLIP_INSERT_EVENT, @__initFold, false)
        $(@__blipContainer).off('focusin focusout')
        thread = BlipThread.getBlipThread(@__blipContainer)
        if thread
            thread.deleteBlipNode(@__blipContainer)
            thread.removeListener('unfold', @_processUnfold)

module.exports = BlipViewBase
