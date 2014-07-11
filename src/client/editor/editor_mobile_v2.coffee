DomUtils = require('../utils/dom')
SelectionHelper = require('./selection/html_selection_helper')
EditorV2 = require('./editor_v2').Editor
BrowserSupport = require('../utils/browser_support_mobile')
BrowserEvents = require('../utils/browser_events')
{CachedRange} = require('./cached_range')
{TextLevelParams, LineLevelParams, ModelField, ParamsField, ModelType} = require('./model')
{EventType, SPECIAL_INPUT} = require('./common')
{StringUtil} = require('../utils/string')
Diff = require('./utils/diff')
{EDIT_PERMISSION, COMMENT_PERMISSION} = require('../blip/model')

editorTmpl = -> ul 'js-editor editor', {contentEditable: 'false', spellcheck: 'false', tabIndex: '1'}

renderEditor = window.CoffeeKup.compile(editorTmpl)

SERIALIZED_TYPES = {}
SERIALIZED_INDEX = 1

serializeNonTextElement = (elType) ->
    return SERIALIZED_TYPES[elType] if SERIALIZED_TYPES[elType]?
    SERIALIZED_TYPES[elType] = SERIALIZED_INDEX++

serializeElement = (elType, el) ->
    if elType is ModelType.TEXT
        if (text = el.textContent)?
            return text
        else
            return el.innerText
    serializeNonTextElement(elType)


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
        return if @_editableElement
        @_setSelectionToElement(child, 0) if @_editable and (child = @_container.firstChild) and not @_editableElement

    applyOp: (args...) ->
        @_unbindFromEditableElement(el) if (el = @_editableElement) and @_isTmpElement(el) # blur hack
        super(args...)
        @_preserveState()

    applyOps: (args...) ->
        @_unbindFromEditableElement(el) if (el = @_editableElement) and @_isTmpElement(el) # blur hack
        super(args...)
        @_preserveState()

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

    _getLineElements: (line) ->
        res = ''
        els = []
        while (el = @__renderer.getNextElement(el)) and (params = @__renderer.getElementParams(el)) and
                ((elType = params[ParamsField.TYPE]) isnt ModelType.LINE)
            text = serializeElement(elType, el)
            res += text
            els.push({params, text, length: text.length})
        els

    _handleKeyEvent: (event) ->
        eventType = @_getKeyEventType(event)
        @_clearCachedRange()
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
        @_clearState()
        @_unbindFromEditableElement(el) if (el = @_editableElement) and @_isTmpElement(el) # blur hack
        super(args...)
        @_maybeSaveState()

    _submitOps: (args...) ->
        @_clearState()
        @_unbindFromEditableElement(el) if (el = @_editableElement) and @_isTmpElement(el) # blur hack
        super(args...)
        @_maybeSaveState()

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
        while @_renderer.getElementType(element) isnt ModelType.LINE
            element = @_renderer.getPreviousElement(element)
        element.contentEditable = 'true'
        setTimeout =>
            # wait for focus
            @_bindToEditableElement(element)
        , 0

    _getTmpElement: ->
        tmpEl = document.createElement('span')
        tmpEl.className = 'temporary-cursor-element'
        tmpEl.rzTmp = yes
        tmpEl

    _isTmpElement: (el) ->
        el.rzTmp

    _removeTmpElement: ->
        return unless @_tmpElement
        DomUtils.remove(@_tmpElement)
        @_tmpElement = null

    _insertTmpElementAfter: (afterElement) ->
        @_removeTmpElement()
        tmpEl = @_getTmpElement()
        @_renderer.insertInlineElementAfter(tmpEl, afterElement)
        @_tmpElement = tmpEl

    _makePersistentElement: (tmpEl) ->
        throw new Error('Non tmp element provided') if tmpEl isnt @_tmpElement
        tmpEl.rzTmp = no
        params = @_getElementTextParams()
        @_renderer.setParamsToElement(tmpEl, params)
        DomUtils.removeClass(tmpEl, 'temporary-cursor-element')
        @_tmpElement = null

    _setSelectionToElement: (anchorNode, anchorOffset) ->
        console.log 'setSelection', anchorNode, anchorOffset
        [element, offset] = @_getCurrentElement(anchorNode, anchorOffset)
        # contentEditable should not changed to inline elements
        elementType = @_renderer.getElementType(element)
        return unless (line = @_renderer.getParagraphNode(element))
        if line isnt @_editableElement
            @_unbindFromEditableElement(@_editableElement) if @_editableElement
            line.contentEditable = "true"
            SelectionHelper.setCaret(anchorNode, anchorOffset)
            focusLine = =>
                console.error 'touchStart triggered'
                line.removeEventListener(BrowserEvents.TOUCH_START_EVENT, focusLine, no)
                line.focus()
                @_bindToEditableElement(line)
            try e = BrowserEvents.createTouchEvent(BrowserEvents.TOUCH_START_EVENT, yes, yes)
            if e
                line.addEventListener(BrowserEvents.TOUCH_START_EVENT, focusLine, no)
                line.dispatchEvent(e)
            else
                focusLine()
            return
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
                anchorNode = @_insertTmpElementAfter(element)
                anchorOffset = 0
                @_saveState()
                console.warn 'insert tmp element'

        SelectionHelper.setCaret(anchorNode, anchorOffset)

    _getLineNodes: (line) ->
        nodes = []
        texts = []
        for node in line.childNodes
            nodes.push(node)
            if @__renderer.getElementType(node) is ModelType.TEXT or @_isTmpElement(node)
                texts.push(node.textContent)
            else
                texts.push(' ')
        [nodes, texts]

    _clearState: ->
        @_oldEls = null
        @_oldTexts = null

    _saveState: ->
        [@_oldEls, @_oldTexts] = @_getLineNodes(@_editableElement)

    _maybeSaveState: ->
        @_saveState() if !@_oldEls and @_editableElement

    _preserveState: ->
        return unless @_editableElement
        @_maybeInsertTmpElement()
        @_saveState()

    _maybeInsertTmpElement: ->
        range = SelectionHelper.getRangeInside(@_container)
        console.log 'maybeInsertTmpEl', range
        return unless range
        return if not range.collapsed
        @_setSelectionToElement(range.startContainer, range.startOffset)

    _cleanLineElements: (line) ->
        _ref = line.childNodes
        return unless _ref.length
        for i in [_ref.length - 1 .. 0]
            el = _ref[i]
            if DomUtils.isTextNode(el) and not el.data
                DomUtils.remove(el)
                continue
            if DomUtils.isBrElement(el) and line.lastChild isnt el
                DomUtils.remove(el)
                continue
        if not DomUtils.isBrElement(line.lastChild)
            line.appendChild(document.createElement('br'))

    _cleanLine: (line) ->
        _ref = line.childNodes
        return unless _ref.length
        @_removeTmpElement()
        for i in [_ref.length - 1 .. 0]
            el = _ref[i]
            if DomUtils.isTextNode(el) and not el.data
                DomUtils.remove(el)
                continue
            if @_renderer.getElementType(el) is ModelType.TEXT and not el.textContent
                DomUtils.remove(el)
        @_cleanLineElements(line)

    _getLineNodes: (line) ->
        nodes = []
        texts = []
        for node in line.childNodes
            nodes.push(node)
            if @__renderer.getElementType(node) is ModelType.TEXT or @_isTmpElement(node)
                texts.push(node.textContent)
            else
                texts.push(' ')
        [nodes, texts]

    _clearState: ->
        @_oldEls = null
        @_oldTexts = null

    _saveState: ->
        [@_oldEls, @_oldTexts] = @_getLineNodes(@_editableElement)

    _maybeSaveState: ->
        @_saveState() if !@_oldEls and @_editableElement

    _preserveState: ->
        return unless @_editableElement
        @_maybeInsertTmpElement()
        @_saveState()

    _maybeInsertTmpElement: ->
        range = SelectionHelper.getRangeInside(@_container)
        console.log 'maybeInsertTmpEl', range
        return unless range
        return if not range.collapsed
        @_setSelectionToElement(range.startContainer, range.startOffset)

    _cleanLineElements: (line) ->
        _ref = line.childNodes
        for i in [_ref.length - 1 .. 0]
            el = _ref[i]
            if DomUtils.isTextNode(el) and not el.data
                DomUtils.remove(el)
                continue
            if DomUtils.isBrElement(el) and line.lastChild isnt el
                DomUtils.remove(el)
                continue
        if not DomUtils.isBrElement(line.lastChild)
            line.appendChild(document.createElement('br'))

    _cleanLine: (line) ->
        _ref = line.childNodes
        for i in [_ref.length - 1 .. 0]
            el = _ref[i]
            if DomUtils.isTextNode(el) and not el.data || @_isTmpElement(el)
                DomUtils.remove(el)
                continue
            if @_renderer.getElementType(el) is ModelType.TEXT and not el.textContent
                DomUtils.remove(el)
        @_cleanLineElements(line)

    _bindToEditableElement: (el) ->
        if el isnt document.activeElement
            return @_unbindFromEditableElement(el)
        console.log '_bindToEditableElement', el
        try @emit('focused')
        @_cleanLine(el)
        @_editableElement = el
        @_preserveState()
        delete @_cachedRange
        el.addEventListener(BrowserEvents.BLUR_EVENT, @_handleTargetBlur, false)
        el.addEventListener(BrowserEvents.INPUT_EVENT, @_handleElementInput, false)

    _unbindFromEditableElement: (el) ->
        console.log 'unbindFromEditableElement', el
        el.contentEditable = 'false'
        el.removeAttribute('contentEditable', 0)
        el.removeEventListener(BrowserEvents.BLUR_EVENT, @_handleTargetBlur, false)
        el.removeEventListener(BrowserEvents.INPUT_EVENT, @_handleElementInput, false)
        @_cleanLine(el)
        @_editableElement = null if @_editableElement is el
        @clearCursor() if @_cursor

    _getNewLineOp: ->
        params = {}
        params[ParamsField.TYPE] = ModelType.LINE
        params[ParamsField.RANDOM] = Math.random()
        {ti: ' ', params: params}

    __applyTextModifiers: (params) ->
        for key, value of @_modifiers
            if value is null
                delete params[key]
            else
                params[key] = value

    _getTextParamsFromElements: (els, offset, length) ->
        index = 0
        res = []
        el = els[index]
        while offset and el
            break if el.length > offset
            offset -= el.length
            el = els[++index]
        return null unless el
        wholeText = ''
        while length
            return null unless el
            if offset + length <= el.length
                text = el.text.substr(offset, length)
                wholeText += text
                res.push({text, params: el.params})
                break
            availableLength = el.length - offset
            text = el.text.substr(offset, availableLength)
            wholeText += text
            res.push({text, params: el.params})
            length -= availableLength
            offset = 0
            el = els[++index]
        console.warn 'text consist of several parts' if res.length > 1
        res.wholeText = wholeText
        res

    _traverseNodeTextContent: (el) ->
        text = StringUtil.traverseString(el.textContent)
        el.textContent = text if text isnt el.textContent
        text

    _normalizeTextElement: (el) ->
        normalizedText = StringUtil.traverseString(el.textContent)
        el.textContent = normalizedText
        try SelectionHelper.setCaret(el.firstChild, normalizedText.length)
        normalizedText

    _compareLineElements: (oldEls, oldTexts, newEls, offset) ->
        newIndex = 0
        ops = []
        newEl = newEls[newIndex]

        if r = SelectionHelper.getRange()
            startContainer = r.startContainer
            startOffset = r.startOffset
        insertNewTextElement = (newEl) =>
            return unless DomUtils.isTextNode(newEl)
            return DomUtils.remove(newEl) if not text = @_traverseNodeTextContent(newEl)
            console.log text
            tmp = @_insertTmpElementAfter(newEl)
            tmp.appendChild(newEl)
            @_makePersistentElement(tmp)
            params = @_renderer.getElementParams(tmp)
            ops.push({p: offset, params, ti: text})
            offset += text.length
            SelectionHelper.setCaret(startContainer, startOffset) if startContainer

        console.log 'Comparing elements', oldEls, newEls
        console.log 'texts', oldTexts
        for oldEl, oldIndex in oldEls
            if oldEl is newEl
                if @_isTmpElement(oldEl) and oldEl.textContent
                    @_makePersistentElement(oldEl)
                params = @__renderer.getElementParams(oldEl)
                type = params[ParamsField.TYPE]
                console.warn type
                if type isnt ModelType.TEXT
                    # skip non-text elements
                    if len = @_renderer.getElementLength(oldEl)
                        offset += len
                    newEl = newEls[++newIndex]
                    continue
                oldText = oldTexts[oldIndex]
                if oldEl.childNodes.length > 1
                    newText = @_normalizeTextElement(oldEl)
                else
                    newText = @_traverseNodeTextContent(oldEl)
                ops = ops.concat(Diff.getOpsFromDiff(oldText, newText, params, offset))
                offset += newText.length
                newEl = newEls[++newIndex]
                continue
            elIndex = newEls.indexOf(oldEl)
            if elIndex is -1
                params = @__renderer.getElementParams(oldEl)
                continue unless params[ParamsField.TYPE]
                # TODO: params = undefined
                ops.push({p: offset, params, td: oldTexts[oldIndex]})
                continue
            while newIndex < elIndex
                insertNewTextElement(newEl)
                newEl = newEls[++newIndex]
        newElsLength = newEls.length
        while newIndex < newElsLength
            newEl = newEls[newIndex]
            insertNewTextElement(newEl)
            newIndex += 1
        ops

    _handleElementInput: (event) =>
        event.stopPropagation()
        target = event.target
        console.error event.type
        [newEls, newTexts] = @_getLineNodes(target)
        ops = @_compareLineElements(@_oldEls, @_oldTexts, newEls, @_getOffsetBefore(target) + 1)
        @_oldEls = newEls
        @_oldTexts = newTexts
        @_cleanLineElements(@_editableElement)
        @_saveState()

        console.log 'handleElementInput ops', ops
        # TODO: fix ff insert 2 autocomplete world and delete it. TypeError: element.firstChild is null
        # from renderer.getElementLength. related to TextNode.data but TextElement is empty
        try @_maybeInsertTmpElement()
        return if not ops.length
        try
            @emit('ops', ops)
        catch e
            return @emit('error', e)

    _handleTargetBlur: (event) =>
        el = event.target
        el.removeEventListener(BrowserEvents.BLUR_EVENT, @_handleTargetBlur, false)
        @_unbindFromEditableElement(el)

    _realSetCachedRange: =>
        @_setRangeTimeoutId = clearTimeout(@_setRangeTimeoutId) if @_setRangeTimeoutId?
        return unless @_cachedRange
        startElement = @_cachedRange.getStartElement()
        endElement = @_cachedRange.getEndElement()
        r = SelectionHelper.getRangeObject(startElement, @_renderer.getElementType(startElement),
                @_cachedRange.getStartOffset(), endElement, @_renderer.getElementType(endElement),
                @_cachedRange.getEndOffset())
        @_setSelectionToElement(r.startContainer, r.startOffset, @_editableElement)
        return delete @_cachedRange
        try
            SelectionHelper.setRangeObject(startElement, @_renderer.getElementType(startElement),
                    @_cachedRange.getStartOffset(), endElement, @_renderer.getElementType(endElement),
                    @_cachedRange.getEndOffset())
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
