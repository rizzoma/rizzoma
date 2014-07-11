DomUtils = require('./utils/dom')
{Utf16Util, matchUrls} = require('./utils/string')
LineLevelParams = require('./model').LineLevelParams
ModelField = require('./model').ModelField
ModelType = require('./model').ModelType
ParamsField = require('./model').ParamsField
TextLevelParams = require('./model').TextLevelParams

###
small
###

SKIP_TAGS =
    APPLET: null
    AREA: null
    AUDIO: null
    CANVAS: null
    COL: null
    COLGROUP: null
    COMMAND: null
    DATALIST: null
    EMBED: null
    FRAME: null
    FRAMESET: null
    HEAD: null
    IFRAME: null
    INPUT: null
    MAP: null
    MENU: null
    META: null
    METER: null
    NOFRAMES: null
    NOSCRIPT: null
    OBJECT: null
    OPTGROUP: null
    OPTION: null
    PARAM: null
    PROGRESS: null
    RP: null
    SCRIPT: null
    SELECT: null
    SOURCE: null
    STYLE: null
    TEXTAREA: null
    TITLE: null
    TRACK: null
    VIDEO: null


isSkippedElement = (element) ->
    element.tagName of SKIP_TAGS

class ParsedElementProcessor
    ###
    Интерфейс для совершения действий с результатами парсинга
    от него должны наследоваться процессры операций и блоков снэпшота
    ###
    createParsedElement: (text, params) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        throw new Error('Not implemented yet')

    getParsedElementText: (parsedElement) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        throw new Error('Not implemented yet')

    setParsedElementText: (parsedElement, text) ->
        ###
        Создает операцию или блок контента
        абстрактный метод
        ###
        throw new Error('Not implemented yet')


class TextParser
    constructor: (@_parsedElementProcessor, @_offset) ->

    __insertTextOp: (ops, text, textParams) ->
        ###
        @param ops: Array
        @param text: string, traversed string
        @param textParams: Object
        ###
        return null unless text

        pushText = (text, params = {}) ->
            return unless text
            paramsCopy = JSON.parse(JSON.stringify(textParams))
            paramsCopy[ParamsField.TYPE] = ModelType.TEXT
            for key, val of params
                paramsCopy[key] = val
            op = @_parsedElementProcessor.createParsedElement(text, paramsCopy, @_offset)
            @_offset += text.length
            ops.push(op)

        urls = matchUrls(text)
        lastIndex = 0
        for url in urls
            startIndex = url.startIndex
            endIndex = url.endIndex
            if lastIndex < startIndex
                pushText.call(@, text.substring(lastIndex, startIndex))
            urlText = text.substring(startIndex, endIndex)
            params = {}
            params[TextLevelParams.URL] = urlText unless textParams[TextLevelParams.URL]
            pushText.call(@, urlText, params)
            lastIndex = endIndex
        pushText.call(@, text.substring(lastIndex))

    __insertLineOp: (ops, lineParams) ->
        params = {}
        params[ParamsField.TYPE] = ModelType.LINE
        params[ParamsField.RANDOM] = Math.random()
        if lineParams[LineLevelParams.BULLETED]?
            params[LineLevelParams.BULLETED] = lineParams[LineLevelParams.BULLETED]
        else if lineParams[LineLevelParams.NUMBERED]?
            params[LineLevelParams.NUMBERED] = lineParams[LineLevelParams.NUMBERED]
        op = @_parsedElementProcessor.createParsedElement(' ', params, @_offset)
        @_offset += 1
        ops.push(op)

    __pushOp: (ops, op) ->
        return if not op or not @_parsedElementProcessor.getParsedElementText(op)?.length
        ops.push(op)
        @_offset += @_parsedElementProcessor.getParsedElementText(op).length

    __popOp: (ops) ->
        return null unless ops.length
        op = ops.pop()
        @_offset -= @_parsedElementProcessor.getParsedElementText(op).length
        op

    parseText: (ops, text, params = {}) ->
        return unless text
        text = text.replace(/\t/g, '    ')
        lines = text.split(/\r\n|\r|\n/g)
        lastLine = lines.pop()
        for line in lines
            @__insertTextOp(ops, Utf16Util.traverseString(line), params) if line
            @__insertLineOp(ops, {})
        @__insertTextOp(ops, Utf16Util.traverseString(lastLine), params) if lastLine

