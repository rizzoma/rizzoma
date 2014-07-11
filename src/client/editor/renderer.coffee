BrowserEvents = require('../utils/browser_events')
DomUtils = require('../utils/dom')
{ModelField, ParamsField, ModelType, TextLevelParams, LineLevelParams} = require('./model')
{Attachment} = require('./attachment')
{File} = require('./file')
{Tag} = require('./tag')
{escapeHTML} = require('../utils/string')
{DATA_VARS, DATA_ATTRS} = require('./parser')
BlipThread = require('../blip/blip_thread').BlipThread
MicroEvent = require('../utils/microevent')

BULLETED_LIST_LEVEL_COUNT = 3 # Количество уровней bulleted list
BULLETED_LIST_LEVEL_PADDING = 15 # Дополнительные отступы для уровней bulleted list
BULLETED_LIST_START_PADDING = 22 # Начальный отступ для list

DATA_KEY = '__rizzoma_data_key'
CURSOR_STYLE =
    position: 'absolute'
    width: '2px'
NAME_STYLE =
    position: 'absolute'
    top: '-9px'
    fontSize: '10px'
    lineHeight: 'normal'
    left: '-2px'
    color: 'white'
    padding: '1px 2px'
    whiteSpace: 'nowrap'
    maxWidth: '200px'
    textOverflow: 'ellipsis'
    overflow: 'hidden'
    backgroundColor: 'inherit'
USER_COLORS = [
    '#6AA84F',
    '#FF00FF',
    '#0000FF',
    '#C00',
    '#5B0F00',
    '#783F04',
    '#0C343D',
    '#4C1130',
    '#741B47',
    '#20124D',
    '#674EA7',
    '#90F',
    '#85200C',
    '#666',
    '#783F04',
    '#7F6000',
    '#274E13'
]

removeArrayElement = (array, elem) ->
    index = array.indexOf(elem)
    return if index is -1
    array[index..index] = []

globalCursors = {}

