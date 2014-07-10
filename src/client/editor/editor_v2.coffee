BrowserEvents = require('../utils/browser_events')
BrowserSupport = require('../utils/browser_support')
{Buffer} = require('./buffer')
{CachedRange} = require('./cached_range')
{KeyCodes} = require('../utils/key_codes')
{TextLevelParams, LineLevelParams, ModelField, ParamsField, ModelType} = require('./model')
{HtmlParser, TextParser, DATA_VARS, DATA_ATTRS, HtmlOpParser, OpParsedElementProcessor} = require('./parser')
{Renderer} = require('./renderer')
SelectionHelper = require('./selection/html_selection_helper')
DomUtils = require('../utils/dom')
MicroEvent = require('../utils/microevent')
{Utf16Util, matchUrls} = require('../utils/string')
{LinkPopup} = require('./link_editor/link_popup')
{LinkEditor} = require('./link_editor')
{TagInput} = require('./tag')
{NOT_PERFORMED_TASK} = require('../search_panel/task/constants')
{TaskRecipientStub} = require('../blip/task_recipient')
{BlipThread} = require('../blip/blip_thread')
{EDIT_PERMISSION, COMMENT_PERMISSION} = require('../blip/model')
getUploadForm = require('./file/upload_form').getInstance
LocalStorage = require('../utils/localStorage').LocalStorage
{Gadget} = require('./gadget')
{EventType, SPECIAL_INPUT} = require('./common')

editorTmpl = ->
    ul '.js-editor.editor', {contentEditable: @isEditable.toString(), spellcheck: 'false', tabIndex: 1}, ''

renderEditor = window.CoffeeKup.compile(editorTmpl)
SCROLL_INTO_VIEW_TIMER = 100
SCROLL_INTO_VIEW_OFFSET = -50

class SelectionAction
    @DELETE = 'DELETE'
    @TEXT = 'TEXT'
    @LINE = 'LINE'
    @UPDATE_SELECTION_INDENT = 1
    @GETTEXTPARAMS = 'GETTEXTPARAMS'
    @GETLINEPARAMS = 'GETLINEPARAMS'
    @CLEARTEXTPARAMS = 'CLEARTEXTPARAMS'
    @COPY_CONTENT = 'COPY_CONTENT'

INITIAL_LINE = {}
INITIAL_LINE[ModelField.TEXT] = ' '
INITIAL_LINE[ModelField.PARAMS] = {}
INITIAL_LINE[ModelField.PARAMS][ParamsField.TYPE] = ModelType.LINE
INITIAL_CONTENT = [INITIAL_LINE]
LINK_POPUP_TIMEOUT = 50
SET_RANGE_TIMEOUT = 500

removeArrayElement = (array, elem) ->
    index = array.indexOf(elem)
    return if index is -1
    array[index..index] = []

LAST_DRAG_OP = undefined
LAST_DRAG_OVER = undefined
LAST_DRAG_OVER_CLASS = undefined
DRAG_CALL_ME_LATER = undefined
DRAG_START_LINE = undefined
DRAG_TYPE_MARKER = 0
DRAG_COUNT = 0

DEBUG_KEY_EVENTS = no

clearDragView = ->
    DomUtils.removeClass(LAST_DRAG_OVER, LAST_DRAG_OVER_CLASS) if LAST_DRAG_OVER and LAST_DRAG_OVER_CLASS
    LAST_DRAG_OVER = undefined
    LAST_DRAG_OVER_CLASS = undefined

updateDragView = (view) ->
    return if view is LAST_DRAG_OVER
    clearDragView()
    LAST_DRAG_OVER = view

clearDragProps = ->
    clearDragView()
    LAST_DRAG_OP = undefined
    DRAG_CALL_ME_LATER = undefined
    DRAG_START_LINE = undefined
    DRAG_COUNT = 0

isDragToTop = (clientY) ->
    return unless LAST_DRAG_OVER
    r = LAST_DRAG_OVER.getBoundingClientRect()
    h = (r.bottom - r.top) / 2 + r.top
    h > clientY