class HtmlParser extends TextParser
    constructor: (@_parsedElementProcessor, @_offset) ->
        @_blockNodeStarted = no
        @_blockNodeEnded = no
        @_isLastCharWhiteSpace = yes

    __insertTextOp: (ops, text, textParams, preserveSpaces = yes) ->
        if preserveSpaces
            @_maybePushLine(ops)
            return unless text
            @_isLastCharWhiteSpace = no
            super(ops, text, textParams)
            return
        return unless text
        if @_isLastCharWhiteSpace or @_isLastOpLine(ops) or @_needToPushLine(ops)
            text = text.replace(/^ /, '')
        textLength = text.length
        if textLength
            @_maybePushLine(ops)
            super(ops, text, textParams)
            @_isLastCharWhiteSpace = text.charAt(textLength - 1) is ' '

    __insertLineOp: (ops, lineParams) ->
        @_tryRemoveLastSpace(ops)
        super(ops, lineParams)
        @_isLastCharWhiteSpace = yes

    _insertOrReplaceLastLine: (ops, lineParams) ->
        if @_isLastOpLine(ops)
            op = @__popOp(ops)
            if op?.params?[LineLevelParams.BULLETED]? or op?.params?[LineLevelParams.NUMBERED]?
                @__pushOp(ops, op)
        @__insertLineOp(ops, lineParams)

    __insertImgOp: (ops, url) ->
        params = {}
        params[ParamsField.TYPE] = ModelType.ATTACHMENT
        params[ParamsField.URL] = url
        params[ParamsField.RANDOM] = Math.random()
        op = @_parsedElementProcessor.createParsedElement(' ', params, @_offset)
        @_offset += 1
        @_isLastCharWhiteSpace = no
        ops.push(op)

    _mapStyle: (name, value, params) ->
        switch name
            when 'backgroundColor'
                return if value is 'transparent' or not value or value is 'inherit'
                params[TextLevelParams.BG_COLOR] = value
                return params
            when 'fontStyle'
                switch value
                    when 'normal'
                        delete params[TextLevelParams.ITALIC] if params[TextLevelParams.ITALIC]?
                    when 'italic'
                        params[TextLevelParams.ITALIC] = yes
                return params
            when 'fontWeight'
                switch value
                    when 'normal'
                        delete params[TextLevelParams.BOLD] if params[TextLevelParams.BOLD]?
                    when 'bold', 'bolder'
                        params[TextLevelParams.BOLD] = yes 
                return params
            when 'textDecoration'
                values = value.split(' ')
                if values.indexOf('line-through') != -1
                    params[TextLevelParams.STRUCKTHROUGH] = yes
                else
                    delete params[TextLevelParams.STRUCKTHROUGH] if params[TextLevelParams.STRUCKTHROUGH]?
                if values.indexOf('underline') != -1
                    params[TextLevelParams.UNDERLINED] = yes
                else
                    delete params[TextLevelParams.UNDERLINED] if params[TextLevelParams.UNDERLINED]?
            else
                return params

    _getElementStyles: (element) ->
        params = {}
        switch element.tagName
            when 'U', 'INS'
                params[TextLevelParams.UNDERLINED] = yes
            when 'I', 'EM', 'DFN', 'VAR'
                params[TextLevelParams.ITALIC] = yes
            when 'B', 'STRONG'
                params[TextLevelParams.BOLD] = yes
            when 'STRIKE', 'DEL', 'S'
                params[TextLevelParams.STRUCKTHROUGH] = yes
            when 'A'
                params[TextLevelParams.URL] = element.href if element.href
        styles = element.style
        for style, val of styles
            @_mapStyle(style, val, params)
        params

    _maybePushLine: (ops, notCheckLastOp = no) ->
        if @_blockNodeStarted or @_blockNodeEnded
            if ops.length and (not @_isLastOpLine(ops) or notCheckLastOp)
                @__insertLineOp(ops, {})
            @_blockNodeStarted = no
            @_blockNodeEnded = no

    _needToPushLine: (ops) ->
        (@_blockNodeStarted or @_blockNodeEnded) and not @_isLastOpLine(ops)

    _collapseText: (text) ->
        return '' unless text
        textParts = text.split('\u00A0')
        textParts = (textPart.replace(/\s+/g, ' ') for textPart in textParts)
        textParts.join('\u00A0')

    _maybePushText: (ops, text, textParams, preserveLines, preserveSpaces) ->
        return unless text
        if preserveSpaces
            @_maybePushLine(ops)
            @parseText(ops, text, textParams)
            return
        if preserveLines
            lines = text.split(/\r\n|\r|\n/g)
            lastLine = @_collapseText(lines.pop())
            @_maybePushLine(ops)
            for line in lines
                @__insertTextOp(ops, Utf16Util.traverseString(@_collapseText(line)), textParams, no) if line
                @__insertLineOp(ops, {})
            @__insertTextOp(ops, Utf16Util.traverseString(lastLine), textParams, no) if lastLine
            return
        text = @_collapseText(text)
        @__insertTextOp(ops, Utf16Util.traverseString(text), textParams, no)

    _isLastOpLine: (ops) ->
        ops[ops.length - 1]?.params[ParamsField.TYPE] is ModelType.LINE

    _tryRemoveLastSpace: (ops) ->
        return unless @_isLastCharWhiteSpace
        lastOp = ops[ops.length - 1]
        return unless lastOp
        text = @_parsedElementProcessor.getParsedElementText(lastOp)
        textLength = text.length
        return unless textLength
        return if text.charAt(textLength - 1) isnt ' '
        return if lastOp.params[ParamsField.TYPE] isnt ModelType.TEXT
        if textLength is 1
            ops.pop()
        else
            @_parsedElementProcessor.setParsedElementText(lastOp, text.substr(0, textLength - 1))
        @_offset -= 1

    _parseAttrs: (attrs) ->

    _parseNode: (node, ops, textParams = {}, lineParams = {}, preserveLines = no, preserveSpaces = no) ->
        if DomUtils.isTextNode(node)
            text = node.data
            return unless text
            @_maybePushText(ops, text, textParams, preserveLines, preserveSpaces)
            return
        if not DomUtils.isElement(node) or isSkippedElement(node)
            return
        if node.tagName is 'BR'
            @__insertLineOp(ops, {})
            return
        if node.tagName is 'IMG'
            @_maybePushLine(ops)
            @__insertImgOp(ops, node.src) if node.src
            return
        isBlockElement = no
        isList = no
        params = @_getElementStyles(node)
        if DomUtils.isBlockElement(node)
            isBlockElement = yes
            @_blockNodeStarted = yes
            tagName = node.tagName
            if tagName is 'UL' or tagName is 'OL'
                isList = yes
                if (lvl = lineParams[LineLevelParams.BULLETED])?
                    lType = LineLevelParams.BULLETED
                else if (lvl = lineParams[LineLevelParams.NUMBERED])?
                    lType = LineLevelParams.NUMBERED
                else
                    lvl = -1
                    lType = null
                delete lineParams[lType] if lType
                newLType = if tagName is 'UL' then LineLevelParams.BULLETED else LineLevelParams.NUMBERED
                lineParams[newLType] = lvl + 1
            else if tagName is 'LI'
                @_insertOrReplaceLastLine(ops, lineParams)
        for own key, val of params
            tmp = textParams[key]
            textParams[key] = val
            params[key] = tmp || null
        child = node.firstChild
        whiteSpace = node.style?.whiteSpace || ''
        switch whiteSpace
            when 'pre-line'
                preserveLines = yes
                preserveSpaces = no
            when 'pre', 'pre-wrap'
                preserveLines = yes
                preserveSpaces = yes
            when 'normal', 'nowrap'
                preserveLines = no
                preserveSpaces = no
        while child
            @_parseNode(child, ops, textParams, lineParams, preserveLines, preserveSpaces)
            child = child.nextSibling
        if isBlockElement
            @_blockNodeStarted = no
            @_blockNodeEnded = yes
            if isList
                delete lineParams[newLType]
                lineParams[lType] = lvl if lType
        for own key, val of params
            val = params[key]
            if val?
                textParams[key] = val
            else
                delete textParams[key]

    parse: (documentFragment) ->
        ops = []
        tmpEl = document.createElement('span')
        tmpEl.appendChild(documentFragment)
        @_parseNode(tmpEl, ops)
        ops


module.exports =
    TextParser: TextParser
    HtmlParser: HtmlParser
    ParsedElementProcessor: ParsedElementProcessor