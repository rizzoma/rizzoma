{ModelField, ParamsField, ModelType, LineLevelParams} = require('../../editor/model')
{getElement, getBlockType} = require('../utils')
{TEXT_NODE_HEIGHT, TEXT_NODE_PADDING_LEFT, BLIP_SPACE, DESCRIPTION_LEFT_OFFSET,
 MINIMAL_THREAD_WIDTH, ROOT_BLOCK_OFFSET_X, ROOT_BLOCK_OFFSET_Y,
 FOLD_BUTTON_WIDTH, FOLD_BUTTON_LEFT_PADDING, HEADER_OFFSET_X, HEADER_OFFSET_Y} = require('../const')


class MindMapNodeBlockBase
    constructor: (@_mindmap, @_parent) ->
        @_isRoot = !@_parent?
        @_createDOMNodes()
        @_updateContent({})
        @_needsPositionUpdate = true

    getParent: -> @_parent

    _createDOMNodes: ->
        ###
        Создает ноды, необходимые для отображения блипа
        ###
        @_container = getElement('g', {class: 'blip-container'})
        @_textContainer = getElement('g', {class: 'blip-text-container'})
        @_container.appendChild(@_textContainer)
        @_createBlipSizeBox()
        @_descriptionContainer = getElement('g')
        @_container.appendChild(@_descriptionContainer) if not @_parent?

    getContainer: -> @_container

    getTextContainer: -> @_textContainer

    getDescriptionContainer: -> @_descriptionContainer

    _createBlipSizeBox: ->
        ###
        Создает подложку, обозначающую границы блипа
        ###
        @_blipSizeBox = getElement 'rect',
            'class': 'blip-size-box'
        @_textContainer.appendChild(@_blipSizeBox)

    _updateBlipSizeBoxPosition: ->
        return if not @_blipSizeBox?
        top = @getParagraphTextTop(0)
        bottom = @getParagraphTextBottom(@_paragraphs.length - 1)
        @_blipSizeBox.setAttribute('y', top)
        @_blipSizeBox.setAttribute('width', @getThreadTextWidth())
        @_blipSizeBox.setAttribute('height', bottom - top)

    getNodeIndex: (node) ->
        for paragraph, index in @_paragraphs
            return index if paragraph.node is node
        return null

    getParagraphTextTop: (index) ->
        if not @_paragraphs[index].textTop?
            if index is 0
                if @isRoot()
                    @_paragraphs[index].textTop = HEADER_OFFSET_Y
                else
                    @_paragraphs[index].textTop = 0
            else
                res = @getParagraphTextBottom(index - 1)
                @_paragraphs[index].textTop = res
        return @_paragraphs[index].textTop

    getParagraphTextBottom: (index) ->
        if not @_paragraphs[index].textBottom?
            res = @getParagraphTextTop(index)
            if @_paragraphs[index].node?
                res += TEXT_NODE_HEIGHT
            @_paragraphs[index].textBottom = res
        return @_paragraphs[index].textBottom

    getParagraphTextMid: (index) ->
        top = @getParagraphTextTop(index)
        bot = Math.max(top, @getParagraphTextBottom(index))
        return (top + bot) / 2

    _getShiftedParagraphDescriptionTop: (index) ->
        # Может вернуть отрицательное значение
        return ROOT_BLOCK_OFFSET_Y if @isRoot()
        return 0 if index is 0
        if not @_paragraphs[index].descriptionTop?
            res = @getParagraphDescriptionBottom(index - 1)
            # Добавим отступ, если у текущей ноды отображается описание
            res += BLIP_SPACE if @_paragraphs[index].node?.getDescriptionHeight()
            @_paragraphs[index].descriptionTop = res
        return @_paragraphs[index].descriptionTop

    getParagraphDescriptionTop: (index) ->
        Math.max(@_getShiftedParagraphDescriptionTop(index), 0)

    getParagraphDescriptionBottom: (index) ->
        if not @_paragraphs[index].descriptionBottom?
            res = @_getShiftedParagraphDescriptionTop(index)
            if @_paragraphs[index].node?.getDescriptionHeight()
                res += @_paragraphs[index].node.getDescriptionHeight()
            else if index is 0
                # У первой ноды нет описания, сдвинем bottom вверх, чтобы следующая нода рисовалась от нуля
                res -= BLIP_SPACE
            @_paragraphs[index].descriptionBottom = res
        return @_paragraphs[index].descriptionBottom

    getBlockDescriptionTop: ->
        # Возвращает отступ описания блока в треде
        return 0 if not @_parent?
        index = @_parent.getBlockIndex(@)
        return @_parent.getBlockDescriptionTop(index)

    getBlockTop: ->
        # Возвращает отступ содержимого блока в треде
        return 0 if not @_parent?
        index = @_parent.getBlockIndex(@)
        return @_parent.getBlockTop(index)

    _getTextLeft: ->
        if @isRoot() then HEADER_OFFSET_X else 0

    getDescriptionTop: ->
        if @isRoot() then ROOT_BLOCK_OFFSET_Y else 0

    getDescriptionLeft: ->
        if @isRoot()
            return ROOT_BLOCK_OFFSET_X
        else
            return @getThreadTextWidth() + DESCRIPTION_LEFT_OFFSET

    updatePosition: ->
        return if not @_needsPositionUpdate
        textLeft = @_getTextLeft()
        for paragraph, index in @_paragraphs when paragraph.node
            paragraph.node.updatePosition()
            textTop = @getParagraphTextTop(index)
            paragraph.node.getContainer().setAttribute('transform', "translate(#{textLeft},#{textTop})")
            paragraph.node.getDescription().getContainer().setAttribute('transform', "translate(0,#{@getParagraphDescriptionTop(index)})")
        @_descriptionContainer.setAttribute('transform', "translate(#{@getDescriptionLeft()},#{@getDescriptionTop()})")
        @_updateBlipSizeBoxPosition()
        @_needsPositionUpdate = false

    updatePositionFromRoot: ->
        @_parent.updatePositionFromRoot()

    getChildNodePos: (node) ->
        count = 0
        pos = 0
        foundNode = false
        for paragraph, index in @_paragraphs when paragraph.node
            count++
            foundNode = true if paragraph.node is node
            pos++ if not foundNode
        return [pos, count]

    hasSingleChildNode: ->
        nodeCount = 0
        for paragraph in @_paragraphs when paragraph.node
            nodeCount++
            return false if nodeCount > 1
        return true

    _parseParagraphs: ->
        ###
        Разбирает содержимое блипа на параграфы
        @return: [{blocks: [block], id}]
        ###
        content = @_getContent()
        paragraphs = []
        curParagraph = null
        for block in content
            if getBlockType(block) is ModelType.LINE
                paragraphs.push(curParagraph) if curParagraph
                curParagraph = {blocks: []}
                curParagraph.id = block[ModelField.PARAMS][ParamsField.RANDOM]
            curParagraph.blocks.push(block)
        paragraphs.push(curParagraph)
        return paragraphs

    _getNodesByParagraphId: ->
        res = {}
        for paragraph in @_paragraphs when paragraph.node?
            if paragraph.node.isVirtual()
                paragraph.node.destroy()
            else
                res[paragraph.id] = paragraph.node
        return res

    forceChildrenUpdateNeed: ->
        ###
        Заставляет обновиться блип и все дочерние параграфы. Используется при изменении ширины треда.
        ###
        @_needsPositionUpdate = true
        for paragraph in @_paragraphs when paragraph.node?
            paragraph.node.forceUpdateNeed()
            paragraph.node?.getDescription().forceUpdateNeed()

    _invalidateHeightCalculatedFields: ->
        @_needsPositionUpdate = true
        for paragraph in @_paragraphs
            paragraph.textTop = null
            paragraph.textBottom = null
            paragraph.descriptionTop = null
            paragraph.descriptionBottom = null
            # Нужно обновить координаты стрелок у дочерних тредов этого блипа
            paragraph.node?.getDescription().forceUpdateNeed()

    _invalidateAllCalculatedFields: ->
        @_invalidateHeightCalculatedFields()
        @_invalidateTextWidth()

    recursivelyInvalidateAllCalculatedFields: ->
        ###
        Сбрасывает закешированные вычисленные значения
        ###
        @_invalidateAllCalculatedFields()
        @_parent?.recursivelyInvalidateAllCalculatedFields()

    invalidateIncludingChildren: ->
        @_invalidateAllCalculatedFields()
        for paragraph in @_paragraphs when paragraph.node?
            paragraph.node.invalidateIncludingChildren()

    _getBlipThreadId: (blipBlock) ->
        blipBlock[ModelField.PARAMS][ParamsField.THREAD_ID] || blipBlock[ModelField.PARAMS][ParamsField.ID]

    _isBlipBlock: (block) ->
        getBlockType(block) is ModelType.BLIP

    _getParagraphDescriptionBlipIds: (paragraph) ->
        ###
        Thread, находящийся в самом конце параграфа
        @param paragraph: [block]
        @return: [threadId] | null
        ###
        curBlockIndex = paragraph.blocks.length - 1
        while curBlockIndex >= 0
            lastBlock = paragraph.blocks[curBlockIndex]
            break if @_isBlipBlock(lastBlock)
            break if not @_isEmptyTextBlock(lastBlock)
            curBlockIndex--
        return [] if curBlockIndex < 0 or not @_isBlipBlock(lastBlock)
        threadId = @_getBlipThreadId(lastBlock)
        res = []
        while curBlockIndex >= 0
            curBlock = paragraph.blocks[curBlockIndex]
            break if @_getBlipThreadId(curBlock) isnt threadId
            res.push(curBlock[ModelField.PARAMS][ParamsField.ID])
            curBlockIndex--
        res.reverse()
        return res

    _updateParagraphContent: (paragraph, oldNodes, numberedListCounter) ->
        descriptionThreadBlipIds = @_getParagraphDescriptionBlipIds(paragraph)
        if paragraph.id of oldNodes
            node = oldNodes[paragraph.id]
            @_updateParagraphNode(node, paragraph.blocks, descriptionThreadBlipIds)
            delete oldNodes[paragraph.id]
        else
            node = @_getParagraphNode(paragraph.id, paragraph.blocks, descriptionThreadBlipIds)
            @_textContainer.appendChild(node.getContainer())
            @_descriptionContainer.insertBefore(node.getDescription().getContainer(), @_descriptionContainer.firstChild)
        if not node.isVirtual()
            numberLevel = paragraph.blocks[0][ModelField.PARAMS][LineLevelParams.NUMBERED]
            deleteStart = if numberLevel? then numberLevel + 1 else 0
            numberedListCounter.splice(deleteStart, numberedListCounter.length)
            if numberLevel?
                if numberedListCounter[numberLevel]?
                    newValue = numberedListCounter[numberLevel] + 1
                else
                    newValue = 1
                numberedListCounter[numberLevel] = newValue
                node.setNumberedListValue(newValue, numberLevel)
        paragraph.node = node

    _isEmptyTextBlock: (block) ->
        getBlockType(block) is ModelType.TEXT and
            block[ModelField.TEXT].match(/^\s*$/)

    _paragraphIsEmpty: (paragraph) ->
        for block, index in paragraph.blocks
            if index is 0
                return false if block[ModelField.PARAMS][LineLevelParams.BULLETED]?
                return false if block[ModelField.PARAMS][LineLevelParams.NUMBERED]?
                continue
            continue if index is 0
            return false if getBlockType(block) isnt ModelType.TEXT
            return false if not @_isEmptyTextBlock(block)
        return true

    _shouldUseParagraph: (index) -> true

    _updateContent: (oldNodes) ->
        ###
        Парсит и обновляет параграфы блипа
        @param oldNodes: {paragraphId: paragraph}, старые ноды, используются при обновлении
        @param reder: boolean, нужно ли рендерить создаваемые ноды
        ###
        @_paragraphs = @_parseParagraphs()
        hasNodes = false
        numberedListCounter = []
        for paragraph, index in @_paragraphs
            continue if not @_shouldUseParagraph(index)
            if @_paragraphIsEmpty(paragraph)
                numberedListCounter = []
                continue
            hasNodes = true
            @_updateParagraphContent(paragraph, oldNodes, numberedListCounter)
        if not hasNodes
            @_updateParagraphContent(@_paragraphs[0], oldNodes, numberedListCounter)
        for nodeId, node of oldNodes
            node.destroy()

    foldAllRecursively: ->
        @_invalidateHeightCalculatedFields()
        for paragraph in @_paragraphs when paragraph.node?
            paragraph.node.foldAllRecursively()

    unfoldAllRecursively: ->
        @_invalidateHeightCalculatedFields()
        for paragraph in @_paragraphs when paragraph.node?
            paragraph.node.unfoldAllRecursively()

    _invalidateTextWidth: ->
        @_textWidth = null
        for paragraph in @_paragraphs when paragraph.node?
            # Нужно сообщить ноде, что ширина изменилась
            paragraph.node.forceUpdateNeed()

    hasMaxWidth: ->
        ###
        Возвращает true, если хотя бы один из параграфов имеет максимальную ширину
        ###
        for paragraph in @_paragraphs when paragraph.node?
            return true if paragraph.node.isOfMaxWidth()

    getTextWidth: ->
        ###
        Возвращает ширину текста, выделяемую для всех нод этого блока
        @return: float
        ###
        if not @_textWidth?
            @_textWidth = MINIMAL_THREAD_WIDTH
            for paragraph in @_paragraphs when paragraph.node?
                @_textWidth = Math.max(@_textWidth, paragraph.node.getTextWidth())
            @_textWidth += 2 * TEXT_NODE_PADDING_LEFT
        return @_textWidth

    getThreadTextWidth: ->
        return @getTextWidth() if not @_parent?
        return @_parent.getTextWidth()

    _getParagraphIndexWithDescrtiptionAtYCoord: (y) ->
        return 0 if y < @getParagraphDescriptionTop(0)
        lastIndex = null
        for paragraph, index in @_paragraphs when paragraph.node?
            return index if @getParagraphDescriptionTop(index) <= y <= @getParagraphDescriptionBottom(index)
            lastIndex = index
        return lastIndex

    _canUseParagraphNode: (node) -> node?

    _getNodeAtTextZoneToTheTopOfCoords: (y) ->
        return null if @isRoot()
        # Середина текста для первого отображаемого параграфа
        return null if y < @getParagraphTextMid(0)
        nodeIndex = null
        for paragraph, index in @_paragraphs when @_canUseParagraphNode(paragraph.node)
            break if y < @getParagraphTextMid(index)
            nodeIndex = index
        return null if not nodeIndex?
        return [@_paragraphs[nodeIndex].node, y - @getParagraphTextMid(nodeIndex)]

    _getNodeAtTextZoneToTheBottomOfCoords: (y) ->
        return null if @isRoot()
        nodeIndex = null
        for paragraph, index in @_paragraphs when @_canUseParagraphNode(paragraph.node)
            nodeIndex = index
            break if y < @getParagraphTextMid(index)
        return null if y > @getParagraphTextMid(nodeIndex)
        return [@_paragraphs[nodeIndex].node, @getParagraphTextMid(nodeIndex) - y]

    _getNodeAtTextZoneToTheLeftOfCoords: (x, y) ->
        return null if @isRoot()
        for paragraph, index in @_paragraphs when @_canUseParagraphNode(paragraph.node)
            if @getParagraphTextTop(index) < y < @getParagraphTextBottom(index)
                return [paragraph.node, x - @getThreadTextWidth()]
        return null

    _getParagraphDescriptionCoordinates: (index, x, y) ->
        # Преобразует координаты к точке отсчета описания index-го параграфа
        newX = x - @getDescriptionLeft()
        newY = y - @getParagraphDescriptionTop(index) - @getDescriptionTop()
        return [newX, newY]

    getNodeAtDescriptionZoneToTheTopOfCoords: (x, y) ->
        curIndex = @_getParagraphIndexWithDescrtiptionAtYCoord(y)
        return null if not curIndex?
        while curIndex >= 0
            node = @_paragraphs[curIndex].node
            if node? and (@isRoot() or not node.isVirtual())
                [newX, newY] = @_getParagraphDescriptionCoordinates(curIndex, x, y)
                curRes = node.getNodeAtDescriptionZoneToTheTopOfCoords(newX, newY)
                return curRes if curRes?
            curIndex--
        return null

    getNodeAtDescriptionZoneToTheBottomOfCoords: (x, y) ->
        curIndex = @_getParagraphIndexWithDescrtiptionAtYCoord(y)
        return null if not curIndex?
        while curIndex < @_paragraphs.length
            node = @_paragraphs[curIndex].node
            if node? and (@isRoot() or not node.isVirtual())
                [newX, newY] = @_getParagraphDescriptionCoordinates(curIndex, x, y)
                curRes = node.getNodeAtDescriptionZoneToTheBottomOfCoords(newX, newY)
                return curRes if curRes?
            curIndex++
        return null

    getNodeAtDescriptionZoneToTheLeftOfCoords: (x, y) ->
        curIndex = @_getParagraphIndexWithDescrtiptionAtYCoord(y)
        return null if not curIndex?
        node = @_paragraphs[curIndex].node
        if node? and (@isRoot() or not node.isVirtual())
            [newX, newY] = @_getParagraphDescriptionCoordinates(curIndex, x, y)
            curRes = node.getNodeAtDescriptionZoneToTheLeftOfCoords(newX, newY)
            return curRes
        return null

    getNodeToTheTopOfCoords: (x, y) ->
        if x > @getDescriptionLeft()
            # Описание блипа
            return @getNodeAtDescriptionZoneToTheTopOfCoords(x, y)
        else if x < @_getTextLeft()
            # Отступ слева
            return null
        else if x < @getThreadTextWidth()
            # Текст в блипе
            return @_getNodeAtTextZoneToTheTopOfCoords(y)
        else
            # Пространство между блипом и описанием
            return null

    getNodeToTheBottomOfCoords: (x, y) ->
        if x > @getDescriptionLeft()
            # Описание блипа
            return @getNodeAtDescriptionZoneToTheBottomOfCoords(x, y)
        else if x < @_getTextLeft()
            # Отступ слева
            return null
        else if x < @getThreadTextWidth()
            # Текст в блипе
            return @_getNodeAtTextZoneToTheBottomOfCoords(y)
        else
            # Пространство между блипом и описанием
            return null

    getNodeToTheLeftOfCoords: (x, y) ->
        if x > @getDescriptionLeft()
            # Описание блипа
            return @getNodeAtDescriptionZoneToTheLeftOfCoords(x, y)
        else if x < @_getTextLeft()
            # Отступ слева
            return null
        else if x < @getThreadTextWidth()
            # Текст в блипе
            return null
        else
            # Пространство между блипом и описанием
            return @_getNodeAtTextZoneToTheLeftOfCoords(x, y)

        curIndex = @_getParagraphIndexAtYCoord(y)
        node = @_paragraphs[curIndex].node
        return null if not node?
        return node.getNodeToTheLeftOfCoords(x, y - @getParagraphTextTop(curIndex))

    getTotalWidth: ->
        ###
        Возвращает полную ширину этого блока вместе со всеми потомками
        @return: float
        ###
        descriptionWidth = 0
        hasDescription = false
        for paragraph in @_paragraphs when paragraph.node?
            hasDescription = true if paragraph.node.hasDescription()
            descriptionWidth = Math.max(descriptionWidth, paragraph.node.getDescriptionWidth())
        descriptionRight = 0
        if descriptionWidth
            descriptionRight = descriptionWidth + @getDescriptionLeft()
        threadRight = @_getTextLeft() + @getThreadTextWidth()
        threadRight += FOLD_BUTTON_WIDTH + FOLD_BUTTON_LEFT_PADDING if hasDescription
        return Math.max(threadRight, descriptionRight)

    getTotalHeight: ->
        ###
        Возвращает высоту этого блока вместе со всеми потомками
        @return: float
        ###
        return @getDescriptionHeight() + @getParagraphDescriptionTop(0) if @isRoot()
        return Math.max(@getDescriptionHeight(), @getSelfHeight())

    getSelfHeight: ->
        paraCount = 0
        for paragraph in @_paragraphs when paragraph.node?
            paraCount++
        return paraCount * TEXT_NODE_HEIGHT

    getDescriptionHeight: ->
        index = @_paragraphs.length - 1
        return Math.max(0, @getParagraphDescriptionBottom(index))

    isRoot: -> @_isRoot

    destroy: ->
        p.node?.destroy() for p in @_paragraphs
        @_container.parentNode.removeChild(@_container)
        delete @_container
        @_descriptionContainer.parentNode?.removeChild(@_descriptionContainer)
        delete @_descriptionContainer
        @_paragraphs = []
        delete @_parent
        @_destroyed = true

module.exports = {MindMapNodeBlockBase}