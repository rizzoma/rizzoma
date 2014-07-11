DomUtils = require('../utils/dom')
SelectionHelper = require('./selection/html_selection_helper')
EditorV2 = require('./editor_v2').Editor
BrowserSupport = require('../utils/browser_support_mobile')
BrowserEvents = require('../utils/browser_events')
{CachedRange} = require('./cached_range')
{TextLevelParams, LineLevelParams, ModelField, ParamsField, ModelType} = require('./model')
{EventType, SPECIAL_INPUT} = require('./common')
{Utf16Util} = require('../utils/string')
{EDIT_PERMISSION, COMMENT_PERMISSION} = require('../blip/model')

editorTmpl = -> ul 'js-editor editor', {contentEditable: 'false', spellcheck: 'false', tabIndex: '1'}

renderEditor = window.CoffeeKup.compile(editorTmpl)
dmp = new diff_match_patch()
dmp.Diff_Timeout = 0.02

class Editor extends EditorV2
    _init: (args...) ->
        super(args...)
        @_container.addEventListener(BrowserEvents.CLICK_EVENT, @_handleClickEvent, false)

    initContent: ->
        # set content to the editor
        content = @_getSnapshot()
        try
            @_renderer.renderContent(@_container, content)
        catch e
            @emit('error', e)

    setEditable: (editable) ->
        return if not BrowserSupport.isSupported()
        return if editable is @_editable
        @_editable = editable
        unless @_editable
            @_unbindFromEditableElement(@_editableElement) if @_editableElement

    focus: ->
        @_setSelectionToElement(child, 0) if @_editable and (child = @_container.firstChild) and not @_editableElement

    applyOp: (args...) ->
        @_unbindFromEditableElement(el) if (el = @_editableElement) and el.rzTmp # blur hack
        super(args...)

    applyOps: (args...) ->
        @_unbindFromEditableElement(el) if (el = @_editableElement) and el.rzTmp # blur hack
        super(args...)

    destroy: ->
        @_container.removeEventListener(BrowserEvents.CLICK_EVENT, @_handleClickEvent, false)
        super()

    _createDom: ->
        tmpContainer = document.createElement 'span'
        $(tmpContainer).append(renderEditor(isEditable: @_editable))
        @_container = tmpContainer.firstChild

    __registerDomEventHandling: ->
        @_container.addEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_processMouseDownEvent, no)
        @_container.addEventListener(BrowserEvents.KEY_DOWN_EVENT, @_processKeyEvent, no)
        @_container.addEventListener(BrowserEvents.KEY_PRESS_EVENT, @_processKeyEvent, no)
        @_container.addEventListener(BrowserEvents.COPY_EVENT, @_processCopyEvent, no)
        @_container.addEventListener(BrowserEvents.PASTE_EVENT, @_processPasteEvent, no)

    __unregisterDomEventHandling: ->
        @_container.removeEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_processMouseDownEvent, no)
        @_container.removeEventListener(BrowserEvents.KEY_DOWN_EVENT, @_processKeyEvent, no)
        @_container.removeEventListener(BrowserEvents.KEY_PRESS_EVENT, @_processKeyEvent, no)
        @_container.removeEventListener(BrowserEvents.COPY_EVENT, @_processCopyEvent, no)
        @_container.removeEventListener(BrowserEvents.PASTE_EVENT, @_processPasteEvent, no)

    _processCopyEvent: (args...) ->
        super(args...)
        delete @_cachedRange

    _setStubbedRange: ->
        @_cachedRange = new CachedRange(@, @_container.firstChild, 1, 1, @_container.firstChild, 1, 1)

    _handleKeyEvent: (event) ->
        eventType = @_getKeyEventType(event)
        switch eventType
            when EventType.LINE
                try
                    @_handleNewLine()
                catch e
                    @emit('error', e)
                yes
            when EventType.TAB
                try
                    @_handleTab(event.shiftKey)
                catch e
                    @emit('error', e)
                yes
            when EventType.DELETE
                try
                    @_handleDelete(event)
                catch e
                    @emit('error', e)
                yes
            else
                no

    _submitOp: (args...) ->
        @_unbindFromEditableElement(el) if (el = @_editableElement) and el.rzTmp # blur hack
        super(args...)

    _submitOps: (args...) ->
        @_unbindFromEditableElement(el) if (el = @_editableElement) and el.rzTmp # blur hack
        super(args...)

    _handleClickEvent: (event) =>
        return if event.processed
        @_processCursor()
        event.processed = yes

    _processMouseDownEvent: (event) =>
        @_clearCachedRange()
        return if event.button
        event.stopPropagation()
        try @emit(event.type)
        return unless @_editable
        element = event.target
        return if DomUtils.isButtonElement(element)
        container = element
        while container and not DomUtils.hasClass(container, 'js-editor')
            return if DomUtils.hasClass(container, 'js-blips-container')
            container = container.parentNode
        return if not container or container isnt @_container
        return if element is document.activeElement
        if document.activeElement isnt element
            document.activeElement?.blur()
            return @_handleElementMouseDown(element)
        @_handleElementMouseDown(element)

    _handleElementMouseDown: (element) ->
        elementType = @_renderer.getElementType(element)
        if elementType is ModelType.TEXT
            element.contentEditable = 'true'