class Renderer
    constructor: (args...) ->
        @_init(args...)

    _init: (@_id, @_config, @_addInlineBlip, @_removeInlineBlip, @_getRecipient, @_getTaskRecipient, @_getNewInlineElement) ->
        # recipient nodes cache
        @_recipients = []
        @_taskRecipients = []

    _paramsEqual: (p1, p2) ->
        for i of p1
            return no unless p1[i] is p2[i]
        for i of p2
            return no unless p1[i] is p2[i]
        yes

    _data: (element, key, value) ->
        element[DATA_KEY] ?= {}
        if not key?
            return element[DATA_KEY]
        if typeof key is 'object'
            return element[DATA_KEY] = key
        if not value?
            return element[DATA_KEY][key]
        return element[DATA_KEY][key] = value

    renderContent: (@_container, content) ->
        ###
        Отрисовка содержимого редактора по снимку его содержимого
        @param _container: HTMLElement - элемент редактора, в который будет вставляться содержимое
        @param content: [Object] - снимок содержимого
        ###
        $container = $(@_container)
        $container.empty()
        $curPar = null
        lastEl = null
        lastThread = null
        for element in content
            params = element[ModelField.PARAMS]
            node = @_renderElement(element[ModelField.TEXT], params)
            switch params[ParamsField.TYPE]
                when ModelType.LINE
                    $curPar = $(node)
                    $container.append(node)
                    lastThread = null
                when ModelType.BLIP
                    if (threadId = params[ParamsField.THREAD_ID]) and lastThread and threadId is lastThread.getId()
                        lastThread.appendBlipElement(node)
                    else
                        threadId = params[ParamsField.THREAD_ID] || params[ParamsField.ID]
                        lastThread = new BlipThread(threadId, node)
                        $last = $curPar.children().last()
                        $last = $last.prev() if $last[0].tagName.toLowerCase() isnt 'br'
                        $last.before(lastThread.getContainer())
                else
                    $last = $curPar.children().last()
                    $last = $last.prev() if $last[0].tagName.toLowerCase() isnt 'br'
                    $last.before(node)
                    lastThread = null
            lastEl = element
        @_updateLightBox()
        @_updateLines()

    preventEventsPropagation: (node) ->
        $(node).bind "#{BrowserEvents.KEY_EVENTS.join(' ')} #{BrowserEvents.CLIPBOARD_EVENTS.join(' ')} #{BrowserEvents.INPUT_EVENTS.join(' ')}", (e) ->
            e.stopPropagation()

    insertInlineElementAfter: (element, elementAfter) ->
        ###
        Вставит инлайновый элемент в offsetElement
        @param element: HTMLElement - элемент для вставки
        @param elementAfter: элемент, после которого следует вставить элемент
        ###
        type = @getElementType(elementAfter)
        switch type
            when ModelType.LINE
                elementAfter.insertBefore(element, elementAfter.firstChild)
            when ModelType.BLIP
                @_insertInlineElementAfterBlipThread(element, elementAfter)
            else
                DomUtils.insertNextTo(element, elementAfter)

    createTextElement: ->
        @_createTextElement('', {})

    setParamsToElement: (element, params) ->
        @_setParamsToElement(element, params)

    removeParamsFromElement: (element) ->
        @_setParamsToElement(element, {})

    getCursorFromElement: (element, offset) -> @_getCursorCoordFromElement(element, offset)

    _renderElement: (text, params) ->
        switch params[ParamsField.TYPE]
            when ModelType.TEXT
                return @_createTextElement(text, params)
            when ModelType.LINE
                return @_createLineElement(params)
            else
                return @_createInlineElement(params)

    _setParamsToElement: (node, params) ->
        data = @_data(node)
        data[ModelField.PARAMS] = params
        @_data(node, data)

    _createTextElement: (text, params) ->
        ###
        Создает тексторый элемент и назначает ему параметры
        @param text: string - текст элемента
        @param params: Object - параметры объекта
        @returns: HTMLNode
        ###
        if params[TextLevelParams.URL]
            res = document.createElement('a')
            res.href = params[TextLevelParams.URL]
        else
            res = document.createElement('span')
        $res = $(res)
        $res.css('font-weight', 'bold') if params[TextLevelParams.BOLD]
        $res.css('font-style', 'italic') if params[TextLevelParams.ITALIC]
        decs = []
        decs.push('underline') if params[TextLevelParams.UNDERLINED] or params[TextLevelParams.URL]
        decs.push('line-through') if params[TextLevelParams.STRUCKTHROUGH]
        $res.css('text-decoration', decs.join(' ')) if decs.length
        $res.css('background-color', params[TextLevelParams.BG_COLOR]) if params[TextLevelParams.BG_COLOR]
        textNode = document.createTextNode(text)
        res.appendChild(textNode)
        @_setParamsToElement(res, params)
        res

    _createLineElement: (params) ->
        ###
        Создает элемент типа Line и назначает ему параметры
        @param params: Object - параметры элемента
        @returns: HTMLNode
        ###
        bulleted = params[LineLevelParams.BULLETED]
        val = if bulleted? then bulleted else params[LineLevelParams.NUMBERED]
        if val?
            res = document.createElement('li')
            res.style.marginLeft = "#{BULLETED_LIST_START_PADDING + val * BULLETED_LIST_LEVEL_PADDING}px"
            if bulleted?
                bulletedType = bulleted % BULLETED_LIST_LEVEL_COUNT
                res.className = "bulleted bulleted-type#{bulletedType}"
            else
                res.className = 'numbered'
        else
            res = document.createElement('div')
        res.appendChild(document.createElement('br'))
        if val?
            res.appendChild(marker = document.createElement('span'))
            marker.className = 'js-draggable-marker marker'
            marker.draggable = yes
            marker.contentEditable = 'false'
        @_setParamsToElement(res, params)
        res

    _createInlineElement: (params) ->
        ###
        Создает инлайн элемент и назначает ему параметры
        @param params: Object - параметры элемента
        @returns: HTMLNode
        ###
        switch params[ParamsField.TYPE]
            when ModelType.BLIP
                res = @_addInlineBlip(params[ParamsField.ID])
            when ModelType.ATTACHMENT
                url = params[ParamsField.URL]
                attachment = new Attachment(@_id, url)
                res = attachment.getContainer()
                @preventEventsPropagation(res)
            when ModelType.RECIPIENT
                recipient = @_getRecipient(params[ParamsField.ID])
                res = recipient.getContainer()
                $(res).data('recipient', recipient)
                @_recipients.push(res)
                @preventEventsPropagation(res)
            when ModelType.TASK_RECIPIENT
                recipient = @_getTaskRecipient(params)
                res = recipient.getContainer()
                $(res).data('object', recipient)
                @_taskRecipients.push(res)
                @preventEventsPropagation(res)
            when ModelType.FILE
                file = new File(@_id, params[ParamsField.ID], @_updateLightBox)
                res = file.getContainer()
                @preventEventsPropagation(res)
            when ModelType.TAG
                tag = new Tag(params[ParamsField.TAG])
                res = tag.getContainer()
                @preventEventsPropagation(res)
            when ModelType.GADGET
                res = @_getNewInlineElement(params).getContainer()
            else
                res = document.createElement('span')
                res.contentEditable = 'false'
        @_setParamsToElement(res, params)
        DomUtils.addClass(res, 'default-text')
        res

    _updateLightBox: =>
        if @_updateLightBoxTimer?
            clearTimeout(@_updateLightBoxTimer)
            @_updateLightBoxTimer = null
        @_updateLightBoxTimer = setTimeout =>
            $(@_container).find('a[rel="' + escapeHTML(@_id) + '"]').lightBox(@_config?.lightbox or {})
        , 500

    _insertInlineElementAfterBlip: (element, blipAfter) ->
        thread = BlipThread.getBlipThread(blipAfter)
        thread.splitAfterBlipNode(blipAfter)
        DomUtils.insertNextTo(element, thread.getContainer())
        element

    _insertInlineElementAfterBlipThread: (element, blipAfter) ->
        thread = BlipThread.getBlipThread(blipAfter)
        DomUtils.insertNextTo(element, thread.getContainer())
        element

    _insertInlineElementsAfterBlip: (elements, blipAfter) ->
        thread = BlipThread.getBlipThread(blipAfter)
        thread.splitAfterBlipNode(blipAfter)
        DomUtils.moveNodesNextTo(elements, thread.getContainer())

    _getElementAndOffset: (index, node = @_container) ->
        curNode = node = @getNextElement(node)
        offset = @getElementLength(curNode)
        while curNode
            if offset >= index
                return [node, offset]
            curNode = @getNextElement(curNode)
            if curNode
                offset += @getElementLength(curNode)
                node = curNode
        [node, offset]

    getElementAndOffset: (index) -> @_getElementAndOffset(index)

    getElement: (index) ->
        @getNextElement(@_getElementAndOffset(index)[0])

    getParagraphNode: (node) ->
        while node isnt @_container and @getElementType(node) isnt ModelType.LINE
            node = node.parentNode
        node

    _splitTextElement: (element, index, cachedRange) ->
        ###
        Разбиваем текстовый элемент на два элемента по указанному индексу, если индекс указывает не на края элемента
        @param element: HTMLElement - разбиваемый элемент
        @param index: int - индекс, по которому произойдет разбиение
        @param cachedRange: CachedRange: текущее выделение
        @returns: [HTMLElement, HTMLElement]
        ###
        elLength = element.firstChild.length
        return [element, null] if elLength is index
        return [null, element] if index is 0
        newElement = @_createTextElement(element.firstChild.data.substr(index), @getElementParams(element))
        cachedRange.processSplitText(element, newElement, index) if cachedRange
        DomUtils.insertNextTo(newElement, element)
        element.firstChild.deleteData(index, elLength - index)
        [element, newElement]

    _insertText: (text, params, element, index, offset, cachedRange, shiftCursor, user) ->
        elementParams = @getElementParams(element)
        textLength = text.length
        if @_paramsEqual(params, elementParams)
            textNode = element.firstChild
            textNode.insertData(offset, text)
            @_drawCursorSafely(element, text.length + offset, user)
            if shiftCursor and cachedRange
                cachedRange.setCursor(element, offset + textLength, index + textLength)
            else if cachedRange
                cachedRange.processInsertText(element, offset, textLength, index)
        else
            newElement = @_createTextElement(text, params)
            [leftElement, rightElement] = @_splitTextElement(element, offset, cachedRange)
            if leftElement
                DomUtils.insertNextTo(newElement, leftElement)
            else
                rightElement.parentNode.insertBefore(newElement, rightElement)
            @_drawCursorSafely(newElement, text.length, user)
            if shiftCursor and cachedRange
                cachedRange.setCursor(newElement, textLength, index + textLength)
            else if cachedRange
                cachedRange.processInsertElement(index, textLength)

    _handleTiOp: (op, cachedRange, shiftCursor, user) ->
        index = op.p
        throw new Error('trying to insert text at 0') if not index
        text = op.ti
        params = op.params
        if cachedRange and index is cachedRange.getStartIndex()
            element = cachedRange.getStartElement()
            unless cachedRange.getStartOffset()
                element = @getPreviousElement(element)
                cachedRange.setStart(element, @getElementLength(element), index)
            realOffset = cachedRange.getStartOffset()
        else
            [element, offset] = @_getElementAndOffset(index)
            offsetBefore = offset - @getElementLength(element)
            realOffset = index - offsetBefore
        type = @getElementType(element)
        switch type
            when ModelType.TEXT
                @_insertText(text, params, element, index, realOffset, cachedRange, shiftCursor, user)
            else
                nextElement = @getNextElement(element)
                nextElementType = @getElementType(nextElement)
                if nextElementType is ModelType.TEXT
                    @_insertText(text, params, nextElement, index, 0, cachedRange, shiftCursor, user)
                else
                    newElement = @_createTextElement(text, params)
                    if type is ModelType.LINE
                        element.insertBefore(newElement, element.firstChild)
                    else if type is ModelType.BLIP
                        @_insertInlineElementAfterBlip(newElement, element)
                    else
                        DomUtils.insertNextTo(newElement, element)
                    @_drawCursorSafely(newElement, text.length, user)
                    if shiftCursor and cachedRange
                        cachedRange.setCursor(newElement, text.length, index + text.length)
                    else if cachedRange
                        cachedRange.processInsertElement(index, text.length)

    _handleLineInsertOp: (params, element, index, offset, cachedRange, shiftCursor, user) ->
        newElement = @_createLineElement(params)
        throw new Error('trying to insert line at 0') if not index
        type = @getElementType(element)
        parNode = @getParagraphNode(element)
        DomUtils.insertNextTo(newElement, parNode)
        switch type
            when ModelType.TEXT
                [element, startNode] = @_splitTextElement(element, offset, cachedRange)
                startNode = element.nextSibling unless startNode
            when ModelType.BLIP
                thread = BlipThread.getBlipThread(element)
                [threadNode, startNode] = thread.splitAfterBlipNode(element)
                startNode = threadNode.nextSibling unless startNode
            when ModelType.LINE
                startNode = element.firstChild
            else
                startNode = element.nextSibling
        nodes = DomUtils.getNodeAndNextSiblings(startNode)
        poped = nodes.pop()
        nodes.pop() if poped and poped.tagName?.toLowerCase() isnt 'br'
        DomUtils.moveNodesToStart(newElement, nodes)
        newElementLength = @getElementLength(newElement)
        @_drawCursorSafely(newElement, newElementLength, user)
        @_linesUpdated = yes
        if shiftCursor and cachedRange
            cachedRange.setCursor(newElement, newElementLength, index + newElementLength)
        else if cachedRange
            cachedRange.processInsertElement(index, newElementLength)

    _handleLineDeleteOp: (element, index, cachedRange) ->
        nextElement = @getNextElement(element)
        nodes = DomUtils.getNodeAndNextSiblings(nextElement.firstChild)
        poped = nodes.pop()
        nodes.pop() if poped and poped.tagName?.toLowerCase() isnt 'br'
        parNode = @getParagraphNode(element)
        last = parNode.lastChild
        last = last.previousSibling if last.tagName?.toLowerCase() isnt 'br'
        DomUtils.moveNodesBefore(nodes, last)
        if cachedRange
            cachedRange.processDeleteElement(index, nextElement, @getElementLength(nextElement), element, @getElementLength(element))
        $(nextElement).remove()
        @_linesUpdated = yes
        return if @getElementType(element) isnt ModelType.BLIP
        thread = BlipThread.getBlipThread(element)
        thread.mergeWithNext()

    _handleInlineInsertOp: (params, element, index, offset, cachedRange, shiftCursor, user) ->
        type = @getElementType(element)
        newElement = @_createInlineElement(params)
        if params[ParamsField.TYPE] is ModelType.BLIP and 
                (nextElement = @getNextElement(element)) and @getElementType(nextElement) is ModelType.BLIP and 
                (nextThread = BlipThread.getBlipThread(nextElement)).getId() is params[ParamsField.THREAD_ID]
            nextThread.insertBlipNodeBefore(newElement, nextElement)                
        else if params[ParamsField.TYPE] is ModelType.BLIP and @getElementType(element) is ModelType.BLIP and 
                (thread = BlipThread.getBlipThread(element)).getId() is params[ParamsField.THREAD_ID]
            thread.insertBlipNodeAfter(newElement, element)
        else
            parNode = @getParagraphNode(element)
            elementLength = @getElementLength(newElement)
            if params[ParamsField.TYPE] is ModelType.BLIP
                threadId = params[ParamsField.THREAD_ID] || params[ParamsField.ID]
                newThread = new BlipThread(threadId, newElement)
                insertElement = newThread.getContainer()
                draw = no
            else
                insertElement = newElement
                draw = yes
            switch type
                when ModelType.TEXT
                    [element, startNode] = @_splitTextElement(element, offset, cachedRange)
                    if element
                        insert = DomUtils.insertNextTo
                    else
                        element = startNode
                        insert = parNode.insertBefore
                    until element.parentNode is parNode
                        element = element.parentNode
                    insert(insertElement, element)
                when ModelType.BLIP
                    @_insertInlineElementAfterBlip(insertElement, element)
                when ModelType.LINE
                    parNode.insertBefore(insertElement, parNode.firstChild)
                else
                    DomUtils.insertNextTo(insertElement, element)
            @_drawCursorSafely(newElement, elementLength, user) if draw
        if(params[ParamsField.TYPE] is ModelType.ATTACHMENT)
            @_updateLightBox()
        if shiftCursor and cachedRange
            cachedRange.setCursor(newElement, elementLength, index + elementLength)
        else if cachedRange
            cachedRange.processInsertElement(index, elementLength)

    _handleInlineDeleteOp: (element, index, cachedRange) ->
        nextElement = @getNextElement(element)
        type = @getElementType(nextElement)
        switch type
            when ModelType.BLIP
                params = @getElementParams(nextElement)
                #thread = BlipThread.getBlipThread(nextElement)
                #thread.deleteBlipNode(nextElement)
                @_removeInlineBlip(params[ParamsField.ID])
            when ModelType.RECIPIENT
                $(nextElement).data('recipient')?.destroy()
                removeArrayElement(@_recipients, nextElement)
            when ModelType.TASK_RECIPIENT
                $(nextElement).data('object')?.destroy()
                removeArrayElement(@_taskRecipients, nextElement)
            when ModelType.GADGET
                try
                    @emit('gadgetDelete', nextElement)
                catch e
                    console.warn('Error while deleting inline element', e)
        if cachedRange
            cachedRange.processDeleteElement(index, nextElement, @getElementLength(nextElement), element, @getElementLength(element))
        $(nextElement).remove()
        if @getElementType(element) is ModelType.BLIP
            thread = BlipThread.getBlipThread(element)
            thread.mergeWithNext()
        if(type is ModelType.ATTACHMENT)
            @_updateLightBox()

    _handleOiOp: (op, cachedRange, shiftCursor, user) ->
        index = op.p
        params = op.params
        if cachedRange and index is cachedRange.getStartIndex()
            element = cachedRange.getStartElement()
            unless cachedRange.getStartOffset()
                element = @getPreviousElement(element)
                cachedRange.setStart(element, @getElementLength(element), index)
            realOffset = cachedRange.getStartOffset()
        else
            [element, offset] = @_getElementAndOffset(index)
            offsetBefore = offset - @getElementLength(element)
            realOffset = index - offsetBefore
        switch params[ParamsField.TYPE]
            when ModelType.LINE
                @_handleLineInsertOp(params, element, index, realOffset, cachedRange, shiftCursor, user)
            else
                @_handleInlineInsertOp(params, element, index, realOffset, cachedRange, shiftCursor, user)

    _handleTdOp: (op, cachedRange, shiftCursor, user) ->
        index = op.p
        textLength = op.td.length
        throw new Error('trying to delete 0 element') if not index
        if cachedRange and index is cachedRange.getStartIndex()
            element = cachedRange.getStartElement()
            realOffset = cachedRange.getStartOffset()
            if @getElementLength(element) is cachedRange.getStartOffset()
                element = @getNextElement(element)
                realOffset = 0
        else
            [element, offset] = @_getElementAndOffset(index)
            offsetBefore = offset - @getElementLength(element)
            if @getElementType(element) isnt ModelType.TEXT or offset - index is 0
                element = @getNextElement(element)
                realOffset = 0
            else
                realOffset = index - offsetBefore
        if textLength + realOffset < element.textContent.length
            element.firstChild.deleteData(realOffset, textLength)
            @_drawCursorSafely(element, realOffset, user)
            return unless cachedRange
            if shiftCursor
                cachedRange.setCursor(element, realOffset, index)
            else
                cachedRange.processInsertText(element, realOffset, -textLength, index)
            return
        [_, element] = @_splitTextElement(element, realOffset, cachedRange)
        cursorElement = @getPreviousElement(element)
        cursorElementLength = @getElementLength(cursorElement)
        while textLength
            nextElement = @getNextElement(element)
            if @getElementType(element) isnt ModelType.TEXT
                throw new Error('trying to delete non-text element in text operation')
            elementLength = @getElementLength(element)
            if elementLength <= textLength
                textLength -= elementLength
                if not shiftCursor and cachedRange
                    cachedRange.processDeleteElement(index, element, elementLength, cursorElement, cursorElementLength)
            else
                [element, _] = @_splitTextElement(element, textLength, cachedRange)
                textLength = 0
            $(element).remove()
            element = nextElement
        if @getElementType(cursorElement) is ModelType.BLIP
            thread = BlipThread.getBlipThread(cursorElement)
            thread.mergeWithNext()
            @_drawCursorSafely(@getNextElement(cursorElement), 0, user)
        else
            @_drawCursorSafely(cursorElement, @getElementLength(cursorElement), user)
        if shiftCursor and cachedRange
            cachedRange.setCursor(cursorElement, @getElementLength(cursorElement), index)

    _handleOdOp: (op, cachedRange, user) ->
        index = op.p
        throw new Error('trying to delete 0 element') if not index
        params = op.params
        if cachedRange and index is cachedRange.getStartIndex()
            element = cachedRange.getStartElement()
            unless cachedRange.getStartOffset()
                element = @getPreviousElement(element)
                cachedRange.setStart(element, @getElementLength(element), index)
        else
            [element, _] = @_getElementAndOffset(index)
        switch params[ParamsField.TYPE]
            when ModelType.LINE
                @_handleLineDeleteOp(element, index, cachedRange)
            else
                @_handleInlineDeleteOp(element, index, cachedRange)
        @_drawCursorSafely(element, @getElementLength(element), user)

    _getParamValue: (params) ->
        for param, value of params
            return [param, value]

    _handleParamsOp: (op, shiftCursor, cachedRange, insert, user) ->
        index = op.p
        length = op.len
        params = if insert then op.paramsi else op.paramsd
        if cachedRange and index is cachedRange.getStartIndex()
            element = cachedRange.getStartElement()
            realOffset = cachedRange.getStartOffset()
            if realOffset is @getElementLength(element)
                element = @getNextElement(element)
                realOffset = 0
        else
            [element, offset] = @_getElementAndOffset(index)
            if index and (@getElementType(element) isnt ModelType.TEXT or offset - index is 0)
                element = @getNextElement(element)
                realOffset = 0
            else
                realOffset = index - offset + @getElementLength(element)
        type = @getElementType(element)
        [param, value] = @_getParamValue(params)
        switch type
            when ModelType.TEXT
                return @_handleTextParamOp(element, realOffset, cachedRange, index, length, param, value, insert, user)
            when ModelType.LINE
                return @_handleLineParamOp(element, cachedRange, param, value, insert, user)
            when ModelType.TASK_RECIPIENT
                return @_handleTaskRecipientParamOp(element, cachedRange, param, value, insert, user)
            when ModelType.GADGET
                return @_handleGadgetParamOp(element, param, value, insert, user)

    _handleGadgetParamOp: (element, param, value, insert, user) ->
        elementParams = @getElementParams(element)
        if insert
            elementParams[param] = value
        else
            delete elementParams[param]
            value = null
        @_setParamsToElement(element, elementParams)
        @emit('gadgetParamChange', element, elementParams, param, value)
        @_drawCursorSafely(element, @getElementLength(element), user)

    _handleTextParamOp: (element, realOffset, cachedRange, index, length, param, value, insert, user) ->
        throw "unexpected text param: #{param}" unless TextLevelParams.isValid(param)
        [_, startElement] = @_splitTextElement(element, realOffset, cachedRange)
        endIndex = index + length
        while length
            type = @getElementType(startElement)
            throw "text param could not be applied to #{type} type" unless type is ModelType.TEXT
            elLength = @getElementLength(startElement)
            if elLength > length
                [startElement] = @_splitTextElement(startElement, length, cachedRange)
                elLength = @getElementLength(startElement)
            params = @getElementParams(startElement)
            if insert
                params[param] = value
            else
                delete params[param]
            newElement = @_createTextElement(startElement.firstChild.data, params)
            DomUtils.insertNextTo(newElement, startElement)
            cachedRange.processReplaceElement(startElement, newElement) if cachedRange
            length -= elLength
            $(startElement).remove()
            startElement = @getNextElement(newElement)
        @_drawCursorSafely(newElement, @getElementLength(newElement), user)

    _handleLineParamOp: (element, cachedRange, param, value, insert, user) ->
        throw "unexpected line param: #{param}" unless LineLevelParams.isValid(param)
        params = @getElementParams(element)
        if insert
            params[param] = value
        else
            delete params[param]
        newElement = @_createLineElement(params)
        nodes = DomUtils.getNodeAndNextSiblings(element.firstChild)
        poped = nodes.pop()
        nodes.pop() if poped and poped.tagName?.toLowerCase() isnt 'br'
        DomUtils.moveNodesToStart(newElement, nodes)
        DomUtils.insertNextTo(newElement, element)
        cachedRange.processReplaceElement(element, newElement) if cachedRange
        @_linesUpdated = yes
        $(element).remove()
        @_drawCursorSafely(newElement, @getElementLength(newElement), user)

    _handleTaskRecipientParamOp: (element, cachedRange, param, value, insert, user) ->
        params = @getElementParams(element)
        if insert
            params[param] = value
        else
            delete params[param]
        $(element).data('object')?.destroy()
        removeArrayElement(@_taskRecipients, element)
        newElement = @_createInlineElement(params)
        DomUtils.insertNextTo(newElement, element)
        cachedRange.processReplaceElement(element, newElement) if cachedRange
        $(element).remove()
        @_drawCursorSafely(newElement, @getElementLength(newElement), user)

    getNextElement: (node = @_container) ->
        type = @getElementType(node)
        #TODO: do not look at contentEditable attribute
        if type is ModelType.LINE or ((node is @_container or node.getAttribute?('contentEditable') isnt 'false') and not type) or node.rzContainer
            child = node.firstChild
            while child
                return child if @getElementType(child)?
                firstNode = @getNextElement(child)
                return firstNode if firstNode
                child = child.nextSibling
        until node is @_container
            nextNode = node.nextSibling
            while nextNode
                return nextNode if @getElementType(nextNode)?
                nextEl = @getNextElement(nextNode)
                return nextEl if nextEl
                nextNode = nextNode.nextSibling
            node = node.parentNode
        null

    getDeepestLastNode: (node) ->
        ###
        Возвращает самого вложенного из последних наследников указнной ноды
        Возвращает саму ноду, если у нее нет наследников
        Не заходит внутрь нод, у которых contentEditable == false и не ялвяющихся тредом
        @param node: HTMLNode
        @return: HTMLNode
        ###
        #TODO: do not look at contentEditable attribute
        return node if (node.getAttribute?('contentEditable') is 'false') and node isnt @_container and not node.rzContainer
        return node if not node.lastChild
        return @getDeepestLastNode(node.lastChild)

    getPreviousElement: (node = null) ->
        return @getPreviousElement(@getDeepestLastNode(@_container)) unless node
        until node is @_container
            if prevNode = node.previousSibling
                deepest = @getDeepestLastNode(prevNode)
                return deepest if @getElementType(deepest)?
                return @getPreviousElement(deepest)
            node = node.parentNode
            return node if @getElementType(node)?
        null

    getElementType: (element) ->
        ###
        Возвращает тип указанного элемента
        @param element: HTMLElement - элемент, тип которого требуется получить
        @returns: null, если элемент не имеет типа, иначе string - одно из значений параметров класса ModelType
        ###
        return null unless element
        @_data(element, ModelField.PARAMS)?[ParamsField.TYPE] || null

    getElementParams: (element) ->
        ###
        Возвращает копию параметров указанного элемента
        @param element: HTMLElement - элемент, параметры которого требуется получить
        @returns: Object - параметры данного элемента
        ###
        return null unless element
        res = {}
        $.extend res, @_data(element, ModelField.PARAMS)
        res

    getElementLength: (element) ->
        ###
        Возвращает длину элемента - смещение, которое задает элемент в снимке содержимого редактора
        @param: element - HTMLElement - элемент, длину которого требуется получить
        @returns: int - длина элемента
        ###
        type = @getElementType(element)
        return 0 unless type?
        return 1 unless type is ModelType.TEXT
        element.firstChild.data.length

    insertNodeAt: (node, index) ->
        ###
        Вставляет указанную ноду по индексу в снимке содержимого, не проверяя параметры и не устанавливая параметры
        Нода будет вставлена после ноды, на которую попадает индекс
        @param node: HTMLNode - нода для вставки
        @param index: int - индекс, по котороуму следует вставить ноду
        ###
        [element, offset] = @_getElementAndOffset(index)
        elType = @getElementType(element)
        switch elType
            when ModelType.TEXT
                parNode = @getParagraphNode(element)
                [navElement, right] = @_splitTextElement(element, index - offset + @getElementLength(element))
                if navElement
                    insert = DomUtils.insertNextTo
                else
                    navElement = right
                    insert = parNode.insertBefore
                insert(node, navElement)
            when ModelType.LINE
                element.insertBefore(node, element.firstChild)
            when ModelType.BLIP
                @_insertInlineElementAfterBlip(node, element)
            else
                DomUtils.insertNextTo(node, element)

    insertTemporaryBlipNodes: (blipNodes, index, cachedRange) ->
        [element, offset] = @_getElementAndOffset(index)
        type = @getElementType(element)
        switch type
            when ModelType.TEXT
                [navElement, right] = @_splitTextElement(element, index - offset + @getElementLength(element), cachedRange)
                if navElement
                    insert = DomUtils.moveNodesNextTo
                else
                    navElement = right
                    insert = DomUtils.moveNodesBefore
                insert(blipNodes, navElement)
            when ModelType.LINE
                DomUtils.moveNodesBefore(blipNodes, element.firstChild)
            when ModelType.BLIP
                @_insertInlineElementsAfterBlip(blipNodes, element)
            else
                DomUtils.moveNodesNextTo(blipNodes, element)

    getRecipientNodes: -> @_recipients

    getTaskRecipientNodes: -> @_taskRecipients

    renderOps: (ops, container, textData) ->
        ###
        Отрисовка содержимого редактора в виде HTML по операциям, уходящим в буфер обмена
        ###
        currentLine = null
        currentLineIndent = -1
        currentLineType = null
        for op in ops
            params = op[ModelField.PARAMS]
            type = params[ParamsField.TYPE]
            switch type
                when ModelType.LINE
                    [currentLine, currentLineIndent, currentLineType] = @_renderLineHtmlElement(container, currentLine,
                            currentLineIndent, currentLineType, params, textData)
                when ModelType.TEXT
                    @_renderTextHtmlElement(container, currentLine, op.ti, params, textData)
                else
                    @_renderInlineHtmlElement(container, currentLine, op, textData)

    _renderInlineHtmlElement: (container, curLine, op, textData) ->
        params = op[ModelField.PARAMS]
        type = params[ParamsField.TYPE]
        switch type
            when ModelType.BLIP
                element = document.createElement('span')
                ops = op.ops
                return null unless ops
                @renderOps(ops, element, textData)
                @_addParamToElement('BLIP_PARAMS', element, op.blipParams)
                textData.push('\n') if textData
            when ModelType.ATTACHMENT
                element = document.createElement('img')
                element.src = params[ParamsField.URL]
            when ModelType.FILE
                element = document.createElement('a')
                element.href = params[ParamsField.URL]
                element.innerHTML = 'FILE'
            else
                element = document.createElement('span')
        @_addParamToElement('PARAMS', element, params)
        if curLine
            curLine.insertBefore(element, curLine.lastChild)
        else
            container.appendChild(element)

    _renderLineHtmlElement: (container, curLine, curIndent, currentType, params, textData) ->
        textData.push('\n') if textData
        if (indent = params[LineLevelParams.BULLETED])?
            type = 'b'
        else if (indent = params[LineLevelParams.NUMBERED])?
            type = 'n'
        else type = null
        unless type
            element = @_createLineHtmlElement('div')
            container.appendChild(element)
            curIndent = -1
            type = null
        else
            if type isnt currentType
                curLine = null
                curIndent = -1
            baseElement = curLine?.parentNode || container
            element = @_createLineHtmlElement('li')
            while curIndent isnt indent
                if curIndent > indent
                    curIndent -= 1
                    baseElement = baseElement.parentNode
                else
                    curIndent += 1
                    baseElement = baseElement.appendChild(document.createElement(if type is 'b' then 'ul' else 'ol'))
            baseElement.appendChild(element)
        @_addParamToElement('PARAMS', element, params)
        [element, curIndent, type]

    _createLineHtmlElement: (tagName) ->
        line = document.createElement(tagName)
        line.appendChild(document.createElement('br'))
        line

    _renderTextHtmlElement: (container, curLine, text, params, textData) ->
        textData.push(text) if textData
        element = @_createTextElement(text, params)
        @_addParamToElement('PARAMS', element, params)
        if curLine
            curLine.insertBefore(element, curLine.lastChild)
        else
            container.appendChild(element)

    _addParamToElement: (paramName, element, params) ->
        if element.dataset
            element.dataset[DATA_VARS[paramName]] = JSON.stringify(params)
        else
            element.setAttribute(DATA_ATTRS[paramName], JSON.stringify(params))

    _updateLines: ->
        index = -1
        levels = []
        for child in @_container.children
            params = @getElementParams(child)
            numbered = params[LineLevelParams.NUMBERED]
            bulleted = params[LineLevelParams.BULLETED]
            if (not numbered? and not bulleted?) or (bulleted? and bulleted <= index)
                index = -1
                levels = []
                continue
            continue if bulleted
            while numbered > index
                index += 1
                levels.push(0) unless levels[index]?
            while numbered < index
                levels[index--] = 0
            levels[index] += 1
            child.value = "#{levels[index]}"

    _getRectFromNodeSelection: (node, offset = null) ->
        r = document.createRange()
        if offset?
            r.setStart(node, offset)
            r.setEnd(node, offset + 1)
        else
            r.selectNode(node)
        rect = r.getBoundingClientRect()
        {top: rect.top, left: rect.left, right: rect.right, bottom: rect.bottom}

    _getCursorCoordFromText: (element, offset) ->
        toEnd = offset is @getElementLength(element)
        offset -= 1 if toEnd
        rect = @_getRectFromNodeSelection(element.firstChild, offset)
        if toEnd then rect.left = rect.right else rect.right = rect.left
        rect

    _getCursorCoordFromLine: (line, offset) ->
        unless offset
            prev = @getPreviousElement(line)
            throw new Error('do not have prev element') unless prev
            return @_getCursorCoordFromElement(prev, @getElementLength(prev))
        next = @getNextElement(line)
        if next and (type = @getElementType(next)) isnt ModelType.LINE and type isnt ModelType.BLIP
            return @_getCursorCoordFromElement(next, 0)
        rect = @_getRectFromNodeSelection(line)
        p = parseInt(window.getComputedStyle(line).paddingLeft) || 0
        rect.left += p
        rect.right = rect.left
        rect

    _getCursorCoordFromInline: (inline, offset) ->
        rect = @_getRectFromNodeSelection(inline)
        if offset
            rect.left = rect.right
        else
            rect.right = rect.left
        rect

    _getCursorCoordFromElement: (element, offset) ->
        switch @getElementType(element)
            when ModelType.TEXT
                rect = @_getCursorCoordFromText(element, offset)
            when ModelType.LINE
                rect = @_getCursorCoordFromLine(element, offset)
            when ModelType.BLIP
                return null
            else
                rect = @_getCursorCoordFromInline(element, offset)
        rect

    _getCursorCoord: (element, offset) ->
        rect = @_getCursorCoordFromElement(element, offset)
        return null unless rect
        DomUtils.convertWindowCoordsToRelative(rect, @_container.parentNode)
        rect

    _drawCursorSafely: (args...) -> try @_drawCursor(args...)

    _drawCursor: (element, offset, user) =>
