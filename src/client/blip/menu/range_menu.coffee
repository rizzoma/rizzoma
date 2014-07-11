DomUtils = require('../../utils/dom')
BrowserEvents = require('../../utils/browser_events')

tmpl = ->
    div 'range-menu hidden', ->
        button 'button', {title: 'Edit (Ctrl+E)'}, ->
            div 'icon edit-icon', ''
        button 'button', {title: 'Insert comment (Ctrl+Enter)'}, ->
            div 'icon comment-icon', ''
            span 'Comment'

render = window.CoffeeKup.compile(tmpl)
DEFAULT_LINE_HEIGHT = 12
LEFT_SHIFT = 28

class RangeMenu
    constructor: ->
        @_createDom()
        @_resetCounter()
        @_hidden = yes

    _createDom: ->
        fr = DomUtils.parseFromString(render())
        @_container = fr.firstChild
        BrowserEvents.addBlocker(@_container, BrowserEvents.MOUSE_DOWN_EVENT)
        @_editBtn = @_container.firstChild
        @_commentBtn = @_container.lastChild
        $(@_editBtn).on 'click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'To edit mode', 'context menu'])
        $(@_commentBtn).on 'click', =>
            _gaq.push(['_trackEvent', 'Blip usage', 'Insert reply', 'Re in blip context menu'])

    _showBtn: (btn) ->
        btn.style.removeProperty('display')

    _hideBtn: (btn) ->
        btn.style.display = 'none'

    _resetBtn: (btn, handler, callback) ->
        return @_hideBtn(btn) unless callback
        btn.addEventListener(BrowserEvents.CLICK_EVENT, handler, no)
        @_showBtn(btn)

    _removeHandlers: ->
        @_commentBtn.removeEventListener(BrowserEvents.CLICK_EVENT, @_handleComment, no)
        @_editBtn.removeEventListener(BrowserEvents.CLICK_EVENT, @_handleEdit, no)
        window.removeEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_handleWndEvent, yes)
        @_editCallback = null
        @_commentCallback = null

    _addHandlers: (@_commentCallback, @_editCallback) ->
        @_resetBtn(@_commentBtn, @_handleComment, @_commentCallback)
        @_resetBtn(@_editBtn, @_handleEdit, @_editCallback)
        window.addEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_handleWndEvent, yes)

    _handleEdit: =>
        try @_editCallback() if @_editCallback
        @hide()

    _handleComment: =>
        try @_commentCallback() if @_commentCallback
        @hide()

    _handleWndEvent: (e) =>
        return if DomUtils.contains(@_container, e.target)
        @hide()

    _resetCounter: ->
        @_id = ''
        @_counter = 0

    _setPos: (rect) ->
        return if @_hidden
        height = rect.bottom - rect.top
        height = DEFAULT_LINE_HEIGHT if height <= 0
        rect.left -= if @_editCallback then LEFT_SHIFT else @_container.offsetWidth / 2
        rect.top += 5 + height
        @_container.setAttribute('style', "top: #{rect.top}px; left: #{rect.left}px;")

    hide: ->
        return if @_hidden
        @_hidden = yes
        @_resetCounter()
        DomUtils.addClass(@_container, 'hidden')
        @_removeHandlers()

    show: (id, rect, parent, commentCallback, editCallback) ->
        @_hidden = no
        if id is @_id
            @_counter += 1
        else
            @_id = id
            @_counter = 1
        return if @_counter % 2
        @_removeHandlers()
        if editCallback
            DomUtils.addClass(@_container, 'edit')
        else
            DomUtils.removeClass(@_container, 'edit')
        @_addHandlers(commentCallback, editCallback)
        DomUtils.removeClass(@_container, 'hidden')
        parent.appendChild(@_container)
        @_setPos(rect)

    update: (rect) ->
        @_setPos(rect)

instance = null
module.exports.get = -> instance ?= new RangeMenu()