#            @_container.contentEditable = 'true'
            element.addEventListener(BrowserEvents.FOCUS_EVENT, @_handleTextElementFocus, false)
            element.focus()
            return
        if elementType isnt ModelType.LINE
            while @_renderer.getElementType(element) isnt ModelType.LINE
                element = @_renderer.getPreviousElement(element)
        element.contentEditable = 'true'
        element.addEventListener(BrowserEvents.FOCUS_EVENT, @_handleLineFocus, false)
        element.focus()

    _handleLineFocus: (event) =>
        event.target.removeEventListener(BrowserEvents.FOCUS_EVENT, @_handleLineFocus, false)
        setTimeout =>
            @_extractSelectionFromLine(event.target)
        , 0

    _extractSelectionFromLine: (line) ->
        return console.log('wrong editor') if line.parentNode isnt @_container
        s = window.getSelection()
        if not s or not s.anchorNode
            line.contentEditable = 'false'
            line.removeAttribute('contentEditable', 0)
            return
        @_setSelectionToElement(s.anchorNode, s.anchorOffset, line)

    _setSelectionToElement: (anchorNode, anchorOffset, prevSelected = null) ->
        [element, offset] = @_getCurrentElement(anchorNode, anchorOffset)
        elementType = @_renderer.getElementType(element)
        switch (elementType)
            when ModelType.TEXT
                anchorNode = element.firstChild
                anchorOffset = offset
            else
                elementLength = @_renderer.getElementLength(element)
                if offset is elementLength
                    newElement = @_renderer.getNextElement(element)
                    newOffset = 0
                else unless offset
                    newElement = @_renderer.getPreviousElement(element)
                    newOffset = @_renderer.getElementLength(newElement)
                if @_renderer.getElementType(newElement) is ModelType.TEXT
                    anchorNode = newElement.firstChild
                    anchorOffset = newOffset
                    element = newElement
                    break
                if not offset and newElement
                    element = newElement
                tmpEl = document.createElement('span')
                tmpEl.className = 'temporary-cursor-element'
                tmpEl.rzTmp = yes
                anchorNode = tmpEl
                anchorOffset = 0
                @_renderer.insertInlineElementAfter(tmpEl, element)
                element = tmpEl
        element.contentEditable = 'true'
        if prevSelected
            prevSelected.contentEditable = 'false'
            prevSelected.removeAttribute('contentEditable', 0)
            prevSelected.blur()

        element.focus()
        s = window.getSelection()
        r = document.createRange()
        r.setStart(anchorNode, anchorOffset)
        r.collapse(yes)
        s?.removeAllRanges()
        s?.addRange(r)
        setTimeout ->
            if s and s.anchorNode is r.startContainer and s.anchorOffset is r.startOffset
                # just another fckng chrome hack
                s.removeAllRanges()
                s.addRange(r)
        , 0
        @_bindToEditableElement(element)

    _handleTextElementFocus: (event) =>