#        user = {name, id}
        return unless user
        removeCursor = =>
            DomUtils.remove(cursor)
            delete globalCursors[user.id]
        return removeCursor() unless element
        r = @_getCursorCoord(element, offset)
        return removeCursor() unless r
        cursor = if (cursorObject = globalCursors[user.id]) then cursorObject.node else document.createElement('div')
        style = cursor.style
        style.top = "#{r.top}px"
        style.left = "#{r.left}px"
        style.height = "#{r.bottom - r.top}px"
        timerId = setTimeout(removeCursor, 2000)
        if cursorObject?
            @_container.parentNode.appendChild(cursor) if cursor.parentNode isnt @_container.parentNode
            clearTimeout(cursorObject.timerId)
            cursorObject.timerId = timerId
            return
        style = cursor.style
        style.backgroundColor = USER_COLORS[(parseInt(user.id.replace(/0_u_/, ''), 32) || 0) % USER_COLORS.length]
        for s of CURSOR_STYLE
            style[s] = CURSOR_STYLE[s]
        name = document.createElement('div')
        name.textContent = user.name || ''
        style = name.style
        for s of NAME_STYLE
            style[s] = NAME_STYLE[s]
        cursor.appendChild(name)
        @_container.parentNode.appendChild(cursor)
        globalCursors[user.id] = {node: cursor, timerId: timerId}

    applyOps: (ops, cachedRange, shiftCursor, user = null) ->
        @_linesUpdated = no
        lIndex = ops.length - 1
        u = null
        for op, i in ops
            u = user if i is lIndex
            @_applyOp(op, cachedRange, shiftCursor, u)
        @_updateLines() if @_linesUpdated

    applyOp: (op, cachedRange, shiftCursor, user = null) ->
        @_linesUpdated = no
        @_applyOp(op, cachedRange, shiftCursor, user)
        @_updateLines() if @_linesUpdated

    setParamsToInlineElement: (element, params) ->
        # Использовать этот метод только для блипов
        # т.к. удален метод preventEventsPropagation
        DomUtils.addClass(element, 'default-text')
        @_setParamsToElement(element, params)

    destroy: ->
        @removeAllListeners()
        for recipientNode in @_recipients
            $(recipientNode).data('recipient')?.destroy()
        for taskRecipient in @_taskRecipients
            $(taskRecipient).data('object')?.destroy()
        delete @_addInlineBlip
        delete @_removeInlineBlip
        delete @_getRecipient
        delete @_getNewInlineElement

    _applyOp: (op, cachedRange, shiftCursor, user) ->
        return @_handleOiOp(op, cachedRange, shiftCursor, user) if op.ti? and op[ModelField.PARAMS][ParamsField.TYPE] isnt ModelType.TEXT
        return @_handleOdOp(op, cachedRange, user) if op.td? and op[ModelField.PARAMS][ParamsField.TYPE] isnt ModelType.TEXT
        return @_handleTiOp(op, cachedRange, shiftCursor, user) if op.ti
        return @_handleTdOp(op, cachedRange, shiftCursor, user) if op.td
        return @_handleParamsOp(op, shiftCursor, cachedRange, yes, user) if op.paramsi
        return @_handleParamsOp(op, shiftCursor, cachedRange, no, user) if op.paramsd

MicroEvent.mixin(Renderer)
exports.Renderer = Renderer
exports.BULLETED_LIST_LEVEL_COUNT = BULLETED_LIST_LEVEL_COUNT
exports.BULLETED_LIST_LEVEL_PADDING = BULLETED_LIST_LEVEL_PADDING
exports.BULLETED_LIST_START_PADDING = BULLETED_LIST_START_PADDING