class Editor
    constructor: (args...) ->
        @_init(args...)

    _init: (id, config, functions, @_alwaysShowPopupAtBottom) ->
        @_getSnapshot = functions.getSnapshot
        @_getRecipientInput = functions.getRecipientInput
        @_getRecipient = functions.getRecipient
        @_addRecipientByEmail = functions.addRecipientByEmail
        @_getTaskRecipientInput = functions.getTaskRecipientInput
        @_getTaskRecipient = functions.getTaskRecipient
        @_addTaskRecipient = functions.addTaskRecipient
        @_getChildBlip = functions.getChildBlip
        @_getNewChildBlip = functions.getNewChildBlip
        @_getScrollableElement = functions.getScrollableElement
        @_editable = no
        @_createDom()
        @__registerDomEventHandling()
        getRecipient = (id) =>
            @_getRecipient(id, @_removeInline, @_convertRecipientToTask)
        getTaskRecipient = (args...) =>
            recipient = null
            updateTaskRecipient = (data) =>
                recipient = @_updateTaskRecipient(recipient, data)
                return recipient
            removeTaskRecipient = =>
                @_removeInline(recipient)
            convertToRecipient = =>
                @_convertTaskToRecipient(recipient)
            recipient = @_getTaskRecipient(args..., updateTaskRecipient, removeTaskRecipient, convertToRecipient)
        @_renderer = new Renderer(id, config, functions.addInlineBlip, functions.removeInlineBlip, getRecipient, getTaskRecipient, @_createInlineElement)
        @_renderer.on('gadgetParamChange', @_handleGadgetParamChange)
        @_renderer.on('gadgetDelete', @_handleGadgetDelete)
        @__renderer = @_renderer # TODO: renderer as protected
        @_gadgets = []
        @_modifiers = {}
        @_setRangePaused = no

    _createDom: ->
        tmpContainer = document.createElement 'span'
        $(tmpContainer).append(renderEditor(isEditable: @_editable))
        @_container = tmpContainer.firstChild

    initContent: ->
        # set content to the editor
        try
            content = @_getSnapshot()
            if not content.length
                content = INITIAL_CONTENT
                ops = []
                for i in [content.length-1..0]
                    ops.push
                        p: 0
                        ti: content[i].t
                        params: content[i].params
            @_renderer.renderContent(@_container, content)
            @emit('ops', ops) if ops?
        catch e
            @emit('error', e)

    getCursorRectFromRange: (r) ->
        return null unless r
        [_, _, _, el, _, offset] = @_getElementsAndOffsets(r)
        return null unless (type = @_renderer.getElementType(el))
        if(type isnt ModelType.BLIP)
            return @_renderer.getCursorFromElement(el, offset)
        try
            container = BlipThread.getBlipThread(el).getContainer()
        catch e
            return null
        rects = container.getClientRects()
        if rects.length
            r = rects[rects.length - 1]
            rect = {top: r.top, left: r.right, bottom: r.top, right: r.right}
            return rect
        null

    _createInlineElement: (params) =>
        elementType = params[ParamsField.TYPE]
        switch elementType
            when ModelType.GADGET
                p = {}
                for key, value of params
                    continue if not (key[0] is '$' and key.length > 1)
                    p[@_removePrefix(key)] = value
                element = new Gadget(params[ParamsField.URL], p, @_editable)
                @_gadgets.push(element)
                element.on('update', (params) => @_handleElementUpdate(element, params))
                return element
            else
                return null

    _addPrefix: (str) ->
        '$' + str

    _removePrefix: (str) ->
        throw new Error('string does not have prefix') if str[0] isnt '$'
        str.substr(1)

    _handleElementUpdate: (element, params) ->
        container = element.getContainer()
        offset = @_getOffsetBefore(container)
        return null if not offset?
        elementParams = @_renderer.getElementParams(container)
        ops = []
        for paramName, paramValue of params
            prefixedName = @_addPrefix(paramName)
            continue if elementParams[prefixedName] == paramValue
            if elementParams[prefixedName]?
                prop = {}
                prop[prefixedName] = elementParams[prefixedName]
                op = {p: offset, paramsd: prop, len: 1}
                ops.push(op)
            if paramValue?
                prop = {}
                prop[prefixedName] = paramValue
                op = {p: offset, paramsi: prop, len: 1}
                ops.push(op)
        try
            @_submitOps(ops, no) if ops.length
        catch e
            @emit('error')

    _handleGadgetParamChange: (elementContainer, params, param, value) =>
        @_gadgetQueue ||= []
        @_opsQueue ||= []
        throw new Error('not implemented') if params[ParamsField.TYPE] isnt ModelType.GADGET
        for gadget in @_gadgets
            continue if gadget.getContainer() isnt elementContainer
            index = @_gadgetQueue.indexOf(gadget)
            if index is -1
                index = @_gadgetQueue.length
                @_gadgetQueue.push(gadget)
                @_opsQueue.push([])
            @_opsQueue[index].push([param, value])

    _flushOpsQueue: ->
        return if not @_gadgetQueue or not @_opsQueue
        for gadget, index in @_gadgetQueue
            continue if @_gadgets.indexOf(gadget) is -1
            delta = {}
            ops = @_opsQueue[index]
            for op in ops
                [param, value] = op
                paramName = @_removePrefix(param)
                delta[paramName] = value
            gadget.setStateDelta(delta)
        delete @_gadgetQueue
        delete @_opsQueue

    _handleGadgetDelete: (element) =>
        for gadget in @_gadgets
            continue if gadget.getContainer() isnt element
            gadget.destroy()
            gadget.removeAllListeners()
            removeArrayElement(@_gadgets, gadget)
            break

    __registerDomEventHandling: ->
        @_container.addEventListener(BrowserEvents.KEY_DOWN_EVENT, @_processKeyEvent, no)
        @_container.addEventListener(BrowserEvents.KEY_PRESS_EVENT, @_processKeyEvent, no)
        @_container.addEventListener(BrowserEvents.COMPOSITION_START_EVENT, @_processCompositionStartEvent, no)
        if BrowserSupport.isWebKit()
            @_container.addEventListener(BrowserEvents.TEXT_INPUT_EVENT, @_processTextInputEvent, no)
        @_container.addEventListener(BrowserEvents.COMPOSITION_UPDATE_EVENT, @_processCompositionUpdateEvent, no)
        @_container.addEventListener(BrowserEvents.COMPOSITION_END_EVENT, @_processCompositionEndEvent, no)
        @_container.addEventListener(BrowserEvents.COPY_EVENT, @_processCopyEvent, no)
        @_container.addEventListener(BrowserEvents.CUT_EVENT, @_processCutEvent, no)
        @_container.addEventListener(BrowserEvents.PASTE_EVENT, @_processPasteEvent, no)
        @_container.addEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_processMouseDownEvent, no)

        @_container.addEventListener(BrowserEvents.DRAG_START_EVENT, @_processDragStartEvent, no)
        @_container.addEventListener(BrowserEvents.DRAG_ENTER_EVENT, @_processDragEnterEvent, no)
        @_container.addEventListener(BrowserEvents.DRAG_LEAVE_EVENT, @_processDragLeaveEvent, no)
        @_container.addEventListener(BrowserEvents.DRAG_OVER_EVENT, @_processDragOverEvent, no)
        @_container.addEventListener(BrowserEvents.DROP_EVENT, @processDropEvent, no)
        @_container.addEventListener(BrowserEvents.DRAG_END_EVENT, @_processDragEndEvent, no)
        if BrowserSupport.isIe()
            @_container.addEventListener(BrowserEvents.BEFORE_PASTE_EVENT, @_processPasteEvent, no)

    __unregisterDomEventHandling: ->
        @_container.removeEventListener(BrowserEvents.KEY_DOWN_EVENT, @_processKeyEvent, no)
        @_container.removeEventListener(BrowserEvents.KEY_PRESS_EVENT, @_processKeyEvent, no)
        @_container.removeEventListener(BrowserEvents.COMPOSITION_START_EVENT, @_processCompositionStartEvent, no)
        if BrowserSupport.isWebKit()
            @_container.removeEventListener(BrowserEvents.TEXT_INPUT_EVENT, @_processTextInputEvent, no)
        @_container.removeEventListener(BrowserEvents.COMPOSITION_UPDATE_EVENT, @_processCompositionUpdateEvent, no)
        @_container.removeEventListener(BrowserEvents.COMPOSITION_END_EVENT, @_processCompositionEndEvent, no)
        @_container.removeEventListener(BrowserEvents.COPY_EVENT, @_processCopyEvent, no)
        @_container.removeEventListener(BrowserEvents.CUT_EVENT, @_processCutEvent, no)
        @_container.removeEventListener(BrowserEvents.PASTE_EVENT, @_processPasteEvent, no)
        @_container.removeEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_processMouseDownEvent, no)

        @_container.removeEventListener(BrowserEvents.DRAG_START_EVENT, @_processDragStartEvent, no)
        @_container.removeEventListener(BrowserEvents.DRAG_ENTER_EVENT, @_processDragEnterEvent, no)
        @_container.removeEventListener(BrowserEvents.DRAG_LEAVE_EVENT, @_processDragLeaveEvent, no)
        @_container.removeEventListener(BrowserEvents.DRAG_OVER_EVENT, @_processDragOverEvent, no)
        @_container.removeEventListener(BrowserEvents.DROP_EVENT, @processDropEvent, no)
        @_container.removeEventListener(BrowserEvents.DRAG_END_EVENT, @_processDragEndEvent, no)
        if BrowserSupport.isIe()
            @_container.removeEventListener(BrowserEvents.BEFORE_PASTE_EVENT, @_processPasteEvent, no)

    _processCompositionStartEvent: (event) =>
        event.stopPropagation()
        return event.preventDefault() if not @_editable or BrowserSupport.isIe()
        range = @_getCachedRange()
        return unless range
        if not range.isCollapsed()
            try
                ops = @_deleteSelection(range)
                @_submitOps(ops)
            catch e
                @emit('error', e)
                return
        @pauseSetRange()
        span = document.createElement('span')
        @_renderer.insertNodeAt(span, range.getStartIndex())
        Buffer.attachNextTo(span)
        span.parentNode?.removeChild(span)

    _processCompositionUpdateEvent: (event) =>
        event.stopPropagation()
        return if Buffer.getText() isnt ''
        range = @_getCachedRange(no)
        return unless range
        span = document.createElement('span')
        @_renderer.insertNodeAt(span, range.getStartIndex())
        Buffer.attachNextTo(span)
        span.parentNode?.removeChild(span)

    _processCompositionEndEvent: (event) =>
        event.stopPropagation()
        if BrowserSupport.isMozilla()
            @insertTextData(Buffer.getText(), no)
        if BrowserSupport.isMozilla()
            Buffer.detach()
            @resumeSetRange(yes, yes)

    _processTextInputEvent: (event) =>
        event.preventDefault()
        event.stopPropagation()
        return unless @_editable
        try
            if event.data is '\n'
                @_handleNewLine()
            else
                @insertTextData(event.data)
        catch e
            @emit('error', e)
        Buffer.clear()

    _processKeyEvent: (event) =>
        if DEBUG_KEY_EVENTS
            console.log event?.type, event?.keyCode, event?.charCode, event
        cancel = @_handleKeyEvent(event)
        if cancel
            event.stopPropagation()
            event.preventDefault()

    _detachBuffer: ->
        @_resumeSetRange(no, yes)
        Buffer.detach()

    _processMouseDownEvent: =>
        @_detachBuffer()
        @_clearCachedRange()

    _handleKeyEvent: (event) ->
        eventType = @_getKeyEventType(event)
        if not @_editable
            switch eventType
                when EventType.NAVIGATION, EventType.NOEFFECT
                    return no
                else return yes
        switch eventType
            when EventType.INPUT
                @_detachBuffer()
                try
                    @insertTextData(String.fromCharCode(event.charCode))
                catch e
                    @emit('error', e)
                return yes
            when EventType.LINE
                @_detachBuffer()
                try
                    @_handleNewLine()
                catch e
                    @emit('error', e)
                return yes
            when EventType.TAB
                @_detachBuffer()
                try
                    @_handleTab(event.shiftKey)
                catch e
                    @emit('error', e)
                return yes
            when EventType.DELETE
                @_detachBuffer()
                try
                    @_handleDelete(event)
                catch e
                    @emit('error', e)
                return yes
            when EventType.NAVIGATION
                @_detachBuffer()
                if @_cachedRange
                    @_setCachedRange(yes)
                return no
            when EventType.NOEFFECT
                event.stopPropagation()
                return no
            when EventType.DANGEROUS
                return yes
            else
                return yes

    _getKeyEventType: (event) ->
        computedKeyCode = if event.which != 0 then event.which else event.keyCode
        if !BrowserSupport.isMac() and event.keyCode is KeyCodes.KEY_DELETE and
                event.shiftKey and !event.ctrlKey and !event.altKey
            return EventType.NOEFFECT
        type = null
        # wiab webkit key logic
        if BrowserSupport.isWebKit()
            if not computedKeyCode
                type = EventType.DANGEROUS
            else if event.type is BrowserEvents.KEY_PRESS_EVENT
                if computedKeyCode is KeyCodes.KEY_ESCAPE or ((event.ctrlKey or event.metaKey) and not event.altKey)
                    type = EventType.NOEFFECT
                else if computedKeyCode is KeyCodes.KEY_TAB
                    type = EventType.TAB
                else
                    type = EventType.INPUT
            else if KeyCodes.NAVIGATION_KEYS.indexOf(computedKeyCode) isnt -1
                type = EventType.NAVIGATION
            else if computedKeyCode is KeyCodes.KEY_DELETE or computedKeyCode is KeyCodes.KEY_BACKSPACE
                type = EventType.DELETE
            else if computedKeyCode is KeyCodes.KEY_ESCAPE or event.keyIdentifier is 'U+0010'
                type = EventType.NOEFFECT
            else if computedKeyCode is KeyCodes.KEY_ENTER
                type = EventType.LINE
            else if computedKeyCode is KeyCodes.KEY_TAB
                type = EventType.TAB
            else
                type = EventType.NOEFFECT
        else if BrowserSupport.isMozilla()
            if event.type is BrowserEvents.KEY_DOWN_EVENT
                if (event.keyCode is KeyCodes.KEY_BACKSPACE or event.keyCode is KeyCodes.KEY_DELETE) and event.ctrlKey and not event.altKey
                    return EventType.DELETE
                else if KeyCodes.NAVIGATION_KEYS.indexOf(computedKeyCode) isnt -1
                    return EventType.NAVIGATION
                else
                    return EventType.NOEFFECT
            if not computedKeyCode
                type = EventType.DANGEROUS
            else if event.ctrlKey or event.metaKey or event.altKey
                type = EventType.NOEFFECT
            else if event.charCode
                type = EventType.INPUT
            else if computedKeyCode is KeyCodes.KEY_DELETE or computedKeyCode is KeyCodes.KEY_BACKSPACE
                type = EventType.DELETE
            else if KeyCodes.NAVIGATION_KEYS.indexOf(computedKeyCode) isnt -1
                type = EventType.NAVIGATION
            else if computedKeyCode is KeyCodes.KEY_ENTER
                type = EventType.LINE
            else if computedKeyCode is KeyCodes.KEY_TAB
                type = EventType.TAB
            else
                type = EventType.NOEFFECT
        else if BrowserSupport.isIe()
            if event.type is BrowserEvents.KEY_DOWN_EVENT
                if computedKeyCode is KeyCodes.KEY_BACKSPACE or computedKeyCode is KeyCodes.KEY_DELETE
                    return EventType.DELETE
                if computedKeyCode is KeyCodes.KEY_TAB
                    return EventType.TAB
                if computedKeyCode is KeyCodes.KEY_ENTER
                    return EventType.LINE
                return EventType.NOEFFECT
            else if event.type is BrowserEvents.KEY_PRESS_EVENT
                if computedKeyCode is KeyCodes.KEY_ESCAPE or ((event.ctrlKey or event.metaKey) and not event.altKey)
                    return EventType.NOEFFECT
                return EventType.INPUT
        else
            type = EventType.DANGEROUS
        type

    _getCurrentElement: (node, offset) ->
        # Возвращает элемент, содержащий параметры и смещение этого элемента
        if DomUtils.isTextNode(node)
            prevElement = @_renderer.getPreviousElement(node)
            offset = @_renderer.getElementLength(prevElement) if prevElement isnt node.parentNode
            return [prevElement, offset]
        rightNode = node.childNodes[offset]
        if rightNode
            element = @_renderer.getPreviousElement(rightNode)
            return [@_container.firstChild, 1] if not element
            return [element, 0] if DomUtils.isTextNode(rightNode) and element is rightNode.parentNode
            return [element, @_renderer.getElementLength(element)]
        leftNode = node.childNodes[offset - 1] || node
        if leftNode
            leftNode = @_renderer.getDeepestLastNode(leftNode)
            element = if (@_renderer.getElementType(leftNode))? then leftNode else @_renderer.getPreviousElement(leftNode)
            return [@_container.firstChild, 1] if not element
            return [element, @_renderer.getElementLength(element)]
        console.error node, offset
        throw 'could not determine real node'

    _getOffsetBefore: (node) ->
        # Возращает смещение в снепшоте до текущей ноды
        offset = 0
        while node = @_renderer.getPreviousElement(node)
            offset += @_renderer.getElementLength(node)
        offset

    _getOffsetsBefore: (startElement, endElement) ->
        startOffset = 0
        endOffset = 0
        isCollapsed = startElement is endElement
        countStart = no
        while endElement = @_renderer.getPreviousElement(endElement)
            elementLength = @_renderer.getElementLength(endElement)
            endOffset += elementLength
            if not isCollapsed and not countStart and endElement is startElement
                countStart = yes
                continue
            startOffset += elementLength if countStart
        startOffset = endOffset if isCollapsed
        [startOffset, endOffset]

    _getElementsAndOffsets: (range) ->
        [startElement, startOffset] = @_getCurrentElement(range.startContainer, range.startOffset)
        if range.collapsed
            endElement = startElement
            endOffset = startOffset
        else
            [endElement, endOffset] = @_getCurrentElement(range.endContainer, range.endOffset)
        [startOffsetBefore, endOffsetBefore] = @_getOffsetsBefore(startElement, endElement)
        [startElement, startOffsetBefore + startOffset, startOffset, endElement, endOffsetBefore + endOffset, endOffset]

    _getCachedRange: (clearSelection = yes) ->
        return @_cachedRange if @_setRangePaused
        unless @_cachedRange
            range = SelectionHelper.getRangeInside(@_container)
            if range
                [startElement, startIndex, startOffset, endElement, endIndex, endOffset] = @_getElementsAndOffsets(range)
                @_cachedRange = new CachedRange(@, startElement, startOffset, startIndex, endElement, endOffset, endIndex)
            else
                @_cachedRange = null
        SelectionHelper.clearSelection() if clearSelection and @_cachedRange
        @_cachedRange

    _realSetCachedRange: =>
        @_setRangeTimeoutId = clearTimeout(@_setRangeTimeoutId) if @_setRangeTimeoutId?
        return unless @_cachedRange
        startElement = @_cachedRange.getStartElement()
        endElement = @_cachedRange.getEndElement()
        try
            SelectionHelper.setRangeObject(startElement, @_renderer.getElementType(startElement), @_cachedRange.getStartOffset(),
                endElement, @_renderer.getElementType(endElement), @_cachedRange.getEndOffset())
        catch e
            console.warn 'failed to set range', e, startElement, @_renderer.getElementType(startElement),
                    @_cachedRange.getStartOffset(), endElement, @_renderer.getElementType(endElement),
                    @_cachedRange.getEndOffset()
        @focus()
        delete @_cachedRange

    _setCachedRange: (force = no) ->
        return if @_setRangePaused # do not perform setRange because it's used by smthng
        return @_realSetCachedRange() if force
        clearTimeout(@_setRangeTimeoutId) if @_setRangeTimeoutId?
        @_setRangeTimeoutId = setTimeout(@_realSetCachedRange, SET_RANGE_TIMEOUT)

    _clearCachedRange: ->
        @_setRangeTimeoutId = clearTimeout(@_setRangeTimeoutId) if @_setRangeTimeoutId?
        @_setRangePaused = no
        delete @_cachedRange if @_cachedRange

    _getElementTextParams: (element) ->
        ###
        Возвращает текстовые параметры указанного элемента (для нетекстовых
        элементов возвращает пустые параметры текстового объекта)
        @param element: DomUtils node
        @return: object
        ###
        if @_renderer.getElementType(element) is ModelType.TEXT
            return @_renderer.getElementParams(element)
        params = {}
        params[ParamsField.TYPE] = ModelType.TEXT
        return params

    _processInChildBlip: (action) ->
        ###
        Когда блип можно только комментировать, для большей части ввода создается дочерний
        блип и ввод производится в него.
        ###
        childBlip = @_getNewChildBlip(true)
        childBlipView = childBlip.getView()
        childEditor = childBlipView.getEditor()
        childEditor.focus()
        action(childEditor)

    insertTextData: (data, sync = yes) -> #throws Error
        data = Utf16Util.traverseString(data)
        return unless data.length
        r = @_getCachedRange()
        return unless r
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                editor.insertTextData(data)
        return if @_permission isnt EDIT_PERMISSION
        ops = []
        if not r.isCollapsed() and not Buffer.isAttached()
            ops = @_deleteSelection(r)
        startElement = r.getStartElement()
        startElementType = @_renderer.getElementType(startElement)
        startOffset = r.getStartOffset()
        if data of SPECIAL_INPUT and
                (data isnt '@' or startElementType isnt ModelType.TEXT or startOffset is 0 or
                startElement.textContent.charAt(startOffset - 1).match(/^\W/)) and
                (data isnt '~' or require('../account_setup_wizard/processor').instance.isBusinessUser())
            @_submitOps(ops) if ops.length
            if sync
                @[SPECIAL_INPUT[data]]()
            else
                setTimeout =>
                    @[SPECIAL_INPUT[data]]()
                , 0
            return
        params = @_getElementTextParams(startElement)
        for key, value of @_modifiers
            if value is null
                delete params[key]
            else
                params[key] = value
        if params[TextLevelParams.URL]?
            if not startOffset
                if (prevElement = @_renderer.getPreviousElement(startElement))
                    if @_renderer.getElementParams(prevElement)[TextLevelParams.URL] isnt params[TextLevelParams.URL]
                        delete params[TextLevelParams.URL]
                else
                    delete params[TextLevelParams.URL]
        if params[TextLevelParams.URL]?
            endElementParams = @_renderer.getElementParams(r.getEndElement())
            endElementUrl = endElementParams[TextLevelParams.URL]
            if endElementUrl isnt params[TextLevelParams.URL]
                delete params[TextLevelParams.URL]
            else
                if r.getEndOffset() is @_renderer.getElementLength(r.getEndElement())
                    if (nextElement = @_renderer.getNextElement(r.getEndElement()))
                        nextElementParams = @_renderer.getElementParams(nextElement)
                        if nextElementParams[TextLevelParams.URL] isnt params[TextLevelParams.URL]
                            delete params[TextLevelParams.URL]
                    else
                        delete params[TextLevelParams.URL]
        op = {p: r.getStartIndex(), ti: data, params: params}
        ops.push(op)
        @_submitOps(ops)

    _lineIsEmpty: (line) ->
        ###
        Возвращает true, если переданный параграф является пустым
        @param line: HTMLElement
        @return: boolean
        ###
        next = @_renderer.getNextElement(line)
        return true unless next?
        return @_renderer.getElementType(next) is ModelType.LINE

    _handleNewLine: -> #throws Error
        range = @_getCachedRange()
        return if not range
        if @_permission is COMMENT_PERMISSION
            # Создаем дочерний блип, но не вставляем пустую строку
            return @_processInChildBlip ->
        return if @_permission isnt EDIT_PERMISSION
        prevLine = @_renderer.getParagraphNode(range.getStartElement())
        prevParams = @_renderer.getElementParams(prevLine)
        params = {}
        if prevParams[LineLevelParams.BULLETED]?
            params[LineLevelParams.BULLETED] = prevParams[LineLevelParams.BULLETED]
        else if prevParams[LineLevelParams.NUMBERED]?
            params[LineLevelParams.NUMBERED] = prevParams[LineLevelParams.NUMBERED]
        if @_lineIsEmpty(prevLine) and (prevParams[LineLevelParams.BULLETED]? or prevParams[LineLevelParams.NUMBERED]?)
            # Просто снимем bulleted list
            op = {p: range.getStartIndex() - 1, len: 1, paramsd: params}
        else
            # Создадим новый параграф
            params[ParamsField.TYPE] = ModelType.LINE
            params[ParamsField.RANDOM] = Math.random()
            op = {p: range.getStartIndex(), ti: ' ', params: params}
        @_submitOp(op)

    _handleTab: (shiftKey) ->
        ###
        Обрабатывает нажатие на tab
        ###
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange()
        return if not range
        diff = if shiftKey then -1 else 1
        line = @_renderer.getParagraphNode(range.getStartElement())
        ops = @_getSelectionOps(@_getOffsetBefore(line), line, 0, range.getEndElement(), range.getEndOffset(),
                SelectionAction.UPDATE_SELECTION_INDENT, diff)
        return if not ops
        @_submitOps(ops)

    _getDeleteOp: (element, index, textOffset, length) ->
        ###
        Генерирует операцию удаления
        @param element: HTMLNode - элемент, в котором будет происходить удаление
        @param index: int - индекс, по которому будет происходить удаление
        @param length: int - обязательный параметр для удаления текста, при удалении элементов остальных
                типов не будет использован
        ###
        type = @_renderer.getElementType(element)
        op = {p: index, params: @_renderer.getElementParams(element)}
        switch type
            when ModelType.TEXT
                op.td = element.firstChild.data.substr(textOffset, length)
            else
                op.td = ' '
        op

    _deleteNext: (element, offset, index) ->
        return [] if not index or not element
        if offset is @_renderer.getElementLength(element)
            nextElement = @_renderer.getNextElement(element)
            return [] unless nextElement
            return @_deleteNext(nextElement, 0, index)
        type = @_renderer.getElementType(element)
        switch type
            when ModelType.TEXT
                return [@_getDeleteOp(element, index, offset, 1)]
            when ModelType.LINE
                return @_deleteLine(element, index)
            else
                return [] if @_renderer.getElementType(element) is ModelType.BLIP
                return [@_getDeleteOp(element, index)]

    _deletePrev: (element, offset, index) ->
        type = @_renderer.getElementType(element)
        if type is ModelType.LINE
            lineParams = @_renderer.getElementParams(element)
            if lineParams[LineLevelParams.BULLETED]? or lineParams[LineLevelParams.NUMBERED]?
                params = {}
                if lineParams[LineLevelParams.BULLETED]?
                    params[LineLevelParams.BULLETED] = lineParams[LineLevelParams.BULLETED]
                else
                    params[LineLevelParams.NUMBERED] = lineParams[LineLevelParams.NUMBERED]
                return [{p: index, len: 1, paramsd: params}]
            return @_deleteLine(element, index)
        unless offset
            prevElement = @_renderer.getPreviousElement(element)
            return [] unless prevElement
            return @_deletePrev(prevElement, @_renderer.getElementLength(prevElement), index)
        return [] if not index
        switch type
            when ModelType.TEXT
                return [@_getDeleteOp(element, index, offset - 1, 1)]
            when ModelType.BLIP
                return []
            else
                return [@_getDeleteOp(element, index)]

    _isLineWithoutParams: (line) ->
        return false if not line?
        type = @_renderer.getElementType(line)
        return false if type isnt ModelType.LINE
        params = @_renderer.getElementParams(line)
        return not (params[LineLevelParams.BULLETED]? or params[LineLevelParams.NUMBERED]?)

    _deleteLine: (line, index) ->
        return [] if not index
        res = [@_getDeleteOp(line, index)]
        prevElement = @_renderer.getPreviousElement(line)
        if @_isLineWithoutParams(prevElement)
            curParams = @_renderer.getElementParams(line)
            if curParams[LineLevelParams.BULLETED]? or curParams[LineLevelParams.NUMBERED]?
                params = {}
                if curParams[LineLevelParams.BULLETED]?
                    params[LineLevelParams.BULLETED] = curParams[LineLevelParams.BULLETED]
                else
                    params[LineLevelParams.NUMBERED] = curParams[LineLevelParams.NUMBERED]
                res.push({p: index-1, len: 1, paramsi: params})
        return res

    _getTextMarkupOps: (element, index, length, param, value) ->
        ops = []
        if not TextLevelParams.isValid(param)
            throw new Error "Bad text param is set: #{param}, #{value}"
        type = @_renderer.getElementType(element)
        return ops unless type is ModelType.TEXT
        params = @_renderer.getElementParams(element)
        return ops if params[param] is value
        if params[param]?
            op = {p: index, len: length, paramsd: {}}
            op.paramsd[param] = params[param]
            ops.push(op)
        if value?
            op = {p: index, len: length, paramsi: {}}
            op.paramsi[param] = value
            ops.push(op)
        ops

    _getClearTextMarkupOps: (element, index, length) ->
        ops = []
        type = @_renderer.getElementType(element)
        return ops unless type is ModelType.TEXT
        params = @_renderer.getElementParams(element)
        for param of params
            continue if param is ParamsField.TYPE
            continue if param is TextLevelParams.URL
            op = {p: index, len: length, paramsd: {}}
            op.paramsd[param] = params[param]
            ops.push(op)
        ops

    _getLineMarkupOps: (element, index, param, value) ->
        ops = []
        if not LineLevelParams.isValid(param)
            throw new Error "Bad line param is set: #{param}, #{value}"
        type = @_renderer.getElementType(element)
        return ops unless type is ModelType.LINE
        params = @_renderer.getElementParams(element)
        for p in [LineLevelParams.BULLETED, LineLevelParams.NUMBERED]
            continue unless params[p]?
            prevVal = params[p]
            op = {p: index, len: 1, paramsd: {}}
            op.paramsd[p] = prevVal
            ops.push(op)
        if value?
            op = {p: index, len: 1, paramsi: {}}
            op.paramsi[param] = if prevVal and not value then prevVal else value
            ops.push(op)
        ops

    _getLineIndentUpdateOps: (element, index, indent) ->
        ops = []
        type = @_renderer.getElementType(element)
        return ops unless type is ModelType.LINE
        params = @_renderer.getElementParams(element)
        if (lvl = params[LineLevelParams.BULLETED])?
            param = LineLevelParams.BULLETED
        else if (lvl = params[LineLevelParams.NUMBERED])?
            param = LineLevelParams.NUMBERED
        else return ops
        newValue = Math.max(0, lvl + indent)
        return ops if newValue is lvl
        op = {p: index, len: 1, paramsd: {}}
        op.paramsd[param] = params[param]
        ops.push(op)
        op = {p: index, len: 1, paramsi: {}}
        op.paramsi[param] = newValue
        ops.push(op)
        return ops

    _getCopyElementOp: (element, offset, length) ->
        type = @_renderer.getElementType(element)
        return null unless type
        switch type
            when ModelType.TEXT
                return {ti: element.firstChild.data.substr(offset, length), params: @_renderer.getElementParams(element)}
            when ModelType.BLIP
                childBlip = @_getChildBlip(element['__rizzoma_id'])
                return null unless childBlip
                ops = childBlip.getView().getEditor().getCopyContentOps()
                childModel = childBlip.getModel()
                blipParams =
                    isFoldedByDefault: childModel.isFoldedByDefault()
                    contributors: childModel.getContributors()
                    sourceBlipId: childModel.getServerId()
                params = @_renderer.getElementParams(element)
                params[ParamsField.THREAD_ID] ||= params[ParamsField.ID]
                return {ti: ' ', params: params, ops: ops, blipParams: blipParams}
            when ModelType.LINE, ModelType.ATTACHMENT, ModelType.FILE, ModelType.RECIPIENT
                params = @_renderer.getElementParams(element)
                params[ParamsField.URL] = element.getAttribute('rzUrl') || '' if type is ModelType.FILE
                return {ti: ' ', params: params}
            else
                params = @_renderer.getElementParams(element)
                params[ParamsField.URL] = element.getAttribute('rzUrl') || '' if type is ModelType.FILE
                return {ti: ' ', params: params}

    _processSelection: (startIndex, endIndex, endElement, endOffset, action, param, value) ->
        ###
        Для указанного выделения возвращает результаты, полученные одним из действий:
        SelectionAction.DELETE: удаление, возвращает ShareJS-операции удаления
        SelectionAction.TEXT: изменение параметров текста, возввращает ShareJS-операции
            маркировки текста
        SelectionAction.LINE: изменение парметров абзацев, возвращает ShareJS-операции
            маркировки абзацев
        SelectionAction.GETTEXTPARAMS: текстовые параметры, возвращает массив объектов параметров
            для всех текстовых блоков внутри выделения
        SelectionAction.GETLINEPARAMS: абзацевые параметры. возвращает массив объектов параметров
            для всех абзацев, содержащих выделение
        SelectionAction.GETLINEPARAMS: обновление абзацевых параметров
        SelectionAction.CLEARTEXTPARAMS: удаление параметров текста, возвращает ShareJS-операции
            удаления маркировки текста (кроме ссылок)
        @param startIndex: int - начальное смещение
        @param endIndex: int - конечное смещение (не включая элемент по смещению)
        @param endElement: HTMLElement - элемент, на который попадает конец выделения (включен в выделение)
        @param action: SelectionAction - действие, которое будет совершаться над выделением
        @param param: имя параметра для маркировки (только для действий по маркировке выделения)
        @param value: значение параметра для маркировки (только для действий по маркировке веделения)
        @returns: [object]
        ###
        unless endOffset
            endElement = @_renderer.getPreviousElement(endElement)
            endOffset = @_renderer.getElementLength(endElement)
        res = []
        selectionLength = endIndex - startIndex
        while selectionLength
            params = @_renderer.getElementParams(endElement)
            type = @_renderer.getElementType(endElement)
            endElementLength = @_renderer.getElementLength(endElement)
            endOffset ||= endElementLength
            workingLength = Math.min(Math.min(selectionLength, endElementLength), endOffset)

            index = endIndex - workingLength
            switch action
                when SelectionAction.DELETE
                    ops = [@_getDeleteOp(endElement, index, endOffset - workingLength, workingLength)]
                when SelectionAction.TEXT
                    ops = @_getTextMarkupOps(endElement, index, workingLength, param, value)
                when SelectionAction.LINE
                    ops = @_getLineMarkupOps(endElement, index, param, value)
                when SelectionAction.CLEARTEXTPARAMS
                    ops = @_getClearTextMarkupOps(endElement, index, workingLength)
                when SelectionAction.GETTEXTPARAMS
                    type = @_renderer.getElementType(endElement)
                    if type is ModelType.TEXT
                        ops = [@_renderer.getElementParams(endElement)]
                    else
                        ops = null
                when SelectionAction.GETLINEPARAMS
                    type = @_renderer.getElementType(endElement)
                    if type is ModelType.LINE
                        ops = [@_renderer.getElementParams(endElement)]
                    else
                        ops = null
                when SelectionAction.COPY_CONTENT
                    op = @_getCopyElementOp(endElement, endOffset - workingLength, workingLength)
                    ops = [op] if op
            while ops and ops.length
                if action is SelectionAction.TEXT or action is SelectionAction.COPY_CONTENT
                    res.unshift(ops.pop())
                else
                    res.push(ops.shift())
            endIndex -= workingLength
            selectionLength -= workingLength
            endOffset = null
            endElement = @_renderer.getPreviousElement(endElement)
        res

    _getSelectionOps: (startIndex, startElement, startOffset, endElement, endOffset, action, param, value) ->
        if startOffset is @_renderer.getElementLength(startElement)
            startElement = @_renderer.getNextElement(startElement)
            startOffset = 0
        unless endOffset
            endElement = @_renderer.getPreviousElement(endElement)
            endOffset = @_renderer.getElementLength(endElement)
        res = []
        while startElement
            if startElement is endElement
                needBreak = yes
                workingLength = endOffset - startOffset
            else
                workingLength = @_renderer.getElementLength(startElement) - startOffset
            switch action
                when SelectionAction.TEXT
                    ops = @_getTextMarkupOps(startElement, startIndex, workingLength, param, value)
                when SelectionAction.COPY_CONTENT
                    op = @_getCopyElementOp(startElement, startOffset, workingLength)
                    ops = [op] if op
                when SelectionAction.UPDATE_SELECTION_INDENT
                    ops = @_getLineIndentUpdateOps(startElement, startIndex, param)
                else return res
            startIndex += workingLength
            while ops and ops.length
                res.push(ops.shift())
            startOffset = 0
            startElement = @_renderer.getNextElement(startElement)
            break if needBreak
        res

    _deleteSelection: (range) ->
        ###
        @param range: CachedRange
        ###
        @_processSelection(range.getStartIndex(), range.getEndIndex(), range.getEndElement(), range.getEndOffset(), SelectionAction.DELETE)

    _handleDelete: (event) ->
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange(no)
        return unless range
        if not range.isCollapsed()
            return @_handleRangeDelete()
        isDelete = event.keyCode is KeyCodes.KEY_DELETE
        if event.ctrlKey
            direction = if isDelete then 'right' else 'left'
            sel = window.getSelection()
            sel.modify('extend', direction, 'word')
            @_cachedRange = null
            return @_handleRangeDelete()
        if isDelete
            ops = @_deleteNext(range.getStartElement(), range.getStartOffset(), range.getStartIndex())
        else
            ops = @_deletePrev(range.getStartElement(), range.getStartOffset(), range.getStartIndex() - 1)
        @_submitOps(ops) if ops.length

    _handleRangeDelete: ->
        range = @_getCachedRange(no)
        return if not range or range.isCollapsed()
        ops = @_deleteSelection(range)
        return @_submitOps(ops) if ops.length

    _isValidLineForDrop: (par, top, checkStartLine) ->
        return no if @_permission isnt EDIT_PERMISSION
        return no if DRAG_START_LINE is par and checkStartLine
        return no if DomUtils.contains(DRAG_START_LINE, par)
        if top and (prev = @_renderer.getPreviousElement(par)) and @_renderer.getParagraphNode(prev) is DRAG_START_LINE
            return no
        else if not top
            while (par = @_renderer.getNextElement(par))
                break if @_renderer.getElementType(par) is ModelType.LINE
            return no if par and par is DRAG_START_LINE
        yes

    _removeDragStartLine: =>
        return unless DRAG_START_LINE.parentNode
        startIndex = @_getOffsetBefore(DRAG_START_LINE)
        endElement = DRAG_START_LINE
        endIndex = startIndex + 1
        endOffset = 1
        next = DRAG_START_LINE
        nextLine = null
        while(next = @_renderer.getNextElement(next))
            if @_renderer.getElementType(next) is ModelType.LINE
                nextLine = next
                break
            endOffset = @_renderer.getElementLength(next)
            endIndex += endOffset
            endElement = next
        additionalOps = []

        processParams = (arr, lineParams, action) ->
            for param in [LineLevelParams.BULLETED, LineLevelParams.NUMBERED]
                continue unless lineParams[param]?
                op = {p: 0, len: 1}
                params = {}
                params[param] = lineParams[param]
                op[action] = params
                arr.push(op)

        if startIndex is 0
            startIndex = 1
            lineParams = @_renderer.getElementParams(DRAG_START_LINE)
            processParams(additionalOps, lineParams, 'paramsd')
            if nextLine
                endElement = nextLine
                endIndex += 1
                lineParams = @_renderer.getElementParams(nextLine)
                processParams(additionalOps, lineParams, 'paramsi')
        ops = @_processSelection(startIndex, endIndex, endElement, endOffset,
                SelectionAction.DELETE).concat(additionalOps)
        @_clearCachedRange()
        SelectionHelper.clearSelection()
        @_submitOps(ops) if ops?.length

    _processDragStartEvent: (e) =>
        e.stopPropagation()
        return e.preventDefault() if @_permission isnt EDIT_PERMISSION
        par = @_renderer.getParagraphNode(e.target)
        if not DomUtils.hasClass(e.target, 'js-draggable-marker') or par.parentNode isnt @_container
            clearDragProps()
            return e.preventDefault()
        DRAG_START_LINE = par
        LAST_DRAG_OP = DRAG_TYPE_MARKER
        LAST_DRAG_OVER_CLASS = undefined
        DRAG_CALL_ME_LATER = @_removeDragStartLine
        @emit('copy')
        dragEnd = par
        dragOffset = 1
        dragStartIndex = @_getOffsetBefore(dragEnd)
        while(next = @_renderer.getNextElement(dragEnd))
            break if @_renderer.getElementType(next) is ModelType.LINE
            dragOffset = @_renderer.getElementLength(next)
            dragEnd = next
        dt = e.dataTransfer
        try
            ops = @_getSelectionOps(dragStartIndex, par, 0, dragEnd, dragOffset, SelectionAction.COPY_CONTENT)
            dt.setData('text/rizzoma', JSON.stringify(ops))
        catch err
            console.warn err
            clearDragProps()
            return e.preventDefault()
        dt.effectsAllowed = 'move'
        dt.addElement(@_renderer.getParagraphNode(e.target)) if dt.addElement

    _processDragEndEvent: (e) ->
        e.stopPropagation()
        clearDragProps()

    _findDropTarget: (target, y) ->
        if target is @_container
            els = @_container.children
            for child, i in els
                r = child.getBoundingClientRect()
                return updateDragView(child) if not i and y < r.top
                return updateDragView(child) if y < r.bottom
            return updateDragView(els[els.length - 1]) if els.length
        par = @_renderer.getParagraphNode(target)
        if par.parentNode is @_container
            updateDragView(par)
        else
            clearDragView()

    _processDragEnterEvent: (e) =>
        return if LAST_DRAG_OP isnt DRAG_TYPE_MARKER
        return if e.defaultPrevented
        e.preventDefault()
        DRAG_COUNT++
        @_findDropTarget(e.target, e.clientY)

    _processDragLeaveEvent: (e) =>
        return if LAST_DRAG_OP isnt DRAG_TYPE_MARKER
        return if e.defaultPrevented1
        e.defaultPrevented1 = yes
        DRAG_COUNT--
        if not DRAG_COUNT
            clearDragView()

    _processDragOverEvent: (e) =>
        e.stopPropagation()
        e.preventDefault()
        if LAST_DRAG_OP is DRAG_TYPE_MARKER
            @_findDropTarget(e.target, e.clientY)
            dt = e.dataTransfer
            return dt.dropEffect = 'none' if not LAST_DRAG_OVER
            top = isDragToTop(e.clientY)
            cl = "drag-over-#{if top then 'top' else 'bottom'}"
            if @_isValidLineForDrop(LAST_DRAG_OVER, top, no)
                dt.dropEffect = 'move'
            else
                dt.dropEffect = 'none'
                return clearDragView()
            if cl isnt LAST_DRAG_OVER_CLASS
                DomUtils.removeClass(LAST_DRAG_OVER, LAST_DRAG_OVER_CLASS)
                DomUtils.addClass(LAST_DRAG_OVER, LAST_DRAG_OVER_CLASS = cl)
            return
        try r = SelectionHelper.getRangeFromPoint(e.clientX, e.clientY, @_container)
        return e.dataTransfer.dropEffect = 'none' unless r
        @_clearCachedRange()
        SelectionHelper.setRange(r)
        r = @_getCachedRange()
        e.dataTransfer.dropEffect = if r then 'copy' else 'none'

    processDropEvent: (event, r) =>
        #TODO: Think about r arg
        return if event.defaultPrevented
        event.preventDefault()
        event.defaultPrevented = yes unless event.defaultPrevented
        if LAST_DRAG_OP is DRAG_TYPE_MARKER and (data = JSON.parse(event.dataTransfer.getData('text/rizzoma')))
            return unless LAST_DRAG_OVER
            top = isDragToTop(event.clientY)
            return unless @_isValidLineForDrop(LAST_DRAG_OVER, top, yes)
            index = @_getOffsetBefore(LAST_DRAG_OVER)
            unless top
                index += 1
                next = LAST_DRAG_OVER
                while(next = @_renderer.getNextElement(next))
                    break if @_renderer.getElementType(next) is ModelType.LINE
                    index += @_renderer.getElementLength(next)
            try
                @_insertOps(index, data)
                DRAG_CALL_ME_LATER()
                clearDragProps()
            catch e
                @emit('error', e)
            return
        unless r
            try r = SelectionHelper.getRangeFromPoint(event.clientX, event.clientY, @_container)
            @_clearCachedRange()
            SelectionHelper.setRange(r)
        r = @_getCachedRange()
        return unless r
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                editor.setCursorToStart()
                editor.processDropEvent(event, r)
        return if @_permission isnt EDIT_PERMISSION
        @_pauseSetRange()
        getUploadForm()?.openImmediateUpload @, event.dataTransfer.files, =>
            @_resumeSetRange(yes, yes)

    _processPasteEvent: (event) =>
        event.stopPropagation()
        return event.preventDefault() unless @_editable
        try
            cancel = @handlePasteEvent(event)
        catch e
            cancel = yes
            console.warn(e)
        if cancel
            event.preventDefault()

    _processCutEvent: (event) =>
        event.stopPropagation()
        try
            cancel = @_handleCut(event)
        catch e
            cancel = yes
            console.warn e
        if cancel
            event.preventDefault()

    _processCopyEvent: (event) =>
        event.stopPropagation()
        try
            cancel = @_handleCopy(event)
        catch e
            cancel = yes
            console.warn('copy processing failed', e)
        if cancel
            event.preventDefault()

    _renderOpsForCopy: (copyOps, textData) ->
        container = document.createElement('span')
        if container.dataset
            container.dataset[DATA_VARS.CLIPBOARD] = 'true'
        else
            container.setAttribute(DATA_ATTRS.CLIPBOARD, 'true')
        @_renderer.renderOps(copyOps, container, textData)
        container

    _handleClipboardCopy: (range, clipboardData) ->
        ops =  @_getSelectionOps(range.getStartIndex(), range.getStartElement(), range.getStartOffset(),
                range.getEndElement(), range.getEndOffset(), SelectionAction.COPY_CONTENT)
        textData = []
        container = @_renderOpsForCopy(ops, textData)
        clipboardData.setData('text/rizzoma', JSON.stringify(ops))
        clipboardData.setData('text/html', container.outerHTML)
        clipboardData.setData('text/plain', textData.join(''))

    _handleHtmlCopy: (range, removeSelection) ->
        copyOps = @_getSelectionOps(range.getStartIndex(), range.getStartElement(), range.getStartOffset(),
                range.getEndElement(), range.getEndOffset(), SelectionAction.COPY_CONTENT)
        if removeSelection
            ops = @_deleteSelection(range)
            @_submitOps(ops) if ops.length
        @pauseSetRange()
        container = @_renderOpsForCopy(copyOps, null)
        Buffer.setFragmentContent(container)
        Buffer.selectAll()
        Buffer.onTextChange(@_finishHtmlDataCopy)

    _finishHtmlDataCopy: =>
        @resumeSetRange(yes, yes)

    _handleCopy: (event) ->
        range = @_getCachedRange(no)
        return no if not range or range.isCollapsed()
        @emit('copy')
        if event.clipboardData
            @_handleClipboardCopy(range, event.clipboardData)
            return yes
        @_handleHtmlCopy(range, no)
        no

    _handleCut: (event) ->
        range = @_getCachedRange()
        return yes if not range or range.isCollapsed()
        @emit('copy')
        if event.clipboardData
            @_handleClipboardCopy(range, event.clipboardData)
            if @_permission is EDIT_PERMISSION and @_editable and not range.isCollapsed()
                ops = @_deleteSelection(range)
                @_submitOps(ops) if ops.length
            return yes
        @_handleHtmlCopy(range, @_permission is EDIT_PERMISSION and @_editable)
        no

    _getBlockParamsChangeOps: (p, len, fromParams, toParams) ->
        ###
        Возвращает операции, необходимые для замены одних параметров другими
        @param pos: int
        @param len: int
        @param fromParams: {key: value}, исходные параметры
        @param toParams: {key: value}, конечные параметры
        ###
        res = []
        for name, value of toParams
            continue if not LineLevelParams.isValid(name)
            continue if name is 'RANDOM'
            continue if value is fromParams[name]
            if fromParams[name]?
                paramsd = {}
                paramsd[name] = fromParams[name]
                res.push {p, len, paramsd}
            if toParams[name]?
                paramsi = {}
                paramsi[name] = value
                res.push {p, len, paramsi}
        for name, value of fromParams
            continue if not LineLevelParams.isValid(name)
            continue if name of toParams
            paramsd = {}
            paramsd[name] = value
            res.push {p, len, paramsd}
        return res

    _getModifiedInsertionOps: (index, insOps) ->
        ###
        Изменяет индекс у всех операций вставки так, чтобы вставка началась с указанного индекса.
        Не генерирует операций для вложенных блипов, помещая их во временные контейнеры.
        @param index: int
        @param insOps: [{p, ti, params}]
        @return: [ops, {index: container}]
        ###
        ops = []
        blipsToInsert = {}
        lastThread = null
        lastBlipThreadId = null
        if index is 0
            curFirstParagraphParams = @_getSnapshot()[0][ModelField.PARAMS]
            firstPara = insOps.shift()
            if firstPara[ModelField.PARAMS][ParamsField.TYPE] isnt ModelType.LINE
                throw new Error("Cannot insert non-paragraph in pos 0")
            index = 1
            ops = @_getBlockParamsChangeOps(0, 1, curFirstParagraphParams, firstPara[ModelField.PARAMS])
            insOps.push(firstPara)
        for op in insOps
            params = op[ModelField.PARAMS]
            type = params[ParamsField.TYPE]
            if type isnt ModelType.BLIP
                lastThread = null
                op.p = index
                ops.push(op)
                op[ModelField.PARAMS][ParamsField.RANDOM] = Math.random() if type isnt ModelType.TEXT
                index += op.ti.length
                continue
            if not lastThread or lastBlipThreadId isnt params[ParamsField.THREAD_ID]
                lastBlipThreadId = params[ParamsField.THREAD_ID]
                lastThread = new BlipThread(Math.random())
                blipsToInsert[index] ?= []
                blipsToInsert[index].push(lastThread.getContainer())
            childBlip = @_getNewChildBlip(false, op.blipParams, lastThread)
            childBlipView = childBlip.getView()
            lastThread.appendBlipElement(childBlipView.getContainer())
            childBlipView.getEditor().setInitialOps(op.ops)
        if firstPara?
            # Добавим операций вставки параграфа
            ops = ops.concat(@_getBlockParamsChangeOps(index-1, 1, firstPara[ModelField.PARAMS], curFirstParagraphParams))
        return [ops, blipsToInsert]

    _insertOps: (index, insOps) ->
        [ops, blipsToInsert] = @_getModifiedInsertionOps(index, insOps)
        @_submitOps(ops) if ops.length
        range = @_getCachedRange(no)
        blipWasInserted = no
        for index, blipNodes of blipsToInsert
            blipWasInserted = yes
            @_renderer.insertTemporaryBlipNodes(blipNodes, index, range)
        if blipWasInserted and range
            @_cachedRange = range
            @_setCachedRange(yes)

    _handleOpsPaste: (ops, range) ->
        if not range.isCollapsed()
            selOps = @_deleteSelection(range)
            @_submitOps(selOps) if selOps.length
        range = @_getCachedRange()
        @_insertOps(range.getStartIndex(), ops)

    _handleClipboardPaste: (range, clipboardData) ->
        skipped = no
        if (data = clipboardData.getData('text/rizzoma'))
            ops = JSON.parse(data)
            @_handleOpsPaste(ops, range)
        else if (data = clipboardData.getData('text/html'))
            tmpEl = document.createElement('span')
            tmpEl.innerHTML = data
            fragment = document.createDocumentFragment()
            while tmpEl.firstChild
                fragment.appendChild(tmpEl.firstChild)
            @_handleHtmlPaste(fragment, range)
        else if BrowserSupport.isMozilla() # we still can get formating from buffer
            skipped = yes
        else if (data = clipboardData.getData('text/plain'))
            ops = []
            if not range.isCollapsed()
                ops = @_deleteSelection(range)
            parser = new TextParser(OpParsedElementProcessor, range.getStartIndex())
            parser.parseText(ops, data)
            @_submitOps(ops) if ops.length
        else if (///Files///.test(clipboardData.types)) and (item = clipboardData.items?[0])
            @_pauseSetRange()
            getUploadForm()?.openImmediateUpload @, [item.getAsFile()], =>
                @_resumeSetRange(yes, yes)
        else
            skipped = yes
        skipped

    _handleHtmlPaste: (fragment, range) ->
        return if not range
        offset = range.getStartIndex()
        frags = fragment.querySelectorAll("[#{DATA_ATTRS.CLIPBOARD}=\"true\"]")
        if frags.length is 1
            htmlParser = new HtmlOpParser(offset)
            ops = htmlParser.parse(frags[0], offset)
            if ops.length
                @_handleOpsPaste(ops, range)
                return
        ops = []
        if not range.isCollapsed()
            ops = @_deleteSelection(range)
        htmlParser = new HtmlParser(OpParsedElementProcessor, offset)
        parsedOps = htmlParser.parse(fragment)
        while parsedOps.length
            ops.push(parsedOps.shift())
        @_submitOps(ops)

    _finishHtmlPaste: (err, fragment) =>
        @resumeSetRange(yes, yes)
        @_handleHtmlPaste(fragment, @_getCachedRange()) if fragment

    handlePasteEvent: (event) ->
        return yes if BrowserSupport.isIe() and event.type is BrowserEvents.PASTE_EVENT
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                editor.handlePasteEvent(event)
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange()
        return yes if not range
        if event.clipboardData && event.clipboardData.getData
            skipped = @_handleClipboardPaste(range, event.clipboardData)
            return yes unless skipped
        @pauseSetRange()
        Buffer.setFragmentContent(null)
        Buffer.selectAll()
        Buffer.onTextChange(@_finishHtmlPaste)
        no

    __scrollIntoCursor: =>
        # TODO: think about it + global scroll
        @_scrollTimer = null
        range = DomUtils.getRange()
        return if not range or not range.collapsed
        container = range.startContainer
        return if not (scrollable = @_getScrollableElement()) or not DomUtils.contains(scrollable, container)
        container = container.parentNode if DomUtils.isTextNode(container)
        waveViewTop = scrollable.getBoundingClientRect().top
        elementTop = container.getBoundingClientRect().top
        return DomUtils.scrollTargetIntoViewWithAnimation(container, scrollable, yes, SCROLL_INTO_VIEW_OFFSET) if waveViewTop > elementTop
        waveViewBottom = waveViewTop + scrollable.offsetHeight
        elementBottom = elementTop + container.offsetHeight
        return container.scrollIntoView(no) if waveViewBottom < elementBottom

    __scrollCursorIntoView: ->
        return if DomUtils.isFrameElement(document.activeElement)
        if @_scrollTimer?
            clearTimeout(@_scrollTimer)
        @_scrollTimer = setTimeout(@__scrollIntoCursor, SCROLL_INTO_VIEW_TIMER)

    _performPostSubmitActions: (ops, shiftCursor) ->
        @_flushOpsQueue()
        if shiftCursor
            @__scrollCursorIntoView()
            @_setCachedRange(yes)
        if @_cursor
            setTimeout =>
                @_processCursor() # TODO: may be merge it with cursor scrolling
            , 0
        @emit('ops', ops)

    _submitOp: (op, shiftCursor = yes) ->
        @_renderer.applyOp(op, @_cachedRange, shiftCursor)
        @_performPostSubmitActions([op], shiftCursor)

    _submitOps: (ops, shiftCursor = yes) ->
        @_renderer.applyOps(ops, @_cachedRange, shiftCursor)
        @_performPostSubmitActions(ops, shiftCursor)

    getRange: ->
        if @_cachedRange
            startElement = @_cachedRange.getStartElement()
            endElement = @_cachedRange.getEndElement()
            SelectionHelper.getRangeObject(startElement, @_renderer.getElementType(startElement),
                    @_cachedRange.getStartOffset(), endElement, @_renderer.getElementType(endElement),
                    @_cachedRange.getEndOffset())
        else
            SelectionHelper.getRangeInside(@_container)

    insertBlip: (serverBlipId, container, threadId, shiftLeft) ->
        ###
        Отправляет операцию вставки указанного блипа в этот
        Возвращает true, если операция была сделана
        @param id: string
        @param container: HTMLNode
        @param threadId: string
        @param shiftLeft: boolean
        @return: boolean
        ###
        return false if not @containsNode(container)
        LocalStorage.incRepliesCount()
        cnt = LocalStorage.getRepliesCount()
        if cnt == 10 or cnt == 20
            mixpanel.track(cnt+" replies done", {"count":cnt})
        offset = @_getOffsetBefore(container)
        params = {}
        params[ParamsField.TYPE] = ModelType.BLIP
        params[ParamsField.ID] = serverBlipId
        params[ParamsField.RANDOM] = Math.random()
        params[ParamsField.THREAD_ID] = threadId
        op = {p: offset, ti: ' ', params: params}
        op.shiftLeft = yes if shiftLeft
        try
            @_renderer.setParamsToInlineElement(container, params)
            @emit('ops', [op])
        catch e
            @emit('error', e)
            return false
        return true

    removeBlip: (id) ->
        try
            element = null
            while element = @_renderer.getNextElement(element)
                continue unless @_renderer.getElementType(element) is ModelType.BLIP
                params = @_renderer.getElementParams(element)
                continue unless params[ParamsField.ID] is id
                offset = @_getOffsetBefore(element)
                op = {p: offset, td: ' ', params: params}
                @_clearCachedRange()
                SelectionHelper.clearSelection()
                @_submitOp(op, no)
                break
        catch e
            @emit('error', e)

    insertAttachment: (url) ->
        range = @_getCachedRange()
        return if not range
        params = {}
        params[ParamsField.TYPE] = ModelType.ATTACHMENT
        params[ParamsField.URL] = url
        params[ParamsField.RANDOM] = Math.random()
        op = {p: range.getEndIndex(), ti: ' ', params: params}
        try
            @_submitOp(op)
        catch e
            @emit('error', e)

    insertFile: (id) ->
        range = @_getCachedRange()
        return if not range
        params = {}
        params[ParamsField.ID] = id
        params[ParamsField.TYPE] = ModelType.FILE
        params[ParamsField.RANDOM] = Math.random()
        op = {p: range.getEndIndex(), ti: ' ', params: params}
        try
            @_submitOp(op)
        catch e
            @emit('error', e)

    _insertAndFocusInlineInput: (inline) ->
        range = @_getCachedRange()
        container = inline.getContainer()
        @_renderer.preventEventsPropagation(container)
        @_renderer.insertNodeAt(container, range.getEndIndex())
        @_clearCachedRange()
        inline.focus()
        return inline

    _destroyInlineInput: (inlineInput) ->
        offset = @_getOffsetBefore(inlineInput.getContainer())
        inlineInput.destroy()
        @setCursorToStart()
        @_getCachedRange()
        return offset

    _bindForEscape: (container, callback) ->
        $(container).bind "blur #{BrowserEvents.KEY_EVENTS.join(' ')}", (event) =>
            return if event.keyCode? and event.keyCode isnt KeyCodes.KEY_ESCAPE
            callback()

    _cancelInlineInput: (input, text) ->
        if not @_renderer
            # Если блип уже удален, то ничего не делаем
            return input.destroy()
        container = input.getContainer()
        prevElement = @_renderer.getPreviousElement(container)
        params = @_getElementTextParams(prevElement)
        offset = @_getOffsetBefore(container)
        input.destroy()
        return @focus() if not text
        op = {p: offset, ti: text, params}
        @setCursorToStart()
        @_getCachedRange()
        @_submitOp(op)

    insertTag: ->
        ###
        Вставляет поле ввода для тега
        ###
        return unless @_getCachedRange()
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                editor.insertTag()
        return if @_permission isnt EDIT_PERMISSION
        try
            tagInput = @_insertAndFocusInlineInput(new TagInput())
            inputContainer = tagInput.getContainer()
            $(inputContainer).bind 'tagInserted', (event, tagText) =>
                @_insertTag(tagInput, tagText)
            @_bindForEscape inputContainer, =>
                @_cancelInlineInput(tagInput, '#' + tagInput.getValue())
            return tagInput
        catch e
            @emit('error', e)

    _insertTag: (tagInput, tagText) ->
        offset = @_destroyInlineInput(tagInput)
        params = {}
        params[ParamsField.TYPE] = ModelType.TAG
        params[ParamsField.TAG] = tagText
        params[ParamsField.RANDOM] = Math.random()
        op = {p: offset, ti: ' ', params: params}
        @_submitOp(op)

    insertRecipient: ->
        ###
        Вставляет поле ввода для получателя сообщения
        Создает обработчики потери фокуса и нажатия клавиш.
        При выборе участника удаляет поле ввода и генерирует операцию для вставки получателя
        ###
        return unless @_getCachedRange()
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                editor.insertRecipient()
        return if @_permission isnt EDIT_PERMISSION
        try
            recipientInput = @_insertAndFocusInlineInput(@_getRecipientInput())
            recipientContainer = recipientInput.getContainer()
            $(recipientContainer).bind 'itemSelected', (event, userId) =>
                return unless userId?
                offset = @_destroyInlineInput(recipientInput)
                @_insertRecipientByUserId(offset, userId)
            $(recipientContainer).bind 'emailSelected', (event, email) =>
                @_insertRecipientByEmail(recipientInput, email)
            $(recipientContainer).bind 'cancel', (event, text) =>
                text = '@' + text if text?
                @_cancelInlineInput(recipientInput, text)
            return recipientInput
        catch e
            @emit('error', e)

    insertTaskRecipient: ->
        ###
        Вставляет поле ввода для получателя задачи.
        Создает обработчики потери фокуса и нажатия клавиш.
        При заполнении полей удаляет поле ввода и генерирует операцию для вставки получателя.
        ###
        return unless @_getCachedRange()
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                return if editor.getPermission() isnt EDIT_PERMISSION
                editor.insertTaskRecipient()
        return if @_permission isnt EDIT_PERMISSION
        try
            taskRecipientInput = @_insertAndFocusInlineInput(@_getTaskRecipientInput())
            taskRecipientInput.on 'finish', (taskParams) =>
                offset = @_getOffsetBefore(taskRecipientInput.getContainer())
                if taskParams.recipientId?
                    @_destroyInlineInput(taskRecipientInput)
                    return @_insertTaskRecipient(offset, taskParams)
                taskParams.position = offset
                taskRecipientStub = taskRecipientInput.stub()
                taskRecipientInput.destroy()
                @focus()
                @_addTaskRecipient taskParams, ->
                    taskRecipientStub.destroy()
            taskRecipientInput.on 'cancel', (text) =>
                text = '~' + text if text?
                @_cancelInlineInput(taskRecipientInput, text)
            return taskRecipientInput
        catch e
            @emit('error', e)

    _insertTaskRecipient: (offset, params) ->
        params[ParamsField.TYPE] = ModelType.TASK_RECIPIENT
        params[ParamsField.RANDOM] = Math.random()
        op = {p: offset, ti: ' ', params: params}
        @_submitOp(op)

    _insertTaskRecipientByUserId: (offset, recipientId) ->
        params =
            recipientId: recipientId
            status: NOT_PERFORMED_TASK
            senderId: window.userInfo.id
        @_insertTaskRecipient(offset, params)

    _updateTaskRecipient: (taskRecipient, data) ->
        container = taskRecipient.getContainer()
        offset = @_getOffsetBefore(container)
        return null if not offset?
        params = @_renderer.getElementParams(container)
        if data.recipientId
            return @_updateTaskRecipientParams(params, offset, data)
        else
            return @_replaceTaskRecipient(taskRecipient, params, offset, data)

    _updateTaskRecipientParams: (params, offset, data) ->
        ops = []
        for paramName, paramValue of data
            continue if params[paramName] is paramValue
            if params[paramName]?
                delProp = {}
                delProp[paramName] = params[paramName]
                op = {p: offset, paramsd: delProp, len: 1}
                ops.push(op)
            if paramValue?
                insProp = {}
                insProp[paramName] = paramValue
                op = {p: offset, paramsi: insProp, len: 1}
                ops.push(op)
        try
            @_submitOps(ops) if ops.length
            return $(@_renderer.getElement(offset)).data('object')
        catch e
            @emit('error', e)

    _replaceTaskRecipient: (taskRecipient, params, offset, data) ->
        @_removeInline(taskRecipient)
        for paramName, paramValue of data
            params[paramName] = paramValue
        stub = new TaskRecipientStub(params.recipientEmail, params.deadlineDate, params.deadlineDatetime)
        params.position = offset
        @_renderer.insertNodeAt(stub.getContainer(), offset)
        @_addTaskRecipient params, ->
            stub.destroy()
        return null

    _insertRecipientByUserId: (offset, userId) ->
        params = {}
        params[ParamsField.TYPE] = ModelType.RECIPIENT
        params[ParamsField.ID] = userId
        params[ParamsField.RANDOM] = Math.random()
        op = {p: offset, ti: ' ', params: params}
        @_submitOp(op)

    _insertRecipientByEmail: (recipientInput, email) ->
        return unless email?
        offset = @_getOffsetBefore(recipientInput.getContainer())
        recipientStub = recipientInput.stub(email)
        recipientInput.destroy()
        @focus()
        @_addRecipientByEmail offset, email, ->
            recipientStub.destroy()

    _convertTaskToRecipient: (task) ->
        offset = @_getOffsetBefore(task.getContainer())
        recipientId = task.getData().recipientId
        @_removeInline(task)
        @_insertRecipientByUserId(offset, recipientId)

    _convertRecipientToTask: (recipient) =>
        offset = @_getOffsetBefore(recipient.getContainer())
        recipientData = @_renderer.getElementParams(recipient.getContainer())
        recipientId = recipientData[ParamsField.ID]
        @_removeInline(recipient)
        @_insertTaskRecipientByUserId(offset, recipientId)
        return $(@_renderer.getElement(offset)).data('object')

    _removeInline: (inline) =>
        ###
        Удаляет inline из редактора
        @param inline: object
        ###
        node = inline.getContainer()
        params = @_renderer.getElementParams(node)
        offset = @_getOffsetBefore(node)
        op = {p: offset, td: ' ', params}
        try
            @_submitOp(op)
        catch e
            @emit('error', e)

    hasRecipientsOrTasks: ->
        ###
        Проверяет наличия хотя бы одного получателя сообщения или задачи в редакторе
        @returns: boolean - true, если в редакторе присутствует хотя бы один получатель, иначе false
        ###
        @_renderer.getRecipientNodes().length > 0 ||
            @_renderer.getTaskRecipientNodes().length > 0

    getRecipients: ->
        ###
        Возвращает массив, содержащий объекты получателей данного сообщения
        @returns: [Recipient]
        ###
        recipientNodes = @_renderer.getRecipientNodes()
        recipients = []
        for recipientNode in recipientNodes
            recipients.push($(recipientNode).data('recipient'))
        recipients

    getTaskRecipients: ->
        ($(t).data('object') for t in @_renderer.getTaskRecipientNodes())

    openUploadForm: (insertImage) ->
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange()
        return if not range
        form = getUploadForm()
        handleFormClose = =>
            @_resumeSetRange(yes, yes)
        @_pauseSetRange()
        form.open(@, insertImage, handleFormClose)

    openLinkEditor: ->
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange()
        return if not range
        return @_openLinkEditor() if not range.isCollapsed()
        element = startElement = endElement = range.getStartElement()
        startIndex = range.getStartIndex()
        leftOffset = rightOffset = range.getStartOffset()
        textBlocks = []
        while element
            elementParams = @_renderer.getElementParams(element)
            break if elementParams[ParamsField.TYPE] isnt ModelType.TEXT or elementParams[TextLevelParams.URL]
            elementText = element.textContent
            if leftOffset and (leftSpace = elementText.lastIndexOf(' ', leftOffset - 1)) isnt -1
                text = elementText.substring(leftSpace + 1, leftOffset)
                textBlocks.unshift(text) if text
                startIndex -= leftOffset - 1 - leftSpace
                startOffset = leftSpace + 1
                startElement = element
                break
            text = elementText.substring(0, leftOffset)
            textBlocks.unshift(text) if text
            startIndex -= leftOffset
            startElement = element
            startOffset = 0
            element = @_renderer.getPreviousElement(element)
            leftOffset = @_renderer.getElementLength(element)

        element = endElement
        endOffset = rightOffset
        while element
            elementParams = @_renderer.getElementParams(element)
            break if elementParams[ParamsField.TYPE] isnt ModelType.TEXT or elementParams[TextLevelParams.URL]
            elementText = element.textContent
            elementLength = @_renderer.getElementLength(element)
            if rightOffset < elementLength and (rightSpace = elementText.indexOf(' ', rightOffset)) isnt -1
                text = elementText.substring(rightOffset, rightSpace)
                textBlocks.push(text) if text
                endElement = element
                endOffset = rightSpace
                break
            text = elementText.substring(rightOffset)
            textBlocks.push(text) if text
            endOffset = elementLength
            endElement = element
            rightOffset = 0
            element = @_renderer.getNextElement(element)

        text = textBlocks.join('')
        urls = matchUrls(textBlocks.join(''))
        return @_openLinkEditor() unless (url = urls[0])
        if url.endIndex isnt text.length
            index = startIndex + url.endIndex
            [endElement, endOffset] = @_renderer.getElementAndOffset(index)
            endOffset = index - endOffset + @_renderer.getElementLength(endElement)
        if url.startIndex
            startIndex += url.startIndex
            [startElement, startOffset] = @_renderer.getElementAndOffset(startIndex)
            startOffset = startIndex - startOffset + @_renderer.getElementLength(startElement)
        url = text.substring(urls[0].startIndex, urls[0].endIndex)
        ops = @_getSelectionOps(startIndex, startElement, startOffset, endElement, endOffset,
                SelectionAction.TEXT, TextLevelParams.URL, url)
        try
            @_submitOps(ops) if ops.length
        catch e
            @emit('error', e)

    getElementAndOffset: (index) ->
        @_renderer.getElementAndOffset(index)

    getContainer: ->
        @_container

    applyOps: (ops, shiftCursor, user) ->
        try
            @_cachedRange = @_getCachedRange() if not @_cachedRange
            @_cachedRange.setAsNotChanged() if @_cachedRange
            if not @_cachedRange and DomUtils.contains(@_container, document.activeElement)
                focused = document.activeElement
                sel = window.getSelection()
                if sel and sel.rangeCount
                    raw = sel.getRangeAt(0)
                    startContainer = raw.startContainer
                    startOffset = raw.startOffset
            @_renderer.applyOps(ops, @_cachedRange, shiftCursor, user)
            if focused and startContainer and DomUtils.contains(document.body, startContainer)
                scrollable = @_getScrollableElement?()
                if scrollable and focused isnt document.activeElement
                    st = scrollable.scrollTop
                    focused.focus()
                    scrollable.scrollTop = st
                    SelectionHelper.setCaret(startContainer, startOffset)
            if @_cachedRange #and @_cachedRange.isChanged()
                @_setCachedRange(yes)
            if @_cursor
                setTimeout =>
                    @_processCursor()
                , 0
            @_flushOpsQueue()
        catch e
            @emit('error', e)

    setEditable: (editable) ->
        return if not BrowserSupport.isSupported()
        return if editable is @_editable
        needFocusMagic = BrowserSupport.isMozilla() and @_container is document.activeElement
        if needFocusMagic
            r = @_getCachedRange()
            scrollable = @_getScrollableElement?()
            st = scrollable.scrollTop if scrollable
            Buffer.focus()
        @_editable = editable
        @_container.contentEditable = @_editable.toString()
        for gadget in @_gadgets
            gadget.setMode(editable)
        return unless needFocusMagic
        @focus()
        scrollable.scrollTop = st if scrollable
        if r
            startEl = r.getStartElement()
            startType = @_renderer.getElementType(startEl)
            startOffset = r.getStartOffset()
            if r.isCollapsed()
                endEl = startEl
                endType = startType
                endOffset = startOffset
            else
                endEl = r.getEndElement()
                endType = @_renderer.getElementType(endEl)
                endOffset = r.getEndOffset()
            SelectionHelper.setRangeObject(startEl, startType, startOffset, endEl, endType, endOffset)

    containsNode: (node) ->
        ###
        Возвращает true, если указанный элемент находиться в этом редакторе
        @param node: HTMLElement
        @return: boolean
        ###
        DomUtils.contains(@_container, node)

    setEditingModifiers: (@_modifiers) ->
        ###
        Устанавливает модификаторы стиля текста, которые будут применены к
        вводимому тексту
        @param _modifiers: object
        ###

    setRangeTextParam: (name, value) ->
        ###
        Устанавливает указанный текстовый параметр на текущем выбранном
        диапазоне в указанное значение.
        Если value=null, удаляет указанный параметр.
        @param name: string
        @param value: any
        ###
        range = @_getCachedRange()
        return if not range or range.isCollapsed()
        try
            ops = @_processSelection(range.getStartIndex(), range.getEndIndex(), range.getEndElement(),
                range.getEndOffset(), SelectionAction.TEXT, name, value)
            @_submitOps(ops) if ops?.length
            @_setCachedRange(yes)
        catch e
            @emit('error', e)

    _filterSameParams: (blocks) ->
        ###
        Возвращает объект, содержащий все пары ключ-значение, совпадающие
        у всех объектов переданного массива.
        @param blocks: [object]
        @return: object
        ###
        return {} if not blocks.length
        params = blocks.pop()
        for blockParams in blocks
            for own key, value of params
                delete params[key] if value isnt blockParams[key]
        params

    _hasTextParams: (block, neededParams) ->
        ###
        Возвращает true, если для указанного блока есть текстовый параметр
        @param block: object
        @param neededParams: {paramName: anything}
        @return: boolean
        ###
        for param of block
            continue if param is ParamsField.TYPE
            continue if param not of neededParams
            return true
        return false

    hasTextParams: (neededParams) ->
        ###
        Возврващает true, если в выделенном тексте установлен хотя бы один из
        переданных параметров.
        @param neededParams: {paramName: anything}
        @return: boolean
        ###
        range = @_getCachedRange(no)
        return false if not range
        try
            if range.isCollapsed()
                params = @_getElementTextParams(range.getEndElement())
                return @_hasTextParams(params, neededParams)
            else
                blocks = @_processSelection(range.getStartIndex(), range.getEndIndex(), range.getEndElement(),
                    range.getEndOffset(), SelectionAction.GETTEXTPARAMS)
                for params in blocks
                    if @_hasTextParams(params, neededParams)
                        return true
            return false
        catch e
            @emit('error', e)
        finally
            delete @_cachedRange ##TODO: its hack


    getTextParams: ->
        ###
        Возвращает общие для выделенного текста параметры.
        @return: object
        ###
        range = @_getCachedRange(no)
        return {} if not range
        try
            if range.isCollapsed()
                params = @_getElementTextParams(range.getEndElement())
            else
                blocks = @_processSelection(range.getStartIndex(), range.getEndIndex(), range.getEndElement(),
                    range.getEndOffset(), SelectionAction.GETTEXTPARAMS)
                params = @_filterSameParams(blocks)
            delete params[ParamsField.TYPE]
            return params
        catch e
            @emit('error', e)
        finally
            delete @_cachedRange ##TODO: its hack

    setRangeLineParam: (name, value) ->
        ###
        Устанавливает указанный параметр параграфа для всех параграфов, которые
        содержат текущий выбранный диапазон.
        Если value=null, удаляет указанный параметр.
        @param name: string
        @param value: any
        ###
        range = @_getCachedRange()
        return if not range
        try
            startElement = @_renderer.getParagraphNode(range.getStartElement())
            ops = @_processSelection(@_getOffsetBefore(startElement), range.getEndIndex(), range.getEndElement(),
                    range.getEndOffset(), SelectionAction.LINE, name, value)
            @_submitOps(ops) if ops?.length
            @_setCachedRange(yes)
        catch e
            @emit('error', e)

    getLineParams: ->
        ###
        Возвращает параметры
        ###
        range = @_getCachedRange(no)
        return {} if not range
        try
            startElement = @_renderer.getParagraphNode(range.getStartElement())
            blocks = @_processSelection(@_getOffsetBefore(startElement), range.getEndIndex(), range.getEndElement(),
                    range.getEndOffset(), SelectionAction.GETLINEPARAMS)
            params = @_filterSameParams(blocks)
            delete params[ParamsField.TYPE]
            return params
        catch e
            @emit('error', e)
        finally
            delete @_cachedRange ##TODO: its hack

    clearSelectedTextFormatting: ->
        ###
        Очищает текстовое форматирование выбранного участка
        ###
        range = @_getCachedRange()
        return if not range or range.isCollapsed()
        try
            ops = @_processSelection(range.getStartIndex(), range.getEndIndex(), range.getEndElement(),
                    range.getEndOffset(), SelectionAction.CLEARTEXTPARAMS)
            @_submitOps(ops) if ops?.length
            @_setCachedRange(yes)
        catch e
            @emit('error', e)

    selectAll: ->
        ###
        Выделяет все содержимое редактора
        range.selectNodeContents(@_container)
        ###
        @_clearCachedRange()
        range = document.createRange()
        range.selectNodeContents(@_container)
        DomUtils.setRange(range)
        return range

    setCursorToStart: ->
        ###
        Устанавливает курсор в начало редактора
        ###
        @_clearCachedRange()
        range = document.createRange()
        range.setStart(@_container, 0)
        range.setEnd(@_container, 0)
        DomUtils.setRange(range)

    _processLinkPopup: =>
        @_linkPopupTimer = null
        hasRange = @_cachedRange?
        range = @_getCachedRange(no)
        linkPopup = LinkPopup.get()
        return linkPopup.hide() if not range
        startElement = range.getStartElement()
        offset = range.getStartIndex()
        @_clearCachedRange() unless hasRange
        url = @_renderer.getElementParams(startElement)?[TextLevelParams.URL]
        return linkPopup.hide() unless url?
        offset -= @_getOffsetBefore(startElement)
        if offset is 0
            prevElement = @_renderer.getPreviousElement(startElement)
            if not prevElement or url isnt @_renderer.getElementParams(prevElement)[TextLevelParams.URL]
                return linkPopup.hide()
        if offset is @_renderer.getElementLength(startElement)
            nextElement = @_renderer.getNextElement(startElement)
            if not nextElement or url isnt @_renderer.getElementParams(nextElement)[TextLevelParams.URL]
                return linkPopup.hide()
        if linkPopup.getContainer().parentNode isnt @_container.parentNode
            DomUtils.insertNextTo(linkPopup.getContainer(), @_container)
        type = @_renderer.getElementType(startElement)
        offset = range.getStartOffset()
        offset -= 1 if offset is @_renderer.getElementLength(startElement)
        r = SelectionHelper.getRangeObject(startElement, type, offset, startElement, type, offset + 1)
        rect = r.getBoundingClientRect()
        rect = {top: rect.top, left: rect.left, right: rect.right, bottom: rect.bottom}
        DomUtils.convertWindowCoordsToRelative(rect, @_container.parentNode)
        linkPopup.show(url, rect, @_openLinkEditor,  @_alwaysShowPopupAtBottom)

    _processCursor: ->
        if @_linkPopupTimer?
            clearTimeout(@_linkPopupTimer)
        @_linkPopupTimer = setTimeout(@_processLinkPopup, LINK_POPUP_TIMEOUT)

    setCursor: ->
        @_cursor = true
        @_processCursor()

    updateCursor: ->
        @_processCursor()

    clearCursor: ->
        @_cursor = false
        @_clearCachedRange()
        LinkPopup.get().hide()

    _paragraphIsShifted: (paragraph) ->
        params = @_renderer.getElementParams(paragraph)
        params[LineLevelParams.BULLETED]? or params[LineLevelParams.NUMBERED]?

    elementIsInShiftedParagraph: (element) ->
        parNode = @_renderer.getParagraphNode(element)
        @_paragraphIsShifted(parNode)

    destroy: ->
        @__unregisterDomEventHandling()
        for gadget in @_gadgets
            gadget.destroy()
            gadget.removeAllListeners()
        delete @_gadgets
        @_renderer.destroy()
        delete @_renderer
        delete @__renderer
        @_clearCachedRange()
        delete @_getSnapshot
        delete @_getRecipientInput
        delete @_getRecipient
        delete @_addRecipientByEmail
        delete @_getTaskRecipientInput
        delete @_getTaskRecipient
        delete @_addTaskRecipient
        delete @_getChildBlip
        delete @_getNewChildBlip
        delete @_getScrollableElement
        delete @_container
        @removeAllListeners()

    insertNodeAtCurrentPosition: (node) ->
        range = @_getCachedRange(no)
        return @_renderer.insertNodeAt(node, range.getEndIndex()) if range
        range = DomUtils.getRange()
        [el, offset] = @_getCurrentElement(range.endContainer, range.endOffset)
        @_renderer.insertNodeAt(node, @_getOffsetBefore(el) + offset)

    pauseSetRange: (updateExisting = no) ->
        @_pauseSetRange(updateExisting)

    _pauseSetRange: (updateExisting = no) ->
        ###
        This method is only used by the classes that are close to editor (eg. Upload form, Link editor)
        ###
        delete @_cachedRange if updateExisting and @_cachedRange
        @_getCachedRange()
        @_setRangePaused = yes

    resumeSetRange: (needToSetRange, force = no) ->
        @_resumeSetRange(needToSetRange, force)

    _resumeSetRange: (needToSetRange, force = no) ->
        ###
        This method is only used by the classes that are close to editor (eg. Upload form, Link editor)
        ###
        @_setRangePaused = no
        if needToSetRange
            @_setCachedRange(force)
        else
            @_clearCachedRange()

    focus: ->
        @_container.focus()

    getCopyContentOps: ->
        startElement = @_renderer.getNextElement()
        endElement = @_renderer.getPreviousElement()
        @_getSelectionOps(0, startElement, 0, endElement, @_renderer.getElementLength(endElement), SelectionAction.COPY_CONTENT)

    setInitialOps: (ops) ->
        firstOp = ops.shift()
        params = firstOp[ModelField.PARAMS]
        if (level = params[LineLevelParams.BULLETED])?
            p = LineLevelParams.BULLETED
        else if (level = params[LineLevelParams.NUMBERED])?
            p = LineLevelParams.NUMBERED
        if level?
            paramsi = {}
            paramsi[p] = level
            op = {p: 0, len: 1, paramsi: paramsi}
            @_submitOp(op)
        @_insertOps(1, ops)
        
    copyElementToBuffer: (element) ->
        op = @_getCopyElementOp(element)
        LocalStorage.setBuffer(JSON.stringify(op)) if op

    getCopyElementOp: (element) -> @_getCopyElementOp(element)
        
    pasteBlipFromBufferToCursor: ->
        range = @_getCachedRange()
        return unless range
        buffer = LocalStorage.getBuffer()
        return unless buffer
        op = JSON.parse(buffer)
        @_insertOps(range.getStartIndex(), [op])
        LocalStorage.removeBuffer()
        
    pasteBlipFromBufferAfter: (blipContainer) ->
        buffer = LocalStorage.getBuffer()
        return unless buffer
        op = JSON.parse(buffer)
        @pasteBlipOpAfter(blipContainer, op)
        LocalStorage.removeBuffer()

    pasteBlipOpAfter: (blipContainer, op) ->
        thread = BlipThread.getBlipThread(blipContainer)
        return if not thread?
        childBlip = @_getNewChildBlip(no, op.blipParams, thread)
        childBlipView = childBlip.getView()
        thread.insertBlipNodeAfter(childBlipView.getContainer(), blipContainer)
        childBlipView.getEditor().setInitialOps(op.ops)

    pasteBlipOpBefore: (blipContainer, op) ->
        thread = BlipThread.getBlipThread(blipContainer)
        return if not thread?
        childBlip = @_getNewChildBlip(no, op.blipParams, thread)
        childBlipView = childBlip.getView()
        thread.insertBlipNodeBefore(childBlipView.getContainer(), blipContainer)
        childBlipView.getEditor().setInitialOps(op.ops)

    pasteOpsAtPosition: (position, insOps) ->
        @_insertOps(position, insOps)

    setPermission: (permission) ->
        @_permission = permission

    getPermission: -> @_permission

    getCurrentIndex: ->
        range = @_getCachedRange()
        return null unless range
        range.getStartIndex()

    insertGadget: (url) ->
        if @_permission is COMMENT_PERMISSION
            return @_processInChildBlip (editor) ->
                editor.insertGadget(url)
        range = @_getCachedRange()
        return if not range
        params = {}
        params[ParamsField.TYPE] = ModelType.GADGET
        params[ParamsField.URL] = url
        params[ParamsField.RANDOM] = Math.random()
        op = {p: range.getEndIndex(), ti: ' ', params: params}
        try
            @_submitOp(op)
        catch e
            @emit('error', e)

    _getTextAndUrl: (startElement, startOffset, endElement, endOffset) ->
        text = ''
        url = undefined
        hasNonTextElement = no
        while startElement
            params = @_renderer.getElementParams(startElement)
            if params[ParamsField.TYPE] is ModelType.TEXT
                url ?= params[TextLevelParams.URL]
                if startElement is endElement
                    text += startElement.textContent.substring(startOffset, endOffset)
                    break
                text += startElement.textContent.substring(startOffset)
            else
                break if startElement is endElement and startOffset is endOffset
                hasNonTextElement = yes
            startOffset = 0
            break if startElement is endElement
            startElement = @_renderer.getNextElement(startElement)
        [text, url, !hasNonTextElement]

    _expandLink: (range) ->
        element = range.getStartElement()
        url = @_renderer.getElementParams(element)[TextLevelParams.URL]
        if url
            startElement = element
            while element = @_renderer.getPreviousElement(element)
                params = @_renderer.getElementParams(element)
                break if params[TextLevelParams.URL] isnt url
                startElement = element
        element = range.getEndElement()
        url = @_renderer.getElementParams(element)[TextLevelParams.URL]
        if url
            endElement = element
            while element = @_renderer.getNextElement(element)
                params = @_renderer.getElementParams(element)
                break if params[TextLevelParams.URL] isnt url
                endElement = element
        rawRange = @getRange()
        rangeChanged = no
        if startElement
            startOffset = 0
            rawRange.setStartBefore(startElement)
            rangeChanged = yes
        else
            startElement = range.getStartElement()
            startOffset = range.getStartOffset()
        if endElement
            endOffset = @_renderer.getElementLength(endElement)
            rawRange.setEndAfter(endElement)
            rangeChanged = yes
        else
            endElement = range.getEndElement()
            endOffset = range.getEndOffset()
        @_updateRange(rawRange) if rangeChanged
        [startElement, startOffset, endElement, endOffset]

    _openLinkEditor: =>
        range = @_getCachedRange()
        return unless range
        [startElement, startOffset, endElement, endOffset] = @_expandLink(range)
        [text, url, editable] = @_getTextAndUrl(startElement, startOffset, endElement, endOffset)
        @pauseSetRange()
        @_linkEditorAttached = yes
        linkEditor = LinkEditor.get()
        linkEditor.on('close', @_handleLinkEditorClose)
        linkEditor.open(text, url, editable, @_updateLink, @_insertLink)

    _handleLinkEditorClose: =>
        @_linkEditorAttached = no
        LinkEditor.get().removeListener('close', @_handleLinkEditorClose)
        @resumeSetRange(yes, yes)

    _updateLink: (url) =>
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange()
        return if not range or range.isCollapsed()
        try
            ops = @_processSelection(range.getStartIndex(), range.getEndIndex(), range.getEndElement(),
                    range.getEndOffset(), SelectionAction.TEXT, TextLevelParams.URL, url)
            @_submitOps(ops) if ops?.length
        catch e
            @emit('error', e)

    _insertLink: (text, url) =>
        return if @_permission isnt EDIT_PERMISSION
        range = @_getCachedRange()
        return unless range
        text = Utf16Util.traverseString(text)
        return if not text
        ops = []
        params = {}
        params[ParamsField.TYPE] = ModelType.TEXT
        params[TextLevelParams.URL] = url
        if range.isCollapsed()
            ops = []
        else
            try
                ops = @_deleteSelection(range)
            catch e
                return @emit('error', e)
        ops.push({p: range.getStartIndex(), ti: text, params: params})
        try
            @_submitOps(ops)
        catch e
            @emit('error', e)

    _updateRange: (range, directionForward) ->
        delete @_cachedRange if @_cachedRange
        SelectionHelper.setRange(range, directionForward)

    setCursorAtParagraph: (index) ->
        [element] = @_renderer.getElementAndOffset(index)
        sel = getSelection()
        sel.removeAllRanges()
        range = document.createRange()
        range.setStartBefore(element)
        range.setEndBefore(element)
        sel.addRange(range)
        @_cachedRange = null

MicroEvent.mixin Editor
exports.Editor = Editor
