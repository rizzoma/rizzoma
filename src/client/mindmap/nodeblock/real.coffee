{MindMapNodeBlockBase} = require('./base')
{ModelField, ParamsField, ModelType, LineLevelParams} = require('../../editor/model')
MicroEvent = require('../../utils/microevent')
History = require('../../utils/history_navigation')
{getElement, copy, copyNodeTextContent, getBlockType, removeClass, addClass} = require('../utils')
{TEXT_NODE_HEIGHT, BLIP_DRAG_ZONE_WIDTH, BLIP_DRAG_ZONE_HEIGHT,
BLIP_BACKGROUND_OFFSET, BLIP_BACKGROUND_REMOVE_TIMEOUT} = require('../const')

getMindMapNode = (args...) ->
    {MindMapNode} = require('../node')
    getMindMapNode = (args...) ->
        return new MindMapNode(args...)
    return getMindMapNode(args...)

class MindMapNodeBlock extends MindMapNodeBlockBase
    constructor: (@_mindmap, @_parent, @_blipViewModel, @_containsHeader) ->
        @_blipLoadCallbacks = {}
        @_waveViewModel = @_blipViewModel.getWaveViewModel()
        super(@_mindmap, @_parent)
        @_blipViewModel.on('remote-ops', @_updateText)
        @_blipViewModel.on('undo-redo-ops', @_updateText)
        @_blipViewModel.getView().on('ops', @_updateText)
        @animateBackground() if not @_mindmap.isFirstRender()

    _createDOMNodes: ->
        super()
        @_createDragZone() if not @isRoot()

    _createDragZone: ->
        @_dragZone = getElement 'image',
            'width': BLIP_DRAG_ZONE_WIDTH
            'height': BLIP_DRAG_ZONE_HEIGHT
            'x': -BLIP_DRAG_ZONE_WIDTH
            'class': 'blip-drag-zone'
        @_dragZone.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', '/s/img/mindmap/blip_drag_zone.png')
        @_dragZone.dragNode = @
        @_textContainer.appendChild(@_dragZone)

    _updateDragZone: ->
        return if not @_dragZone?
        @_dragZone.setAttribute('y',  @getParagraphTextTop(0))

    _createBlipSizeBox: ->
        return if @isRoot()
        super()

    updatePosition: ->
        return if @_waveViewModel.getView().getCurView() isnt 'mindmap'
        return if not @_needsPositionUpdate
        if @isRoot()
            parent = @_container.parentNode
            parent.removeChild(@_container)
        super()
        @_updateDragZone()
        @_updateBackgroundBoxPosition()
        if @_blipViewModel.getView().isRead()
            removeClass(@_textContainer, 'unread')
        else
            addClass(@_textContainer, 'unread')
        if parent
            parent.appendChild(@_container)
            window.setTimeout =>
                @emit('size-updated')
            , 0

    updatePositionFromRoot: ->
        return @updatePosition() if @isRoot()
        super()

    getChildNodeRealIndex: (node) ->
        virtualsBefore = 0
        for paragraph, index in @_paragraphs when paragraph.node
            if paragraph.node is node
                return index - virtualsBefore
            virtualsBefore++ if not paragraph.id?

    _getContent: ->
        @_blipViewModel.getModel().getSnapshotContent()

    _getBlips: (blipIds) ->
        res = []
        for blipId in blipIds
            descriptionBlip = @_blipViewModel.getView().getChildBlipByServerId(blipId)
            if descriptionBlip?
                delete @_blipLoadCallbacks[blipId]
                res.push(descriptionBlip)
            else
                if not @_blipLoadCallbacks[blipId]
                    @_blipLoadCallbacks[blipId] = true
                    @_waveViewModel.onBlipLoaded(blipId, @_updateText)
        return res

    _getTextBlocksFromText: (text) ->
        [
            {t: ' ', params: {__TYPE: 'LINE'}}
            {t: text, params: {__TYPE: 'TEXT'}}
        ]

    _getParagraphNode: (id, paragraphBlocks, blipIds) ->
        descriptionBlips = []
        blips = @_getBlips(blipIds)
        if @isRoot()
            paragraphBlocks = @_getTextBlocksFromText(blips[0].getModel().getTitle())
        return getMindMapNode(@_mindmap, id, paragraphBlocks, @, blips)

    _updateParagraphNode: (node, paragraphBlocks, blipIds) ->
        if @isRoot()
            paragraphBlocks = @_getTextBlocksFromText(blips[0].getModel().getTitle())
        node.setTextBlocks(paragraphBlocks)
        node.getDescription().updateBlips(@_getBlips(blipIds))

    _updateText: =>
        ###
        Реагирует на изменение текста блипа
        ###
        # Может остаться callback на загрузку дочернего блипа, а блок уже удален.
        return if @_destroyed
        oldNodes = @_getNodesByParagraphId()
        @_updateContent(oldNodes)
        @recursivelyInvalidateAllCalculatedFields()
        @updatePositionFromRoot()

    switchToTextView: (paragraphId) ->
        [pos] = @_getParagraphPosition(paragraphId, false)
        return if not pos?
        waveView = @_waveViewModel.getView()
        waveView.setTextView()
        @_blipViewModel.getView().getEditor().setCursorAtParagraph(pos + 1)
        waveView.scrollIntoView()

    getBlipId: -> @_blipViewModel.getModel().serverId

    foldAllRecursively: ->
        super()
        @updatePosition() if @isRoot()

    unfoldAllRecursively: ->
        super()
        @updatePosition() if @isRoot()

    _getParagraphPosition: (paragraphId, includeParagraph = false) ->
        pos = 0
        for paragraph, index in @_paragraphs
            if paragraph.id is paragraphId
                if not includeParagraph
                    return [pos, index]
            for block in paragraph.blocks
                pos += block[ModelField.TEXT].length
            if paragraph.id is paragraphId
                return [pos, index]
        return [null, null]

    _applyOps: (ops) ->
        blipView = @_blipViewModel.getView()
        blipView.submitOps(ops)
        blipView.getEditor()?.applyOps(ops, false)

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

    _getParagraphRemoveOps: (index, pos) ->
        ###
        Возвращает операции для удаления параграфа текста. Если удаляется первый параграф, то оставялет первый
        LINE-блок, вместо него удаляет LINE-блок следующего параграфа
        @param index: int, индекс удаляемого параграфа
        @param pos: int, количество символов до удаляемого параграфа
        ###
        throw new Error("Cannot remove single first paragraph") if index is 0 and @_paragraphs.length is 1
        ops = []
        if index is 0
            removedBlocks = @_paragraphs[index].blocks[1..]
            pos += 1
        else
            removedBlocks = @_paragraphs[index].blocks
        for block in removedBlocks
            ops.push
                td: block[ModelField.TEXT]
                p: pos
                params: copy(block.params)
        # Не удаляем LINE первого парагарфа, вместо него возьмем LINE следующего параграфа
        if index is 0
            nextLineBlock = @_paragraphs[index+1].blocks[0]
            ops.push
                td: nextLineBlock[ModelField.TEXT]
                p: 1
                params: copy(nextLineBlock.params)
            firstBlockChangeOps = @_getBlockParamsChangeOps(0, 1, @_paragraphs[0].blocks[0].params, nextLineBlock.params)
            ops = ops.concat(firstBlockChangeOps)
        return ops

    removeSnapshotParagraphBlocks: (paragraphId) ->
        [pos, index] = @_getParagraphPosition(paragraphId)
        if not index?
            console.warn("Mindmap tried to delete paragraph #{paragraphId} from blip #{@getBlipId()}, but it is not present")
            return
        if @_paragraphs.length is 1
            # Удалим блип целиком
            @_parent.removeChildBlipFromSnapshot(@getBlipId())
        else
            @_applyOps(@_getParagraphRemoveOps(index, pos))

    _getBlipBlock: (blipId) ->
        ###
        Возвращает позицию и блок с указанным блипом
        @param blipId: string
        @return: [pos, blipBlock]
        ###
        pos = 0
        for paragraph, index in @_paragraphs
            for block in paragraph.blocks
                if @_isBlipBlock(block) and block[ModelField.PARAMS][ParamsField.ID] is blipId
                    return [pos, block]
                pos += block[ModelField.TEXT].length
        return [null, null]

    removeSnapshotBlip: (blipId) ->
        [pos, blipBlock] = @_getBlipBlock(blipId)
        if not pos?
            console.warn("Mindmap tried to delete child blip #{blipId} from blip #{@getBlipId()}, but it is not present")
            return
        op =
            p: pos
            td: blipBlock.t
            params: copy(blipBlock.params)
        @_applyOps([op])

    _getParagraphThreadRemoveOps: (index, pos) ->
        ###
        Возвращает операции для удаления треда указанного параграфа.
        @param index: int, индекс удаляемого параграфа
        @param pos: int, количество символов до удаляемого параграфа
        ###
        lastBlockGroupOps = []
        lastPos = lastBlockGroupPos = pos
        for block in @_paragraphs[index].blocks
            type = getBlockType(block)
            lastPos += block[ModelField.TEXT].length
            if type is ModelType.BLIP
                lastBlockGroupOps.push
                    td: block[ModelField.TEXT]
                    p: lastBlockGroupPos
                    params: copy(block.params)
            else
                lastBlockGroupOps = []
                lastBlockGroupPos = lastPos
        return lastBlockGroupOps

    removeSnapshotParagraphThread: (paragraphId) ->
        [pos, index] = @_getParagraphPosition(paragraphId)
        if not index?
            console.warn("Mindmap tried to delete thread from paragraph #{paragraphId} from blip #{@getBlipId()}, but paragraph is not present")
            return
        @_applyOps(@_getParagraphThreadRemoveOps(index, pos))

    _getBlockInsertionOp: (block, node) ->
        type = getBlockType(block)
        params = copy(block[ModelField.PARAMS])
        return {ti: block.t, params} if type isnt ModelType.BLIP
        blipId = block[ModelField.PARAMS][ParamsField.ID]
        return @_blipViewModel.getView().getBlipCopyOpByServerId(blipId)

    _getParagraphInsertionOps: (paragraph) ->
        res = []
        for block in paragraph.blocks
            op = @_getBlockInsertionOp(block, paragraph.node)
            res.push(op) if op
        return res

    _getContentInsertionOps: ->
        res = []
        for paragraph in @_paragraphs
            res = res.concat(@_getParagraphInsertionOps(paragraph))
        return res

    getCopyOp: ->
        ops = @_getContentInsertionOps()
        model = @_blipViewModel.getModel()
        blipParams =
            isFoldedByDefault: model.isFoldedByDefault()
            contributors: model.getContributors()
            sourceBlipId: model.getServerId()
        params = {}
        params[ParamsField.TYPE] = ModelType.BLIP
        return {ti: ' ', params, ops, blipParams}

    getCopyOps: -> [@getCopyOp()]

    getTextBlocks: -> @_getContent()

    removeFromSnapshot: -> @_blipViewModel.getView().remove()

    insertSnapshotParagraphOpsAt: (index, ops) ->
        # Воспользуемся текстовым редактором для обработки вставки
        if index > 0
            paragraphId = @_paragraphs[index - 1].id
            [pos] = @_getParagraphPosition(paragraphId, true)
        else
            pos = 0
        blipView = @_blipViewModel.getView()
        blipView.renderRecursivelyToRoot()
        blipView.getEditor().pasteOpsAtPosition(pos, ops)

    insertBlipOpsAsDescription: (paragraphId, ops) ->
        [pos] = @_getParagraphPosition(paragraphId, true)
        return if not pos?
        # Воспользуемся текстовым редактором для обработки вставки
        blipView = @_blipViewModel.getView()
        blipView.renderRecursivelyToRoot()
        blipView.getEditor().pasteOpsAtPosition(pos, ops)

    _insertSnapshotBlipOpInBlipAfter: (block, op) ->
        blipContainer = block.getBlipViewModel().getView().getContainer()
        blipView = @_blipViewModel.getView()
        blipView.renderRecursivelyToRoot()
        blipView.getEditor().pasteBlipOpAfter(blipContainer, op)

    insertSnapshotBlipOpsInBlipAfter: (block, ops) ->
        i = ops.length - 1
        while i >= 0
            @_insertSnapshotBlipOpInBlipAfter(block, ops[i])
            i--

    _insertSnapshotBlipOpInBlipBefore: (block, op) ->
        blipContainer = block.getBlipViewModel().getView().getContainer()
        blipView = @_blipViewModel.getView()
        blipView.renderRecursivelyToRoot()
        blipView.getEditor().pasteBlipOpBefore(blipContainer, op)

    insertSnapshotBlipOpsInBlipBefore: (block, ops) ->
        @_insertSnapshotBlipOpInBlipBefore(block, op) for op in ops

    getSnapshotParagraphInsertOps: (paragraphId) ->
        ###
        Возвращает операции вставки параграфа и всех его тредов в формате text/rizzoma (см. текстовый редактор)
        @param paragraphId: string
        ###
        [pos, index] = @_getParagraphPosition(paragraphId, false)
        return null if not index?
        return @_getParagraphInsertionOps(@_paragraphs[index])

    getBlipViewModel: ->
        @_blipViewModel

    insertVirtualParagraphAt: (index, textBlocks) ->
        virtualPara =
            blocks: textBlocks
            node: getMindMapNode(@_mindmap, null, textBlocks, @, [])
        @_paragraphs.splice(index, 0, virtualPara)
        @_container.appendChild(virtualPara.node.getContainer())
        @recursivelyInvalidateAllCalculatedFields()

    removeAllVirtualNodes: ->
        newParagraphs = []
        for paragraph in @_paragraphs
            if paragraph.id?
                newParagraphs.push(paragraph)
            else
                paragraph.node.destroy()
        @_paragraphs = newParagraphs
        @recursivelyInvalidateAllCalculatedFields()
        @updatePositionFromRoot()

    _canUseParagraphNode: (node) -> node? and not node.isVirtual()

    insertVirtualDescriptionForParagraph: (index) ->
        container = @_paragraphs[index].node.getVirtualDescription().getContainer()
        container.setAttribute('transform', "translate(0,#{@getParagraphDescriptionTop(index)})")
        @_descriptionContainer.appendChild(container)

    _shouldUseParagraph: (index) ->
        # Не показываем первую строку первого блипа корневого треда - она уйдет в заголовок
        return true if index
        return not @_containsHeader

    animateBackground: ->
        # Показывает анимированный фон, служит для выделения блипов
        @_removeBackgroundBox()
        @_createBackgroundBox()
        @_updateBackgroundBoxPosition()
        @_backgroundBoxRemoveHandler = setTimeout(@_removeBackgroundBox, BLIP_BACKGROUND_REMOVE_TIMEOUT)

    _createBackgroundBox: ->
        @_backgroundBox = getElement 'rect',
            'class': 'blip-background-box'
        @_textContainer.insertBefore(@_backgroundBox, @_blipSizeBox)

    _updateBackgroundBoxPosition: ->
        return if not @_backgroundBox?
        top = @getParagraphTextTop(0) - BLIP_BACKGROUND_OFFSET
        bottom = @getParagraphTextBottom(@_paragraphs.length - 1) + BLIP_BACKGROUND_OFFSET
        @_backgroundBox.setAttribute('x', - BLIP_BACKGROUND_OFFSET)
        @_backgroundBox.setAttribute('y', top)
        @_backgroundBox.setAttribute('width', @getThreadTextWidth() + 2 * BLIP_BACKGROUND_OFFSET)
        @_backgroundBox.setAttribute('height', bottom - top)

    _removeBackgroundBox: =>
        @_backgroundBox?.parentNode?.removeChild(@_backgroundBox)
        delete @_backgroundBox
        clearTimeout(@_backgroundBoxRemoveHandler)

    _getParagraphIndex: (paragraphId) ->
        for paragraph, index in @_paragraphs
            return index if paragraph.id is paragraphId

    markSelectedParagraph: (paragraphId) ->
        @_selectedParagraphIndex = @_getParagraphIndex(paragraphId)
        @_needsPositionUpdate = true
        if @isRoot()
            @updatePosition()
        else
            @_parent.markSelectedBlock(@)

    getSelectedParagraphIndex: -> @_selectedParagraphIndex

    unmarkSelectedParagraph: ->
        @_selectedParagraphIndex = null
        @_needsPositionUpdate = true
        if @isRoot()
            @updatePosition()
        else
            @_parent.unmarkSelectedBlock()

    destroy: ->
        @removeListeners('size-updated')
        @_blipViewModel.removeListener('remote-ops', @_updateText)
        @_blipViewModel.getView().removeListener('ops', @_updateText)
        @_removeBackgroundBox()
        super()
        delete @_waveViewModel
MicroEvent.mixin(MindMapNodeBlock)


module.exports = {MindMapNodeBlock}
