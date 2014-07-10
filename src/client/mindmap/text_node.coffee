{getElement, getBlockType} = require('./utils')
{empty} = require('../utils/dom')
{ICO_WIDTH, ICO_HEIGHT, ICO_SIDE_PADDING, PIXELS_PER_SYMBOL, TEXT_Y_OFFSET} = require('./const')
{ModelField, ModelType, LineLevelParams} = require('../editor/model')
{BULLETED_LIST_LEVEL_COUNT, BULLETED_LIST_LEVEL_PADDING, BULLETED_LIST_START_PADDING} = require('../editor/renderer')

class TextNode
    ###
    Класс для отображения параграфа в mindmap
    ###
    constructor: (@_mindmap, @_textBlocks) ->
        @_container = getElement('g')
        @_updateViewBlocks()

    getContainer: -> @_container

    _getBlockNodesCache: ->
        res = {'text': {}, 'image': {}}
        return res if not @_viewBlocks?
        for block in @_viewBlocks
            continue if not block.node?
            if block.text?
                res.text[block.text] ?= []
                res.text[block.text].push(block.node)
            if block.path?
                res.image[block.path] ?= []
                res.image[block.path].push(block.node)
        return res

    _updateViewBlocks: ->
        blockNodesCache = @_getBlockNodesCache()
        empty(@_container)
        @_width = null
        [@_viewBlocks, @_widthIsMax] = @_getViewBlocks()
        for block in @_viewBlocks
            if block.text?
                cache = blockNodesCache.text[block.text]
                if cache?.length
                    block.node = cache.pop()
                else
                    block.node = @_createTextViewBlock(block.text)
            else
                cache = blockNodesCache.image[block.path]
                if cache?.length
                    block.node = cache.pop()
                else
                    block.node = @_createIcoViewBlock(block.path)
            @_container.appendChild(block.node)

    _getTextNodeWidth: (node) ->
        container = $("<span>#{node.childNodes[0].data}</span>")
        $('body').append(container)
        width = container[0].offsetWidth
        container.remove()
        return width

    _getViewBlockWidth: (index) ->
        block = @_viewBlocks[index]
        return ICO_WIDTH + 2 * ICO_SIDE_PADDING if block.path?
        res = @_getTextNodeWidth(block.node)
        res += block.offset if block.offset?
        res += block.rightOffset if block.rightOffset?
        return res

    _createTextViewBlock: (text) ->
        params = {'pointer-event': 'none'}
        res = getElement('text', params)
        res.appendChild(document.createTextNode(text))
        return res

    _createIcoViewBlock: (path) ->
        res = getElement 'image',
            'width': ICO_WIDTH
            'height': ICO_HEIGHT
            'y': -ICO_HEIGHT
        res.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', path)
        return res

    _getViewBlockRightPosition: (index) ->
        return 0 if index < 0
        block = @_viewBlocks[index]
        if not block.rightPosition?
            block.rightPosition = @_getViewBlockRightPosition(index - 1) + @_getViewBlockWidth(index)
        return block.rightPosition

    updatePosition: ->
        for block, index in @_viewBlocks
            left = @_getViewBlockRightPosition(index - 1)
            left += ICO_SIDE_PADDING if block.path?
            left += block.offset if block.offset?
            block.node.setAttribute('x', left)

    setTextBlocks: (@_textBlocks) ->
        @invalidateAllCalculatedFields()
        @_updateViewBlocks()

    getTextBlocks: -> @_textBlocks

    getTextWidth: ->
        @_getViewBlockRightPosition(@_viewBlocks.length - 1)

    widthIsMax: -> @_widthIsMax

    _getText: (blocks) ->
        res = ''
        maxLength = @_mindmap.getMaxNodeTextLength()
        for block, index in blocks
            continue if index is 0
            res += block[ModelField.TEXT]
            if res.length > maxLength
                res = res[0...maxLength - 1] + '…'
                break
        return res

    _addSymbolsToViewBlocks: (viewBlocks, symbols) ->
        if not viewBlocks.length or
            not viewBlocks[viewBlocks.length - 1].text? or
            viewBlocks[viewBlocks.length - 1].rightOffset?
                textViewBlock = {text: ''}
                viewBlocks.push(textViewBlock)
        else
            textViewBlock = viewBlocks[viewBlocks.length - 1]
        textViewBlock.text += symbols

    _getViewBlocks: ->
        res = []
        totalSymbols = 0
        haveMore = false
        maxLength = @_mindmap.getMaxNodeTextLength()
        for block, index in @_textBlocks
            if totalSymbols > maxLength - 1
                haveMore = true
                break
            if index is 0
                bulletLevel = block[ModelField.PARAMS][LineLevelParams.BULLETED]
                if bulletLevel?
                    shiftLevel = bulletLevel
                    addSymbols = "•◦▪"[bulletLevel % BULLETED_LIST_LEVEL_COUNT] + ' '
                else if @_numberedValue?
                    shiftLevel = @_numberedLevel
                    addSymbols = @_numberedValue + '. '
                continue if not shiftLevel?
                offset = BULLETED_LIST_START_PADDING + (shiftLevel - 1) * BULLETED_LIST_LEVEL_PADDING
                res.push({text: addSymbols, offset})
                totalSymbols += 1 + offset / PIXELS_PER_SYMBOL
            type = getBlockType(block)
            if type is ModelType.TEXT
                symbolsLeft = Math.floor(maxLength - totalSymbols)
                haveMore = true if symbolsLeft < block[ModelField.TEXT].length
                text = block[ModelField.TEXT][0...symbolsLeft]
                @_addSymbolsToViewBlocks(res, text)
                totalSymbols += text.length
            else if type in [ModelType.ATTACHMENT, ModelType.FILE]
                res.push({path: '/s/img/image_ico.png'})
                totalSymbols += (ICO_WIDTH + 2 * ICO_SIDE_PADDING) / PIXELS_PER_SYMBOL
        @_addSymbolsToViewBlocks(res, '…') if haveMore
        return [res, haveMore]

    setNumberedListValue: (@_numberedValue, @_numberedLevel) ->
        @_updateViewBlocks()

    invalidateAllCalculatedFields: ->
        @_width = @_numberedLevel = @_numberedValue = null
        for block in @_viewBlocks
            block.rightPosition = null
        @_updateViewBlocks()


module.exports = {TextNode}