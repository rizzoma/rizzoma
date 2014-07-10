{MindMapNodeBlock} = require('../nodeblock/real')
{VirtualMindMapNodeBlock} = require('../nodeblock/virtual')
{BlipThread} = require('../../blip/blip_thread')
{getElement, addClass, removeClass, removeClasses} = require('../utils')
{MindMapThreadBase} = require('./base')
{THREAD_DRAG_ZONE_WIDTH, THREAD_DRAG_ZONE_HEIGHT, HIDDEN_THREAD_DRAG_ZONE_HEIGHT, ROOT_BLIP_SPACE,
DESCRIPTION_BLOCK_LINE_LEFT_OFFSET, DESCRIPTION_BLOCK_LINE_TOP_OFFSET, DESCRIPTION_HEIGHT_LINE_TOP_OFFSET,
DESCRIPTION_HEIGHT_LINE_LEFT_OFFSET, DESCRIPTION_HEIGHT_LINE_WIDTH, DROP_CHILD_THREAD_ZONE
} = require('../const')


class MindMapThread extends MindMapThreadBase
    constructor: (@_mindmap, @_parent, blips) ->
        super(@_mindmap, @_parent)
        @_possibleArrowClasses.push('selected')
        @_createDescriptionContainer()
        if not @isRoot()
            @_createDragZone()
            @_createArrow()
        @updateBlips(blips)

    _createThreadContainer: (className) ->
        className += ' root-thread' if @isRoot()
        super(className)

    _createDescriptionContainer: ->
        @_descriptionContainer = getElement('g')
        @_container.insertBefore(@_descriptionContainer, @_threadContainer)

    _createArrow: ->
        super()
        @_threadContainer.insertBefore(@_descriptionArrow, @_dragZone)

    _createDragZone: ->
        @_dragZone = getElement 'image',
            'width': THREAD_DRAG_ZONE_WIDTH
            'height': THREAD_DRAG_ZONE_HEIGHT
            'class': 'thread-drag-zone'
        @_dragZone.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', '/s/img/mindmap/thread_drag_zone.png')
        @_dragZone.dragNode = @
        @_threadContainer.insertBefore(@_dragZone, @_blockContainerParent)

    _updateDragZone: ->
        return if not @_dragZone?
        if not @_dragZoneIsShown()
            addClass(@_dragZone, 'hidden')
        else
            removeClass(@_dragZone, 'hidden')
            left = @getTextWidth() - THREAD_DRAG_ZONE_WIDTH
            @_dragZone.setAttribute('x', left)
            top = @_blocks[0].getParagraphTextTop(0) + @getBlockTop(0) - THREAD_DRAG_ZONE_HEIGHT
            @_dragZone.setAttribute('y', top)

    _dragZoneIsShown: -> @_blocks.length >= 2

    _getDragZoneHeight: ->
        if @_dragZoneIsShown() then THREAD_DRAG_ZONE_HEIGHT else HIDDEN_THREAD_DRAG_ZONE_HEIGHT

    _getBlocksByBlipId: ->
        res = {}
        for block in @_blocks
            if block instanceof MindMapNodeBlock
                res[block.getBlipId()] = block
            else
                @_removeBlock(block)
        return res

    _updateBlockLines: ->
        @_blockLines ?= []
        neededLength = @_blocks.length
        curLength = @_blockLines.length
        if curLength > neededLength
            for i in [neededLength-1...curLength]
                group = @_blockLines.pop()
                group.parentNode.removeChild(group)
        else
            for i in [curLength...neededLength]
                group = getElement('g')
                line = getElement('rect', {class: 'block-line-top', x: 0, y: 0, height: 1})
                group.appendChild(line)
                line = getElement('rect', {class: 'block-line-bottom', x: 0, y: 1, height: 1})
                group.appendChild(line)
                @_container.insertBefore(group, @_descriptionContainer)
                @_blockLines.push(group)

    _updateBlockLinePositions: ->
        # Горизонтальные линии между блипами корневого thread'а
        width = @getTotalWidth() - DESCRIPTION_BLOCK_LINE_LEFT_OFFSET
        for group, index in @_blockLines
            top = @getBlockDescriptionTop(index)
            group.setAttribute('transform', "translate(#{DESCRIPTION_BLOCK_LINE_LEFT_OFFSET}, #{top + DESCRIPTION_BLOCK_LINE_TOP_OFFSET})")
            for line in group.childNodes
                line.setAttribute('width', width)

    _updateBlockHeightLines: ->
        @_blockHeightLines ?= []
        neededLength = @_blocks.length
        curLength = @_blockHeightLines.length
        if curLength > neededLength
            for i in [neededLength-1...curLength]
                group = @_blockLines.pop()
                group.parentNode.removeChild(group)
        else
            for i in [curLength...neededLength]
                line = getElement 'rect',
                    class: 'blip-height-line'
                    x: DESCRIPTION_HEIGHT_LINE_LEFT_OFFSET
                    width: DESCRIPTION_HEIGHT_LINE_WIDTH
                @_container.insertBefore(line, @_descriptionContainer)
                @_blockHeightLines.push(line)

    _updateBlockHeightLinePositions: ->
        # Вертикальные линии слева от блипов корневого thread'а
        for line, index in @_blockHeightLines
            top = @getBlockDescriptionTop(index) + DESCRIPTION_HEIGHT_LINE_TOP_OFFSET
            height = @_blocks[index].getTotalHeight()
            line.setAttribute('y', top)
            line.setAttribute('height', height)

    updateBlips: (blips) ->
        ###
        Обновляет блипы треда
        @param blips: [BlipViewModel]
        ###
        newBlocks = []
        blockCache = @_getBlocksByBlipId()
        for blip, index in blips
            blipId = blip.getModel().serverId
            if blockCache[blipId]?
                newBlocks.push(blockCache[blipId])
                delete blockCache[blipId]
            else
                block = new MindMapNodeBlock(@_mindmap, @, blip, @isRoot() and index is 0)
                newBlocks.push(block)
                @_blockContainer.appendChild(block.getContainer())
                blockDescriptionParent = getElement('g')
                blockDescriptionParent.appendChild(block.getDescriptionContainer())
                @_descriptionContainer.insertBefore(blockDescriptionParent, @_descriptionContainer.firstChild)
        @_removeBlock(block) for _, block of blockCache
        @_blocks = newBlocks
        if @isRoot()
            @_updateBlockLines()
            @_updateBlockHeightLines()
        @invalidateAllCalculatedFields()

    _updateBlockPositions: ->
        if @isRoot()
            @_updateBlockLinePositions()
            @_updateBlockHeightLinePositions()
        super()

    _getBlockSpace: ->
        if @isRoot() then ROOT_BLIP_SPACE else super()

    isRoot: -> @_parent.isRoot()

    getTotalWidth: ->
        if @isHidden() then 0 else super()

    _getSelfTotalHeight: ->
        res = super()
        res += @_getDragZoneHeight() if res
        return res

    getTotalHeight: ->
        if @isHidden() then 0 else super()

    isHidden: ->
        thread = @_getTextThread()
        return false if not thread
        return thread.isFolded()

    isRead: -> @_getTextThread()?.isRead()

    _getTextThread: ->
        ###
        Возвращает объект thread'а из текстового представления
        ###
        return null if not @_blocks.length
        for block in @_blocks when block instanceof MindMapNodeBlock
            blipContainer = block.getBlipViewModel().getView().getContainer()
            return BlipThread.getBlipThread(blipContainer)
        return null

    hide: ->
        thread = @_getTextThread()
        return if not thread
        thread.fold()

    show: ->
        thread = @_getTextThread()
        if not thread
            @_parent.getParent().getBlipViewModel().getView().renderToRoot()
            thread = @_getTextThread()
        thread.unfold()

    foldAllRecursively: ->
        @hide() if not @isRoot() and not @isHidden()
        @invalidateAllCalculatedFields()
        block.foldAllRecursively() for block in @_blocks

    unfoldAllRecursively: ->
        @show() if not @isRoot() and @isHidden()
        @invalidateAllCalculatedFields()
        block.unfoldAllRecursively() for block in @_blocks

    updatePosition: ->
        return if not @_needsPositionUpdate
        super()
        @_updateDragZone()

    forceUpdateNeed: ->
        @_needsPositionUpdate = true

    updatePositionFromRoot: ->
        @_parent.updatePositionFromRoot()

    removeAllVirtualNodes: ->
        newBlocks = []
        for block in @_blocks
            if block instanceof MindMapNodeBlock
                newBlocks.push(block)
            else
                block.destroy()
        @_blocks = newBlocks
        @recursivelyInvalidateAllCalculatedFields()
        @updatePositionFromRoot()

    _getRootThreadBlockDescriptionBottom: (index) ->
        return -@_getBlockSpace() if index < 0
        blockBottom = @getBlockTop(index) + @_blocks[index].getSelfHeight()
        return Math.max(@getBlockDescriptionBottom(index), blockBottom)

    getBlockTop: (index) ->
        block = @_blocks[index]
        if not block.top?
            if @isRoot()
                # Блоки в корневом треде центруются со своим описанием
                prevBottom = @_getRootThreadBlockDescriptionBottom(index - 1)
                block.top = prevBottom + @_getBlockSpace() + (block.getTotalHeight() - block.getSelfHeight()) / 2
            else
                block.top = super(index)
                block.top += @_getDragZoneHeight() if index is 0
        return block.top

    _getShiftedBlockDescriptionTop: (index) ->
        block = @_blocks[index]
        if not block.descriptionTop?
            if @isRoot()
                block.descriptionTop = @_getRootThreadBlockDescriptionBottom(index - 1) + @_getBlockSpace()
            else
                super(index)
        return block.descriptionTop

    _getBlockIndexAtYCoord: (y) ->
        return 0 if y < @getBlockTop(0)
        for _, index in @_blocks
            return index - 1 if y < @getBlockTop(index)
        return @_blocks.length - 1

    _getBlockIndexWithDescriptionAtYCoord: (y) ->
        return 0 if y < @getBlockDescriptionTop(0)
        for _, index in @_blocks
            return index - 1 if y < @getBlockDescriptionTop(index)
        return @_blocks.length - 1

    getNodeToTheTopOfCoords: (x, y) ->
        return null if not @_blocks.length
        if x > @getTextWidth()
            curIndex = @_getBlockIndexWithDescriptionAtYCoord(y)
            while curIndex >= 0
                block = @_blocks[curIndex]
                if block instanceof MindMapNodeBlock
                    curRes = block.getNodeAtDescriptionZoneToTheTopOfCoords(x, y - @getBlockDescriptionTop(curIndex))
                    return curRes if curRes?
                curIndex--
        else
            curIndex = @_getBlockIndexAtYCoord(y)
            while curIndex >= 0
                block = @_blocks[curIndex]
                if block instanceof MindMapNodeBlock
                    curRes = block.getNodeToTheTopOfCoords(x, y - @getBlockTop(curIndex))
                    return curRes if curRes?
                curIndex--
        return null

    getNodeToTheBottomOfCoords: (x, y) ->
        return null if not @_blocks.length
        if x > @getTextWidth()
            curIndex = @_getBlockIndexWithDescriptionAtYCoord(y)
            while curIndex < @_blocks.length
                block = @_blocks[curIndex]
                if block instanceof MindMapNodeBlock
                    curRes = block.getNodeAtDescriptionZoneToTheBottomOfCoords(x, y - @getBlockDescriptionTop(curIndex))
                    return curRes if curRes?
                curIndex++
        else
            curIndex = @_getBlockIndexAtYCoord(y)
            while curIndex < @_blocks.length
                block = @_blocks[curIndex]
                if block instanceof MindMapNodeBlock
                    curRes = block.getNodeToTheBottomOfCoords(x, y - @getBlockTop(curIndex))
                    return curRes if curRes?
                curIndex++
        return null

    getNodeToTheLeftOfCoords: (x, y) ->
        return null if not @_blocks.length
        if x > @getTextWidth() + DROP_CHILD_THREAD_ZONE
            curIndex = @_getBlockIndexWithDescriptionAtYCoord(y)
            block = @_blocks[curIndex]
            if block instanceof MindMapNodeBlock
                return block.getNodeAtDescriptionZoneToTheLeftOfCoords(x, y - @getBlockDescriptionTop(curIndex))
        else
            curIndex = @_getBlockIndexAtYCoord(y)
            block = @_blocks[curIndex]
            if block instanceof MindMapNodeBlock
                return block.getNodeToTheLeftOfCoords(x, y - @getBlockTop(curIndex))
        return null

    getChildNodeRealIndex: (target) ->
        res = 0
        for block in @_blocks
            break if block is target
            res++ if not (block instanceof VirtualMindMapNodeBlock)
        return res

    _insertVirtualBlipAt: (index, content) ->
        virtualNodeBlock = new VirtualMindMapNodeBlock(@_mindmap, @, content)
        @_blocks.splice(index, 0, virtualNodeBlock)
        @_blockContainer.appendChild(virtualNodeBlock.getContainer())
        blockDescriptionParent = getElement('g')
        blockDescriptionParent.appendChild(virtualNodeBlock.getDescriptionContainer())
        @_descriptionContainer.appendChild(blockDescriptionParent)
        @recursivelyInvalidateAllCalculatedFields()

    insertVirtualBlipsAt: (index, data) ->
        for content in data
            @_insertVirtualBlipAt(index, content)
            index++

    removeChildBlipFromSnapshot: (blipId) ->
        @_parent.getParent().removeSnapshotBlip(blipId)

    insertBlipOpsAt: (index, ops) ->
        blip = @_parent.getParent()
        curIndex = index - 1
        while curIndex >=0
            block = @_blocks[curIndex]
            if block instanceof MindMapNodeBlock
                return blip.insertSnapshotBlipOpsInBlipAfter(block, ops)
            curIndex--
        curIndex = index
        while curIndex < @_blocks.length
            block = @_blocks[curIndex]
            if block instanceof MindMapNodeBlock
                return blip.insertSnapshotBlipOpsInBlipBefore(block, ops)
            curIndex++

    getBlipsData: ->
        (block.getTextBlocks() for block in @_blocks)

    getCopyOps: ->
        res = []
        for block in @_blocks
            res = res.concat(block.getCopyOps(block))
        return res

    removeFromSnapshot: ->
        @_parent.getParent().removeSnapshotParagraphThread(@_parent.getId())

    markSelectedBlock: (block) ->
        @_selectedBlockIndex = @getBlockIndex(block)
        @_needsPositionUpdate = true
        @_parent.markSelected()

    _getSelectedParagraphTop: ->
        # Возвращает верхнюю координату выделенного параграфа в системе координат треда
        res = 0
        block = @_blocks[@_selectedBlockIndex]
        selectedParaIndex = block.getSelectedParagraphIndex()
        res = block.getParagraphTextTop(selectedParaIndex)
        res += @getBlockTop(@_selectedBlockIndex)
        return res

    _getArrowEndAndClassName: (args...) ->
        # Возвращает y-координату конца стрелки и ее класс
        return super(args...) if not @_selectedBlockIndex?
        return [@_getSelectedParagraphTop() + 5, 'selected']

    unmarkSelectedBlock: ->
        @_selectedBlockIndex = null
        @_needsPositionUpdate = true
        @_parent.unmarkSelected()


module.exports = {MindMapThread}