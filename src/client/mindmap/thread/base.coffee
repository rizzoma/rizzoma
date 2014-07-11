{getElement, addClass, removeClasses} = require('../utils')
{BLIP_SPACE, TEXT_NODE_HEIGHT, DESCRIPTION_ARROW_HEIGHT} = require('../const')

class MindMapThreadBase
    constructor: (@_mindmap, @_parent) ->
        @_blocks = []
        # Контейнер с блипами треда, описывающими параграф
        @_container = getElement('g')
        @_createThreadContainer('thread-container')
        @_createBlockContainer()
        @_needsPositionUpdate = true
        @_possibleArrowClasses = ['to-top', 'to-mid', 'to-bottom']

    getParent: -> @_parent

    _createThreadContainer: (className) ->
        # Контейнер блоков и их оформление
        @_threadContainer = getElement('g', class: className)
        if @_getSelfLeftOffset() || @_getSelfTopOffset()
            @_threadContainer.setAttribute('transform', "translate(#{@_getSelfLeftOffset()},#{@_getSelfTopOffset()})")
        @_container.appendChild(@_threadContainer)

    _createBlockContainer: ->
        # Контейнер для блоков
        @_blockContainerParent = getElement('g')
        @_blockContainer = getElement('g')
        @_blockContainerParent.appendChild(@_blockContainer)
        @_threadContainer.appendChild(@_blockContainerParent)

    getContainer: -> @_container

    getBlockContainer: -> @_blockContainer

    _removeBlock: (block) ->
        blockDescriptionParent = block.getDescriptionContainer()
        blockDescriptionParent.parentNode?.removeChild(blockDescriptionParent)
        block.destroy()

    _updateBlockPositions: ->
        # Mindmap'у нужно снимать копию треда для призрака при перетаскивании, поэтому смещение первой ноды
        # поставим blockContainerParent'у, а самим блокам будем дополнительно ставить разницу в смещении
        for block, index in @_blocks
            if index is 0
                @_blockContainerParent.setAttribute('transform', "translate(0, #{@getBlockTop(0)})")
            block.getContainer().setAttribute('transform', "translate(0,#{@getBlockTop(index) - @getBlockTop(0)})")
            block.getDescriptionContainer().parentNode?.setAttribute('transform', "translate(0,#{@getBlockDescriptionTop(index)})")
            block.updatePosition()

    _getBlockSpace: -> BLIP_SPACE

    getBlockTop: (index) ->
        block = @_blocks[index]
        if not block.top?
            if index is 0
                block.top = (@getTotalHeight() - @_getSelfTotalHeight()) / 2
            else
                space = @_getBlockSpace()
                block.top = @getBlockTop(index - 1) + @_blocks[index - 1].getSelfHeight() + space
        return block.top

    _getShiftedBlockDescriptionTop: (index) ->
        # Может вернуть отрицательное значение
        return 0 if index is 0
        if not @_blocks[index].descriptionTop?
            res = @getBlockDescriptionBottom(index - 1)
            # Добавим отступ, если у текущей ноды отображается описание
            res += BLIP_SPACE if @_blocks[index].getDescriptionHeight()
            @_blocks[index].descriptionTop = res
        return @_blocks[index].descriptionTop

    getBlockDescriptionTop: (index) ->
        res = Math.max(@_getShiftedBlockDescriptionTop(index), 0)
        return res

    getBlockDescriptionBottom: (index) ->
        if not @_blocks[index].descriptionBottom?
            res = @_getShiftedBlockDescriptionTop(index)
            if @_blocks[index].getDescriptionHeight()
                res += @_blocks[index].getDescriptionHeight()
            else if index is 0
                # У первой ноды нет описания, сдвинем bottom вверх, чтобы следующая нода рисовалась от нуля
                res -= BLIP_SPACE
            @_blocks[index].descriptionBottom = res
        return @_blocks[index].descriptionBottom

    invalidateAllCalculatedFields: ->
        @_needsPositionUpdate = true
        @_selfTotalHeight = null
        @_descriptionTotalHeight = null
        @_textWidth = null
        for block in @_blocks
            block.top = null
            block.descriptionTop = null
            block.descriptionBottom = null
            # Если изменилась ширина треда, нужно сообщить об этом всем параграфам треда
            block.forceChildrenUpdateNeed()

    getTotalWidth: ->
        return 0 if not @_blocks.length
        res = 0
        for block in @_blocks
            res = Math.max(res, block.getTotalWidth())
        return res + @_getSelfLeftOffset()

    invalidateIncludingChildren: ->
        @invalidateAllCalculatedFields()
        for block, i in @_blocks
            block.invalidateIncludingChildren()

    recursivelyInvalidateAllCalculatedFields: ->
        @invalidateAllCalculatedFields()
        @_parent.recursivelyInvalidateAllCalculatedFields()

    getBlocks: -> @_blocks

    updatePosition: ->
        return if not @_needsPositionUpdate
        @_updateBlockPositions()
        @_updateArrow()
        @_needsPositionUpdate = false

    _getSelfTotalHeight: ->
        if not @_selfTotalHeight
            space = @_getBlockSpace()
            height = 0
            height += block.getSelfHeight() + space for block in @_blocks
            @_selfTotalHeight = Math.max(0, height - space)
        return @_selfTotalHeight

    _getDescriptionTotalHeight: ->
        if not @_descriptionTotalHeight
            height = 0
            for block in @_blocks
                curHeight = block.getDescriptionHeight()
                height += curHeight + BLIP_SPACE if curHeight
            @_descriptionTotalHeight = Math.max(0, height - BLIP_SPACE)
        return @_descriptionTotalHeight

    getTotalHeight: ->
        Math.max(@_getSelfTotalHeight(), @_getDescriptionTotalHeight())

    _widthIsMax: ->
        for block in @_blocks
            return true if block.hasMaxWidth()
        return false

    getTextWidth: ->
        if not @_textWidth?
            if @_widthIsMax()
                @_textWidth = @_mindmap.getMaxThreadWidth()
            else
                res = 0
                res = Math.max(res, block.getTextWidth()) for block in @_blocks
                @_textWidth = res
        return @_textWidth

    _createArrow: ->
        @_descriptionArrow = getElement('g', {class: 'description-arrow'})
        @_descriptionArrow.appendChild(getElement('path'))
        line = getElement('path', {class: 'description-arrow-line'})
        @_descriptionArrow.appendChild(line)
        @_threadContainer.appendChild(@_descriptionArrow)

    _getSelfTopOffset: -> 0

    _getSelfLeftOffset: -> 0

    _getArrowEndAndClassName: (yStart) ->
        # Возвращает y-координату конца стрелки и ее класс в системе координат треда
        yEnd = @_blocks[0].getParagraphTextTop(0) + @getBlockTop(0)
        return [yEnd, 'to-top'] if @_blocks.length > 1
        textTop = @_blocks[0].getParagraphTextTop(0) + @getBlockTop(0)
        # У нас один блип, стрелку можно рисовать не только к верху
        selfHeight = @_blocks[0].getSelfHeight()
        # Если начало стрелки по высоте между centerFrom и centerTo, то стрелка будет к середине
        centerFrom = textTop + selfHeight / 10
        centerTo = textTop + selfHeight * 9 / 10
        if yStart < centerFrom
            # Стрелка к верху
            return [yEnd, 'to-top']
        if yStart < centerTo
            # Стрелка к середине
            yEnd += (selfHeight - DESCRIPTION_ARROW_HEIGHT) / 2
            return [yEnd, 'to-mid']
        # Стрелка к нижнему краю дочернего блипа
        yEnd += selfHeight - DESCRIPTION_ARROW_HEIGHT
        return [yEnd, 'to-bottom']

    _updateArrow: ->
        return if not @_descriptionArrow
        # У блока с текстовой нодой и блока с описанием разное начало координат
        # В системе координат родительского треда посчитаем координаты старта стрелки (середина fold
        # button'а) и координаты окончания стрелки (верх, середина или низ дочернего блока)
        parentBlock = @_parent.getParent()
        index = parentBlock.getNodeIndex(@_parent)
        # Координаты старта стрелки
        xStart = @_parent.getFoldButtonRight()
        yStart = @_parent.getFoldButtonMidY()
        yStart += parentBlock.getParagraphTextTop(index) + parentBlock.getBlockTop()
        # Левая координата треда
        selfLeft = parentBlock.getDescriptionLeft() + @_getSelfLeftOffset()
        # Верх блока с описанием в системе координат родителя
        selfTop = parentBlock.getParagraphDescriptionTop(index) + @_getSelfTopOffset() + parentBlock.getBlockDescriptionTop()
        # Y-координата окончания стрелки
        [yEnd, arrowClass] = @_getArrowEndAndClassName(yStart - selfTop)
        yEnd += selfTop
        removeClasses(@_descriptionArrow, @_possibleArrowClasses)
        addClass(@_descriptionArrow, arrowClass)
        # Переведем в свою систему координат
        width = selfLeft - xStart
        yDiff = yEnd - yStart
        xStart -= selfLeft
        yStart -= selfTop
        @_descriptionArrow.childNodes[0].setAttribute('d', "M #{xStart} #{yStart} l #{width} #{yDiff} l 0 #{DESCRIPTION_ARROW_HEIGHT} z")
        @_descriptionArrow.childNodes[1].setAttribute('d', "M #{xStart} #{yStart} l #{width} #{yDiff + DESCRIPTION_ARROW_HEIGHT / 2}")

    getBlockIndex: (searchedBlock) ->
        for block, index in @_blocks when block is searchedBlock
            return index
        return null

    destroy: ->
        @_removeBlock(block) for block in @_blocks
        @_container.parentNode?.removeChild(@_container)
        delete @_container


module.exports = {MindMapThreadBase}