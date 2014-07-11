DomUtils = require('../utils/dom')
MicroEvent = require('../utils/microevent')
BrowserEvents = require('../utils/browser_events')

blipThreadTmpl = ->
    div 'fold-button-container', {contentEditable: 'false'}, ->
        span 'js-fold-button fold-button', ->
            div ->
                img {src: "/s/img/empty_pixel.png", height: '20px', width: '18px'}
                div '', ''
                img '.plus-minus', {src: "/s/img/plus_minus.png"}
    div 'js-blips-container blips-container', ''

renderBlipThread = window.CoffeeKup.compile(blipThreadTmpl)

ANIMATED_CLASS = 'animated'
ANIMATION_DURATION = 3000
FOLDED_CLASS = 'folded'

class BlipThread
    constructor: (@_threadId, blipNode) ->
        @_unreadBlips = {}
        @_blipNodes = []
        @_container = document.createElement('span')
        @_container.contentEditable = 'false'
        @_container.className = 'blip-thread'
        @_container.rzContainer = yes
        @_container.rzBlipThread = @
        @_container.innerHTML = renderBlipThread()
        @_blipsContainer = @_container.getElementsByClassName('js-blips-container')[0]
        @initFold(true)
        if blipNode
            @appendBlipElement(blipNode)

    _toggleFold: =>
        ###
        Изменяет свернутость треда
        ###
        if @_folded then @_unfold() else @_fold(no)

    _setAnimated: (animated) ->
        if animated
            DomUtils.addClass(@_container, ANIMATED_CLASS)
        else
            DomUtils.removeClass(@_container, ANIMATED_CLASS)

    _unfold: ->
        @_folded = no
        DomUtils.removeClass(@_container, FOLDED_CLASS)
        @_animationTimer = window.clearTimeout(@_animationTimer) if @_animationTimer
        @_setAnimated(no)
        @emit('unfold')

    _fold: (animated) ->
        return if @_folded
        @_folded = yes
        DomUtils.addClass(@_container, FOLDED_CLASS)
        return unless animated
        @_setAnimated(yes)
        @_animationTimer = window.setTimeout =>
            @_setAnimated(no)
            @_animationTimer = null
        , ANIMATION_DURATION

    _dispatchBlipInsertEvent: (blipElement) ->
        blipElement.dispatchEvent(BrowserEvents.createCustomEvent(BrowserEvents.C_BLIP_INSERT_EVENT, no, no))

    isFirstInThread: (blipNode) ->
        @_blipNodes[0] is blipNode

    getSecondBlipElement: ->
        @_blipNodes[1]

    initFold: (isFolded) ->
        ###
        Инициализирует элементы, отвечающие за свернутость и развернутость блипа
        ###
        @_foldButton = @_container.getElementsByClassName('js-fold-button')[0]
        return unless @_foldButton
        if isFolded
            @_fold(no)
        else
            @_unfold()
        @_foldButton.addEventListener('click', @_toggleFold, false)
        BrowserEvents.addPropagationBlocker(@_foldButton, BrowserEvents.MOUSE_DOWN_EVENT)
        BrowserEvents.addPropagationBlocker(@_foldButton, BrowserEvents.CLICK_EVENT)

    setAsRoot: ->
        DomUtils.addClass(@_container, 'root-thread')

    destroy: ->
        delete @_container.rzBlipThread
        delete @_blipNodes
        @_foldButton.removeEventListener('click', @_toggleFold, false) if @_foldButton
        BrowserEvents.removePropagationBlocker(@_foldButton, BrowserEvents.MOUSE_DOWN_EVENT)
        parentNode.removeChild(@_container) if (parentNode = @_container.parentNode)
        delete @_blipsContainer

    @getBlipThread: (element) ->
        ###
        @param element: HTMLElement - корневой элемент блипа, принадлежащего треда
        ###
        while element and not element.rzBlipThread
            element = element.parentNode
        element?.rzBlipThread

    splitAfterBlipNode: (blipNodeAfter) ->
        index = @_blipNodes.indexOf(blipNodeAfter)
        throw new Error('Blip node does not belong to thread') if index is -1
        index += 1
        return [@_container, null] if index is @_blipNodes.length
        splicedBlips = @_blipNodes.splice(index)
        newThread = new BlipThread(splicedBlips.shift())
        DomUtils.insertNextTo(newThread.getContainer(), @_container)
        newThread.appendBlipElement(blip) while blip = splicedBlips.shift()
        [@_container, newThread.getContainer()]

    mergeWithNext: ->
        nextNode = @_container.nextSibling
        return if not nextNode or not (nextThread = nextNode.rzBlipThread)
        return if @_threadId isnt nextThread.getId()
        blipNodes = nextThread.getBlipNodes()
        @appendBlipElement(blipNode) for blipNode in blipNodes
        nextThread.destroy()

    getBlipNodes: -> @_blipNodes

    getId: -> @_threadId

    deleteBlipNode: (blipNode) ->
        index = @_blipNodes.indexOf(blipNode)
        throw new Error('Blip node does not belong to thread') if index is -1
        @_blipNodes.splice(index, 1)
        @_blipsContainer.removeChild(blipNode)
        @destroy() unless @_blipNodes.length

    insertBlipNodeAfter: (blipNode, blipNodeAfter) ->
        index = @_blipNodes.indexOf(blipNodeAfter)
        throw new Error('Blip node does not belong to thread') if index is -1
        @_blipNodes.splice(index + 1, 0, blipNode)
        DomUtils.insertNextTo(blipNode, blipNodeAfter)
        @_dispatchBlipInsertEvent(blipNode)

    insertBlipNodeBefore: (blipNode, blipNodeBefore) ->
        index = @_blipNodes.indexOf(blipNodeBefore)
        throw new Error('Blip node does not belong to thread') if index is -1
        @_blipNodes.splice(index, 0, blipNode)
        @_blipsContainer.insertBefore(blipNode, blipNodeBefore)
        @_dispatchBlipInsertEvent(blipNode)

    appendBlipElement: (blipElement)->
        @_blipNodes.push(blipElement)
        @_blipsContainer.appendChild(blipElement)
        @_dispatchBlipInsertEvent(blipElement)

    getContainer: ->
        @_container

    unfold: -> @_unfold()

    fold: -> @_fold(yes)

    isFolded: -> @_folded

    setUnreadBlip: (blipId) ->
        @_unreadBlips[blipId] = true
        $(@_foldButton).addClass('unread')

    blipIsUnread: (blipId) -> @_unreadBlips[blipId]

    removeUnreadBlip: (blipId) ->
        delete @_unreadBlips[blipId]
        return if not @isRead()
        $(@_foldButton).removeClass('unread')

    isRead: ->
        for blipId of @_unreadBlips
            return false
        return true

MicroEvent.mixin(BlipThread)

exports.BlipThread = BlipThread