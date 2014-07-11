DomUtils = require('../../utils/dom')
BrowserEvents = require('../../utils/browser_events')

styles = ['color', 'direction', 'fontFamily', 'fontSize', 'fontStretch', 'fontStyle', 'fontWeight', 'kerning',
        'letterSpacing', 'lineHeight', 'marginLeft', 'marginRight', 'marginTop', 'marginBottom', 'overflowWrap',
        'paddingBottom', 'paddingLeft', 'paddingRight', 'paddingTop', 'textAlign', 'textAnchor', 'textDecoration',
        'verticalAlign', 'whiteSpace', 'wordBreak', 'wordSpacing', 'wordWrap']

class TextBuffer
    constructor: ->
        @_container = document.createElement('textarea')
        s = @_container.style
        s.position = 'absolute'
        s.outline = '1px solid silver'
        s.outlineOffset = '1px'
        s.resize = 'none'
        s.overflow = 'hidden'
        s.border = 'none'
        s.backgroundColor = 'rgba(255, 255, 255, 0.6)'
        s.display = 'block'
        s.zIndex = '1'
        @_container.setAttribute('tabIndex', '1')
        @_inputEventHandler = null
        @_container.addEventListener BrowserEvents.TOUCH_START_EVENT, (e) =>
            e.stopPropagation()
            @_selectionStart = null
            @_selectionEnd = null
        , no
#        area.addEventListener('blur', =>
#            return unless area.parentNode
#            area.removeEventListener('input', @_handleElementInput, false)
#            console.warn 'remove textarea'
#            try
#                DomUtils.remove(area)
#            catch e
#        , false)
    updateBox: (left, top, width, height) ->
        style = @_container.style
        if left isnt @_left
            style.left = "#{left}px"
            @_left = left
        if top isnt @_top
            style.top = "#{top}px"
            @_top = top
        if width isnt @_width
            style.width = "#{width}px"
            @_width = width
        if height isnt @_height
            style.height = "#{height}px"
            @_height = height

    attachToTarget: (parent, target, text, inputHandler, keyHandler, offset) ->
        @detach()
        return if not parent or not target
        @_target = target
        @_inputEventHandler = inputHandler
        @_keyEventHandler = keyHandler
        target.style.opacity = '0' if text
        parentRect = JSON.parse(JSON.stringify(target.parentNode.getBoundingClientRect()))
        styleDecl = if window.getComputedStyle then window.getComputedStyle(target) else target.currentStyle
        targetStyle = @_container.style
        rect = JSON.parse(JSON.stringify(target.getBoundingClientRect()))
        rects = target.getClientRects()
        firstRect = rects[0]
        diffLeft = firstRect.left - rect.left
        height = firstRect.bottom - firstRect.top
        DomUtils.convertWindowCoordsToRelative(parentRect, parent)
        DomUtils.convertWindowCoordsToRelative(rect, parent)
        for style in styles
            targetStyle[style] = styleDecl[style]
        targetStyle.textIndent = diffLeft + 'px'
        marginTop = ((height - parseInt(styleDecl.lineHeight)) / 2)
        targetStyle.marginTop = marginTop + 'px'
        targetStyle.top = rect.top + 'px'
        targetStyle.left = rect.left + 'px'
        targetStyle.width = rect.width + 'px'
        targetStyle.height = rect.height - marginTop + 'px'
        targetStyle.display = 'block'
        @_container.value = text if @_container.value isnt text
        if offset?
            @_container.selectionStart = @_container.selectionEnd = offset
            # cache selection to prevent bug http://code.google.com/p/android/issues/detail?id=15245
            @_selectionStart = @_selectionEnd = offset
        @_container.addEventListener(BrowserEvents.INPUT_EVENT, @_inputEventHandler, no)
        @_container.addEventListener(BrowserEvents.KEY_DOWN_EVENT, @_keyEventHandler, no)
        @_container.addEventListener(BrowserEvents.KEY_PRESS_EVENT, @_keyEventHandler, no)
        parent.appendChild(@_container) if parent isnt @_container.parentNode

    detach: (remove = no) ->
        return unless @_inputEventHandler
        @_container.removeEventListener(BrowserEvents.INPUT_EVENT, @_inputEventHandler, no)
        @_container.removeEventListener(BrowserEvents.KEY_DOWN_EVENT, @_keyEventHandler, no)
        @_container.removeEventListener(BrowserEvents.KEY_PRESS_EVENT, @_keyEventHandler, no)
        @_selectionStart = null
        @_selectionEnd = null
        if remove
            @_container.style.display = 'none'
            document.body.appendChild(@_container)
        @_target.style.removeProperty('opacity') if @_target
        @_inputEventHandler = null
        @_keyHandler = null
        @_target = null

    getContainer: ->
        @_container

    getValue: ->
        @_container.value

    getSelectionStart: ->
        @_selectionStart || @_container.selectionStart || 0

    getSelectionEnd: ->
        @_selectionEnd || @_container.selectionEnd || 0

    setValue: (text, params) ->
        @_container.value = text
#        @_container.textContent = text

instance = null
exports.TextBuffer =
    get: ->
        instance ?= new TextBuffer()
