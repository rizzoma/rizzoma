{MindMapNodeBlock} = require('./nodeblock/real')
{getElement, copy, addClass, removeClass} = require('./utils')
{TextNode} = require('./text_node')
{MindMapThread} = require('./thread/real')
{VirtualMindMapThread} = require('./thread/virtual')
{TEXT_NODE_HEIGHT, TEXT_Y_OFFSET, TEXT_NODE_PADDING_LEFT,
DESCRIPTION_LEFT_OFFSET, PARAGRAPH_LINE_LEFT_OFFSET, PARAGRAPH_LINE_HEIGHT,
FOLD_BUTTON_WIDTH, FOLD_BUTTON_HEIGHT, FOLD_BUTTON_TOP_OFFSET, FOLD_BUTTON_LEFT_PADDING,
DROP_CHILD_THREAD_ZONE} = require('./const')

class MindMapNode
    constructor: (@_mindmap, @_id, textBlocks, @_parent, descriptionBlips) ->
        @_createDOMNodes(textBlocks)
        @_description = new MindMapThread(@_mindmap, @, descriptionBlips)
        @_needsPositionUpdate = true

    getId: -> @_id

    _createDOMNodes: (textBlocks) ->
        ###
        Создает ноды, необходимые для отображения параграфа
        ###
        containerClass = 'node-container'
        containerClass += ' virtual' if @isVirtual() and not @isRoot()
        @_container = getElement('g', 'class': containerClass)
        # Контейнер с нодами, отображающими сам параграф
        @_createTextContainer(textBlocks)

    getContainer: -> @_container

    _createFoldButton: ->
        return if @_foldButtonGroup?
        @_foldButtonGroup = getElement('g')
        @_foldButton = getElement 'image',
            'width': FOLD_BUTTON_WIDTH
            'height': FOLD_BUTTON_HEIGHT
            'class': 'fold-button'
        @_foldButton.addEventListener('click', @_processFoldButtonClick)
        @_foldButton.mindMapNode = @
        @_foldButtonGroup.appendChild(@_foldButton)
        @_container.appendChild(@_foldButtonGroup)

    _destroyFoldButton: ->
        return if not @_foldButtonGroup?
        @_foldButton.removeEventListener('click', @_processFoldButtonClick)
        @_foldButtonGroup.parentNode.removeChild(@_foldButtonGroup)
        delete @_foldButton.mindMapNode
        delete @_foldButtonGroup

    _updateFoldButton: ->
        ###
        Обновляет видимость, позицию и картинку на кнопке сворачивания треда
        ###
        if @isRoot() or not @_description.getBlocks().length > 0
            addClass(@_foldButtonGroup, 'hidden')
            return
        removeClass(@_foldButtonGroup, 'hidden')
        name = []
        name.push(if @_descriptionIsHidden() then 'plus' else 'minus')
        name.push(if @_description.isRead() then 'read' else 'unread')
        @_foldButton.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', "/s/img/mindmap/#{name.join('_')}.png")
        @_foldButtonGroup.setAttribute('transform', "translate(#{@_getFoldButtonX()}, #{FOLD_BUTTON_TOP_OFFSET})")

    _getFoldButtonX: -> @_parent.getThreadTextWidth() + FOLD_BUTTON_LEFT_PADDING

    getFoldButtonRight: -> @_getFoldButtonX() + FOLD_BUTTON_WIDTH

    getFoldButtonMidY: -> FOLD_BUTTON_HEIGHT / 2

    _processFoldButtonClick: =>
        if @_descriptionIsHidden() then @_description.show() else @_description.hide()
        @recursivelyInvalidateAllCalculatedFields()
        @updatePositionFromRoot()

    _descriptionIsHidden: ->
        return true if @isVirtual() and not @isRoot()
        return @_description.isHidden()

    showDescription: ->
        return if not @_descriptionIsHidden()
        @_description.show()
        @recursivelyInvalidateAllCalculatedFields()
        @updatePositionFromRoot()

    _createTextContainer: (textBlocks) ->
        containerClass = if @isRoot() then 'root-node' else 'paragraph-label'
        @_textContainer = getElement('g', {class: containerClass})
        @_container.appendChild(@_textContainer)
        @_createSizeBox() if not @isRoot()
        @_createTextNode(textBlocks)
        @_textContainer.dragNode = @ if not @isRoot()
        # По спецификации svg 1.1 dblclick не работает, но firefox и chrome поддерживают
        @_textContainer.addEventListener('dblclick', @_switchToTextView) if not @isVirtual()
        @_textContainer.addEventListener('mouseover', @markSelected) if not @isVirtual()
        @_textContainer.addEventListener('mouseout', @unmarkSelected) if not @isVirtual()
        @_createFoldButton()
        @_createParagraphLine()

    _createTextNode: (textBlocks) ->
        @_textNode = new TextNode(@_mindmap, textBlocks)
        textNodeContainer = @_textNode.getContainer()
        textNodeContainer.setAttribute('transform', "translate(#{TEXT_NODE_PADDING_LEFT}, #{TEXT_Y_OFFSET})")
        @_textContainer.appendChild(textNodeContainer)

    _createSizeBox: ->
        # Создает прозрачный элемент, который заполнит все пространство ноды
        @_sizeBox = getElement('rect', {class: 'paragraph-size-box', height: TEXT_NODE_HEIGHT})
        @_textContainer.appendChild(@_sizeBox)

    _updateSizeBoxPosition: ->
        @_sizeBox?.setAttribute('width', @_parent.getThreadTextWidth())

    getTextNodeContainer: -> @_textNode.getContainer()

    _createParagraphLine: ->
        return if @isRoot()
        paraLine = getElement 'path',
            class: 'paragraph-line'
            d: "M #{PARAGRAPH_LINE_LEFT_OFFSET} #{(TEXT_NODE_HEIGHT - PARAGRAPH_LINE_HEIGHT) / 2} l 0 #{PARAGRAPH_LINE_HEIGHT}"
        @_textContainer.appendChild(paraLine)

    getTextBlocks: -> @_textNode.getTextBlocks()

    _switchToTextView: =>
        @_parent.switchToTextView(@_id)

    _destroyTextContainer: ->
        @_destroyFoldButton()
        @_textContainer.removeEventListener('dblclick', @_switchToTextView)
        @_textContainer.removeEventListener('mouseover', @markSelected)
        @_textContainer.removeEventListener('mouseout', @unmarkSelected)
        @_container?.removeChild(@_textContainer)

    updatePosition: ->
        ###
        Обновляет позиции и размеры всех элементов
        ###
        return if not @_needsPositionUpdate
        @_updateFoldButton()
        @_updateDescription()
        @_updateSizeBoxPosition()
        @_textNode.updatePosition()
        @_needsPositionUpdate = false

    updatePositionFromRoot: ->
        ###
        Обновляет позиции и размеры всех элементов, начиная от корня
        ###
        @_parent.updatePositionFromRoot()

    _updateDescription: ->
        if @_descriptionIsHidden() or not @_description.getBlocks().length
            addClass(@_description.getContainer(), 'hidden')
            return
        removeClass(@_description.getContainer(), 'hidden')
        @_description.updatePosition()

    getDescriptionHeight: ->
        return 0 if @_descriptionIsHidden()
        return @_description.getTotalHeight()

    getDescriptionWidth: ->
        res = 0
        if not @_descriptionIsHidden()
            res = @_description.getTotalWidth()
        if @_virtualDescription
            res = Math.max(res, @_virtualDescription.getTotalWidth())
        return res

    setTextBlocks: (textBlocks) ->
        @_textNode.setTextBlocks(textBlocks)
        @invalidateAllCalculatedFields()

    isRoot: -> @_parent.isRoot()

    foldAllRecursively: ->
        @_description.foldAllRecursively()
        @_needsPositionUpdate = true

    unfoldAllRecursively: ->
        @_description.unfoldAllRecursively()
        @_needsPositionUpdate = true

    getTextWidth: ->
        @_textNode.getTextWidth()

    isOfMaxWidth: ->
        @_textNode.widthIsMax()

    getDescription: -> @_description

    _getBlockIndexAtYCoord: (y) ->
        for block, index in @_description
            # текст рисуется вверх от указанной координаты, поэтому координату надо сместить на высоту текста при проверке
            curTop = @_getDescriptionBlockTop(index) - TEXT_NODE_HEIGHT
            return Math.max(0, index - 1) if y < curTop
        return @_description.length - 1

    getNodeAtDescriptionZoneToTheBottomOfCoords: (x, y) ->
        return null if @_descriptionIsHidden()
        return @_description.getNodeToTheBottomOfCoords(x, y)

    getNodeAtDescriptionZoneToTheTopOfCoords: (x, y) ->
        return null if @_descriptionIsHidden()
        return @_description.getNodeToTheTopOfCoords(x, y)

    getNodeAtDescriptionZoneToTheLeftOfCoords: (x, y) ->
        return null if @_descriptionIsHidden()
        return @_description.getNodeToTheLeftOfCoords(x, y)

    isVirtual: -> not @_id?

    getCopyOps: ->
        @_parent.getSnapshotParagraphInsertOps(@_id)

    removeFromSnapshot: ->
        @_parent.removeSnapshotParagraphBlocks(@_id)

    recursivelyInvalidateAllCalculatedFields: ->
        @invalidateAllCalculatedFields()
        @_parent.recursivelyInvalidateAllCalculatedFields()

    invalidateAllCalculatedFields: ->
        ###
        Сбрасывает все вычисляемые значения. Вызывается родительским блоком после обновления текста и описания.
        ###
        @_needsPositionUpdate = true
        @_textNode.invalidateAllCalculatedFields()

    invalidateIncludingChildren: ->
        @invalidateAllCalculatedFields()
        @_description.invalidateIncludingChildren()

    forceUpdateNeed: ->
        @_needsPositionUpdate = true

    getParent: -> @_parent

    hasDescription: ->
        for block in @_description.getBlocks()
            return true if block instanceof MindMapNodeBlock
        return false

    setNumberedListValue: (value, level) ->
        @_textNode.setNumberedListValue(value, level)

    insertVirtualDescription: (blips) ->
        @_virtualDescription = new VirtualMindMapThread(@_mindmap, @, blips)
        index = @_parent.getNodeIndex(@)
        @_parent.insertVirtualDescriptionForParagraph(index)
        @_virtualDescription.updatePosition()

    getVirtualDescription: -> @_virtualDescription

    removeAllVirtualNodes: ->
        @_virtualDescription?.destroy()
        delete @_virtualDescription

    insertBlipOpsAsDescription: (ops) ->
        @_parent.insertBlipOpsAsDescription(@_id, ops)

    markSelected: =>
        return if @_mindmap.isDragging()
        @_selected = true
        addClass(@_textContainer, 'selected')
        @_needsPositionUpdate = true
        @_parent.markSelectedParagraph(@_id)

    unmarkSelected: =>
        return if not @_selected
        removeClass(@_textContainer, 'selected')
        @_selected = false
        @_needsPositionUpdate = true
        @_parent.unmarkSelectedParagraph(@_id)

    destroy: ->
        @unmarkSelected()
        @_destroyTextContainer()
        @_description.destroy()
        delete @_description
        @removeAllVirtualNodes()
        delete @_parent
        @_container.parentNode?.removeChild(@_container)

module.exports = {MindMapNode}