#        @_container.contentEditable = 'false'
        event.target.removeEventListener(BrowserEvents.FOCUS_EVENT, @_handleTextElementFocus, false)
        @_bindToEditableElement(event.target)

    _bindToEditableElement: (el) ->
        if el isnt document.activeElement
            return @_unbindFromEditableElement(el)
        try @emit('focused')
        @_editableElement = el
        @_oldText = el.textContent
        delete @_cachedRange
        if window.androidJSInterface
            try window.androidJSInterface.showKeyboard?()
        el.addEventListener(BrowserEvents.BLUR_EVENT, @_handleTargetBlur, false)
        el.addEventListener(BrowserEvents.INPUT_EVENT, @_handleElementInput, false)

    _unbindFromEditableElement: (el) ->
        el.contentEditable = 'false'
        el.removeAttribute('contentEditable', 0)
        el.removeEventListener(BrowserEvents.BLUR_EVENT, @_handleTargetBlur, false)
        el.removeEventListener(BrowserEvents.INPUT_EVENT, @_handleElementInput, false)
        DomUtils.remove(el) if el.rzTmp
        @_editableElement = null if @_editableElement is el
        @clearCursor() if @_cursor

    _getNewLineOp: ->
        params = {}
        params[ParamsField.TYPE] = ModelType.LINE
        params[ParamsField.RANDOM] = Math.random()
        {ti: ' ', params: params}

    _handleElementInput: (event) =>
        event.stopPropagation()
        target = event.target
        newLine = target.textContent.indexOf('\n')
        newText = Utf16Util.traverseString(target.textContent)
        target.textContent = newText if target.textContent isnt newText
        if newLine isnt -1
            @_cachedRange = new CachedRange(@, @_container.firstChild, 1, 1, @_container.firstChild, 1, 1)
            offset = @_getOffsetBefore(target)
            offset += newLine unless target.rzTmp
            op = @_getNewLineOp()
            op.p = offset
            try
                @_submitOp(op)
            catch e
                @emit('error', e)
            return
        if target.childNodes.length > 1
            # integrity check
            console.error('integrity check failed')
            DomUtils.empty(target)
            target.appendChild(document.createTextNode(@_oldText)) if @_oldText
            return
        t = Date.now()
        diff = dmp.diff_main(@_oldText, newText)
        return unless diff.length
        offset = @_getOffsetBefore(target)
        ops = []
        params = @_renderer.getElementParams(target) or {}
        params[ParamsField.TYPE] = ModelType.TEXT unless params[ParamsField.TYPE]
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
            target.textContent = @_oldText
            offset = @_oldText.length if offset > @_oldText.length
            r = document.createRange()
            r.setEnd(target.firstChild, offset)
            r.collapse(no)
            delete @_cachedRange
            SelectionHelper.setRange(r)
            @_getCachedRange(no)
            return @_processInChildBlip (editor) =>
                return if editor.getPermission() isnt EDIT_PERMISSION
                newOps = [@_getNewLineOp()]
                for op in ops
                    newOps.push(op) if op.ti
                editor.setInitialOps(newOps)
        if ops.length is 1 and ops[0].ti of SPECIAL_INPUT and
                (ops[0].ti isnt '~'  or require('../account_setup_wizard/processor').instance.isBusinessUser())
            r = document.createRange()
            r.setEnd(target.firstChild, @_oldText.length)
            r.collapse(no)
            SelectionHelper.setRange(r)
            @_getCachedRange()
            target.textContent = @_oldText
            try
                @[SPECIAL_INPUT[ops[0].ti]]()
            catch e
                @emit('error', e)
            return
        if target.rzTmp
            delete target.rzTmp
            target.className = ''
            @_renderer.setParamsToElement(target, params)
            try
                @emit('ops', ops)
            catch e
                @emit('error', e)
            @_oldText = newText
            return
        @clearCursor() if @_cursor
        try
            @emit('ops', ops)
        catch e
            @emit('error', e)
        unless newText
            target.rzTmp = yes
            target.className = 'temporary-cursor-element'
            DomUtils.empty(target)
            @_renderer.removeParamsFromElement(target)
        @_oldText = newText

    _handleTargetBlur: (event) =>
        el = event.target
        el.removeEventListener(BrowserEvents.BLUR_EVENT, @_handleTargetBlur, false)
        @_unbindFromEditableElement(el)

    _realSetCachedRange: =>
        @_setRangeTimeoutId = clearTimeout(@_setRangeTimeoutId) if @_setRangeTimeoutId?
        return unless @_cachedRange
        startElement = @_cachedRange.getStartElement()
        endElement = @_cachedRange.getEndElement()
        if startElement is @_editableElement
            @_oldText = @_editableElement.textContent
        else
            r = SelectionHelper.getRangeObject(startElement, @_renderer.getElementType(startElement), @_cachedRange.getStartOffset(),
                endElement, @_renderer.getElementType(endElement), @_cachedRange.getEndOffset())
            @_setSelectionToElement(r.startContainer, r.startOffset, @_editableElement)
            return delete @_cachedRange
        try
            SelectionHelper.setRangeObject(startElement, @_renderer.getElementType(startElement), @_cachedRange.getStartOffset(),
                endElement, @_renderer.getElementType(endElement), @_cachedRange.getEndOffset())
        catch e
            console.warn 'failed to set range', e, startElement, @_renderer.getElementType(startElement),
                    @_cachedRange.getStartOffset(), endElement, @_renderer.getElementType(endElement),
                    @_cachedRange.getEndOffset()
        delete @_cachedRange

    setPermission: (permission) ->
        super(permission)
        for gadget in @_gadgets # TODO: remove it when edit mode will be available in mobile
            gadget.setMode(permission is EDIT_PERMISSION)

    print: (text) ->
        # for debugging purpose
        d = document.createElement('div')
        d.textContent = text
        document.body.appendChild(d)


exports.Editor = Editor
