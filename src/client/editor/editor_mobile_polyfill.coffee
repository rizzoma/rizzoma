DomUtils = require('../utils/dom')
SelectionHelper = require('./selection/html_selection_helper')
EditorMobile = require('./editor_mobile').Editor
BrowserEvents = require('../utils/browser_events')
BrowserSupport = require('../utils/browser_support_mobile')
{CachedRange} = require('./cached_range')
{TextLevelParams, LineLevelParams, ModelField, ParamsField, ModelType} = require('./model')
{EventType, SPECIAL_INPUT} = require('./common')
{Utf16Util} = require('../utils/string')
{EDIT_PERMISSION, COMMENT_PERMISSION} = require('../blip/model')
{TextBuffer} = require('./buffer/text')

dmp = new diff_match_patch()
dmp.Diff_Timeout = 0.02

CLICK_OFFSET = 10
polyfied = no

class Editor extends EditorMobile
    constructor: (args...) ->
        super(args...)
        return if polyfied
        DomUtils.addClass(document.body, 'editor-polyfill')
        polyfied = yes

    setEditable: (editable) ->
        return if not BrowserSupport.isSupported()
        return if editable is @_editable
        @_editable = editable

    focus: ->
        @_attachBufferAfter(child) if @_editable and (child = @_container.firstChild)
        TextBuffer.get().getContainer().focus()

    applyOps: (args...) ->
        @_cachedRange = @_getFakeRange()
        super(args...)

    destroy: ->
        if @_isBufferAttached()
            TextBuffer.get().detach(yes)
            @_editableElement = null
            @_oldText = null
        super()

    insertRecipient: (args...) ->
        TextBuffer.get().detach(yes)
        super(args...)

    insertTaskRecipient: (args...) ->
        TextBuffer.get().detach(yes)
        super(args...)

    insertTag: (args...) ->
        TextBuffer.get().detach(yes)
        super(args...)

    _submitOp: (args...) ->
        super(args...)

    _submitOps: (args...) ->
        super(args...)

    __registerDomEventHandling: ->
        @_container.addEventListener(BrowserEvents.TOUCH_START_EVENT, @_handleTouchStartEvent, no)

    __unregisterDomEventHandling: ->
        @_container.removeEventListener(BrowserEvents.TOUCH_START_EVENT, @_handleTouchStartEvent, no)

    _isBufferAttached: ->
        TextBuffer.get().getContainer().parentNode is @_container.parentNode and @_editableElement

    _getFakeRange: ->
        delete @_cachedRange
        #TODO: we should delete editable element while unbinding editable element
        return unless @_isBufferAttached()
        buffer = TextBuffer.get()
        indexStart = indexEnd = @_getOffsetBefore(@_editableElement)
        if @_renderer.getElementType(@_editableElement) is ModelType.TEXT
            offsetStart = buffer.getSelectionStart()
            offsetEnd = buffer.getSelectionEnd()
        else
            offsetStart = 1
            offsetEnd = 1
        indexStart += offsetStart
        indexEnd += offsetEnd
        new CachedRange(@, @_editableElement, offsetStart, indexStart, @_editableElement, offsetEnd, indexEnd)

    _handleKeyEvent: (event) ->
        eventType = @_getKeyEventType(event)
        switch eventType
            when EventType.INPUT
                @_cachedRange = @_getFakeRange()
                try
                    @insertTextData(String.fromCharCode(event.charCode))
                catch e
                    @emit('error', e)
                yes
            when EventType.LINE
                @_cachedRange = @_getFakeRange()
                try
                    @_handleNewLine()
                catch e
                    @emit('error', e)
                yes
            when EventType.TAB
                @_cachedRange = @_getFakeRange()
                try
                    @_handleTab(event.shiftKey)
                catch e
                    @emit('error', e)
                yes
            when EventType.DELETE
                @_cachedRange = @_getFakeRange()
                try
                    @_handleDelete(event)
                catch e
                    @emit('error', e)
                yes
            else
                no

    _handleTouchStartEvent: (event) =>
        # for text nodes only
        event.stopPropagation()
        target = event.target
        return unless target
        return unless @_editable
        type = @_renderer.getElementType(target)
        if type isnt ModelType.TEXT
            @_handleNonTextTouchEvent(target, event)
        else
            @_handleTextTouchEvent(target, event)

    _handleTouchEndEvent: (e) =>
        e.stopPropagation()
        return unless @_editableElement

    _handleTextTouchEvent: (target) ->
        @_attachBuffer(target, target.textContent)

    _handleNonTextTouchEvent: (target, event) ->
        return unless (touch = event.touches[0])
        type = @_renderer.getElementType(target) || @_renderer.getElementType(target = @_renderer.getPreviousElement(target))
        return if not target or not type
        switch type
            when ModelType.LINE
                @_handleLineTouchEvent(target, touch.clientX, touch.clientY)
            else
                @_handleInlineTouchEvent(target, touch.clientX, touch.clientY)

    _handleLineTouchEvent: (line, x, y) ->
        element = @_renderer.getNextElement(line)
        while element and (type = @_renderer.getElementType(element)) isnt ModelType.LINE
            rects = element.getClientRects()
            for rect in rects
                if rect.right >= x and rect.bottom >= y
                    console.error 'found correct element', type, element
                    switch type
                        when ModelType.TEXT
                            @_handleTextTouchEvent(element)
                        else
                            console.warn 'do nothing with inline element'
                    return
            lastElement = element
            element = @_renderer.getNextElement(element)
        unless lastElement
            return @_attachBufferAfter(line)
        switch @_renderer.getElementType(lastElement)
            when ModelType.TEXT
                @_handleTextTouchEvent(lastElement)
                # TODO: calculate from line width
                rect = lastElement.getBoundingClientRect()
                b = TextBuffer.get()
                bc = b.getContainer()
                if parseInt(w = bc.style.width) < (width = x - rect.left + 5)
                    bc.style.paddingRight = parseInt(bc.style.paddingRight) + width - w
                return
            else
                @_attachBufferAfter(lastElement)

    _handleInlineTouchEvent: (element, x, y) ->
        rects = element.getClientRects()
        return unless rects.length
        first = rects[0]
        last = rects[rects.length - 1]
        first = last = element.getBoundingClientRect()
        if first.left + CLICK_OFFSET >= x and first.top <= y and first.bottom >= y
            prev = @_renderer.getPreviousElement(element)
            if prev
                if @_renderer.getElementType(prev) is ModelType.TEXT
                    @_handleTextTouchEvent(prev)
                    # TODO: calculate from line width
                    rect = prev.getBoundingClientRect()
                    bc = TextBuffer.get().getContainer()
                    if parseInt(w = bc.style.width) < (width = x - rect.left + 5)
                       bc.style.paddingRight = parseInt(bc.style.paddingRight) + width - w
                    return
            return @_attachBufferAfter(prev)
        if last.right - CLICK_OFFSET <= x and last.top <= y and last.bottom >= y
            next = @_renderer.getNextElement(element)
            if next
                if @_renderer.getElementType(next) is ModelType.TEXT
                    @_handleTextTouchEvent(next)
                    return
            return @_attachBufferAfter(element)
        TextBuffer.get().detach(yes)

    _attachBuffer: (target, text, offset) ->
        buffer = TextBuffer.get()
        buffer.attachToTarget(@_container.parentNode, target, text, @_handleElementInput, @_processKeyEvent, offset)
        @_oldText = text
        @_editableElement = target
        try @emit('focused')

    _attachBufferAfter: (target) ->
        @_oldText = ''
        @_editableElement = target
        tmp = document.createElement('span')
        tmp.textContent = '.'
        if @_renderer.getElementType(target) is ModelType.LINE
            target.insertBefore(tmp, target.firstChild)
        else
            while target and @_renderer.getElementType(target) isnt ModelType.LINE
                prev = target
                target = prev.parentNode
            DomUtils.insertNextTo(tmp, prev)
        buffer = TextBuffer.get()
        buffer.attachToTarget(@_container.parentNode, tmp, '', @_handleElementInput, @_processKeyEvent, 0)
        DomUtils.remove(tmp)
        try @emit('focused')

    _handleElementInput: (event) =>
        event.stopPropagation()
        target = event.target
        buffer = TextBuffer.get()
        text = buffer.getValue()
        newLine = text.indexOf('\n')
        newText = Utf16Util.traverseString(target.value)
        target.value = newText if target.value isnt newText
        editableType = @_renderer.getElementType(@_editableElement)
        if newLine isnt -1
            @_cachedRange = new CachedRange(@, @_container.firstChild, 1, 1, @_container.firstChild, 1, 1)
            offset = @_getOffsetBefore(@_editableElement)
            if editableType is ModelType.TEXT
                offset += newLine
            else
                offset += @_renderer.getElementLength(@_editableElement)
            op = @_getNewLineOp()
            op.p = offset
            try
                @_submitOp(op)
            catch e
                @emit('error', e)
            return
        diff = dmp.diff_main(@_oldText, newText)
        return unless diff.length
        offset = @_getOffsetBefore(@_editableElement)
        ops = []
        if editableType is ModelType.TEXT
            params = @_renderer.getElementParams(@_editableElement)
        else
            offset += @_renderer.getElementLength(@_editableElement)
            params = {}
            params[ParamsField.TYPE] = ModelType.TEXT
        for d in diff
            switch d[0]
                when DIFF_DELETE
                    ops.push({p: offset, params: params, td: d[1]})
                    continue
                when DIFF_INSERT
                    ops.push({p: offset, params: params, ti: d[1]})
            offset += d[1].length
        if @_permission is COMMENT_PERMISSION
            r = @_getCachedRange()
            offset = r.getEndOffset() || 0
            target.value = @_oldText
            offset = @_oldText.length if offset > @_oldText.length
            r = document.createRange()
            r.setEnd(target.firstChild, offset)
            r.collapse(no)
            delete @_cachedRange
            SelectionHelper.setRange(r)
            @_getCachedRange(no)
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                newOps = [@_getNewLineOp()]
                for op in ops
                    newOps.push(op) if op.ti
                editor.setInitialOps(newOps)
        @clearCursor() if @_cursor
        try
            # hack for cached range
            @_cachedRange = new CachedRange(@, @_editableElement, 0, 0, @_ediableElement, 0, 0)
            @_submitOps(ops)
        catch e
            return @emit('error', e)

    _realSetCachedRange: =>
        @_setRangeTimeoutId = clearTimeout(@_setRangeTimeoutId) if @_setRangeTimeoutId?
        return unless @_cachedRange
        startElement = @_cachedRange.getStartElement()
        startOffset = @_cachedRange.getStartOffset()
        startType = @_renderer.getElementType(startElement)
        if startType isnt ModelType.TEXT and not startOffset
            startElement = @_renderer.getPreviousElement(startElement)
            startOffset = @_renderer.getElementLength(startElement)
        switch startType
            when ModelType.TEXT
                @_attachBuffer(startElement, startElement.textContent, startOffset)
            else
                @_attachBufferAfter(startElement)
        return delete @_cachedRange

exports.Editor = Editor
