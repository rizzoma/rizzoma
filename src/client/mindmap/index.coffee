{MindMapNode} = require('./node')
{MindMapNodeBlock} = require('./nodeblock/real')
{MindMapThread} = require('./thread/real')
{getElement, addClass, removeClass, convertTextOpsToSnapshot, convertBlipOpsToSnapshot,
convertTextOpsToBlipOps} = require('./utils')
{ROLE_OWNER, ROLE_EDITOR} = require('../wave/participants/constants')
{TEXT_NODE_HEIGHT, GHOST_X_OFFSET, GHOST_Y_OFFSET, GHOST_MAX_WIDTH, GHOST_MAX_HEIGHT} = require('./const')
{SHORT_MAX_NODE_TEXT_LENGTH, LONG_MAX_NODE_TEXT_LENGTH} = require('./const')
{SHORT_MAX_THREAD_WIDTH, LONG_MAX_THREAD_WIDTH} = require('./const')
MAX_SCROLL_DELTA = 50
MAX_SPEED_SCROLL_ZONE = 30
SCROLL_ZONE = 70
MAX_TEXT_DROP_ZONE = TEXT_NODE_HEIGHT
MAX_CHILD_BLIP_DROP_ZONE = 25
MAX_THREAD_BLIP_DROP_ZONE = 40
DRAG_THRESHOLD_PIXELS = 7

class MindMap
    constructor: (@_waveViewModel) ->
        @_isFirstRender = true

    render: (@_container) ->
        @_svgWidth = @_svgHeight = 0
        @_createRootBlock()
        @_createSVGNode()
        @_rootBlock.updatePosition()
        @_isFirstRender = false
        @_initDrag()
        window.addEventListener('resize', @_updateScrollability)

    _createRootBlock: ->
        containerBlip = @_waveViewModel.getView().rootBlip
        @_rootBlock?.destroy()
        @_rootBlock = new MindMapNodeBlock(@, null, containerBlip)
        @_rootBlock.on('size-updated', @updateSize)

    _createSVGNode: ->
        @_svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
        @_svg.setAttribute('class', 'mindmap')
        @_svg.appendChild(@_rootBlock.getContainer())
        @_svgContainer = $("<div class=\"svg-container\"></div>")[0]
        @_svgContainer.appendChild(@_svg)
        @_container.appendChild(@_svgContainer)
        @_defs = getElement('defs')
        @_svg.appendChild(@_defs)
        @_createGradientDefs()
        @_createGhostClipPath()

    _createGradientDefs: ->
        @_defs.appendChild(@_getGradientDef('blipSizeBoxOddGradient'))
        @_defs.appendChild(@_getGradientDef('blipSizeBoxEvenGradient'))
        @_defs.appendChild(@_getGradientDef('virtualBlipSizeBoxGradient'))

    _getGradientDef: (id) ->
        stop1 = getElement('stop', {offset: '0%', class: 'start-color'})
        stop2 = getElement('stop', {offset: '100%', class: 'end-color'})
        gradient = getElement('linearGradient', {id: id, x1: '0%', y1: '0%', x2: '0%', y2: '100%'})
        gradient.appendChild(stop1)
        gradient.appendChild(stop2)
        return gradient

    _initDrag: ->
        @_canDrag = @_waveViewModel.getRole() in [ROLE_OWNER, ROLE_EDITOR]
        $(@_container).mousedown(@_processContainerMouseDown)

    _initDragEvents: ->
        $(@_container).mouseup(@_processContainerMouseUp)
        $(@_container).mousemove(@_processContainerMouseMove)

    _deinitDragEvents: ->
        $(@_container).off('mouseup', @_processContainerMouseUp)
        $(@_container).off('mousemove', @_processContainerMouseMove)

    _deinitDrag: ->
        $(@_container).off('mousedown', @_processContainerMouseDown)
        @_deinitDragEvents()

    _getCoordinates: (e, offsetElement) ->
        coords = $(offsetElement).offset()
        return {
            x: e.pageX - coords.left
            y: e.pageY - coords.top
        }

    _getSvgCoordinates: (e) -> @_getCoordinates(e, @_svg)

    _getContainerCoordinates: (e) -> @_getCoordinates(e, @_container)

    _dropTargetsAreEqual: (a, b) ->
        return true if not a? and not b?
        return false if not a? or not b?
        return a[0] is b[0] and a[1] is b[1]

    _getTextTopDropTarget: (node) ->
        return @_dropTarget if node.isVirtual()
        block = node.getParent()
        virtualIndex = block.getChildNodeRealIndex(node) + 1
        return [block, virtualIndex]

    _getBlipTopDropTarget: (node) ->
        return @_dropTarget if node.isVirtual()
        block = node.getParent()
        thread = block.getParent()
        virtualIndex = thread.getChildNodeRealIndex(block) + 1
        return [thread, virtualIndex]

    _getTextBottomDropTarget: (node) ->
        return @_dropTarget if node.isVirtual()
        block = node.getParent()
        virtualIndex = block.getChildNodeRealIndex(node)
        # Не позволяем ставить блипы перед корневой нодой топика
        return null if block.getParent().getParent().isRoot() and virtualIndex < 2
        return [block, virtualIndex]

    _getBlipBottomDropTarget: (node) ->
        return @_dropTarget if node.isVirtual()
        block = node.getParent()
        thread = block.getParent()
        virtualIndex = thread.getChildNodeRealIndex(block)
        # Не позволяем ставить блипы перед корневой нодой топика
        return null if thread.getParent().isRoot() and virtualIndex is 0
        return [thread, virtualIndex]

    _getBlipLeftDropTarget: (node) ->
        return @_dropTarget if node.isVirtual()
        return [node, 0]

    _getTopDropTarget: (node, dist, textDropZone, blipDropZone) ->
        if not textDropZone? or dist < textDropZone
            return @_getTextTopDropTarget(node)
        else if not blipDropZone? or dist < blipDropZone
            return @_getBlipTopDropTarget(node)
        else
            return null

    _getBottomDropTarget: (node, dist, textDropZone, blipDropZone) ->
        if not textDropZone? or dist < textDropZone
            return @_getTextBottomDropTarget(node)
        else if not blipDropZone? or dist < blipDropZone
            return @_getBlipBottomDropTarget(node)
        else
            return null

    _getVerticalDropTargetForParagraph: (x, y) ->
        top = @_rootBlock.getNodeToTheTopOfCoords(x, y)
        bottom = @_rootBlock.getNodeToTheBottomOfCoords(x, y)
        if top? and bottom?
            topBlock = top[0].getParent()
            bottomBlock = bottom[0].getParent()
            blipDropZone = null
            if topBlock isnt bottomBlock
                # Разные блипы
                dist = top[1] + bottom[1]
                if topBlock.getParent() isnt bottomBlock.getParent()
                    # Разные треды
                    textDropZone = Math.min(MAX_TEXT_DROP_ZONE, dist / 4)
                    blipDropZone = MAX_THREAD_BLIP_DROP_ZONE
                else
                    textDropZone = Math.min(MAX_TEXT_DROP_ZONE, dist / 3)
            if top[1] < bottom[1]
                res = @_getTopDropTarget(top[0], top[1], textDropZone, blipDropZone)
            else
                res = @_getBottomDropTarget(bottom[0], bottom[1], textDropZone, blipDropZone)
        else if top?
            res = @_getTopDropTarget(top[0], top[1], MAX_TEXT_DROP_ZONE, MAX_THREAD_BLIP_DROP_ZONE)
        else if bottom?
            res = @_getBottomDropTarget(bottom[0], bottom[1], MAX_TEXT_DROP_ZONE, MAX_THREAD_BLIP_DROP_ZONE)
        else
            res = null
        return res

    _getVerticalDropTargetForBlip: (x, y) ->
        top = @_rootBlock.getNodeToTheTopOfCoords(x, y)
        bottom = @_rootBlock.getNodeToTheBottomOfCoords(x, y)
        if top? and bottom?
            topBlock = top[0].getParent()
            bottomBlock = bottom[0].getParent()
            if topBlock is bottomBlock
                # Курсор между параграфами одного блипа
                res = null
            else
                if topBlock.getParent() is bottomBlock.getParent()
                    # Курсор между блипами одного треда
                    if top[1] < bottom[1]
                        res = @_getBlipTopDropTarget(top[0]) #@_getTopDropTarget(top[0], top[1], 0, MAX_THREAD_BLIP_DROP_ZONE)
                    else
                        res = @_getBlipBottomDropTarget(bottom[0]) #@_getBottomDropTarget(bottom[0], bottom[1], 0, MAX_THREAD_BLIP_DROP_ZONE)
                else
                    # Курсор между блипами разных тредов
                    if top[1] < bottom[1]
                        res = @_getTopDropTarget(top[0], top[1], 0, MAX_THREAD_BLIP_DROP_ZONE)
                    else
                        res = @_getBottomDropTarget(bottom[0], bottom[1], 0, MAX_THREAD_BLIP_DROP_ZONE)
        else if top?
            res = @_getTopDropTarget(top[0], top[1], 0, MAX_THREAD_BLIP_DROP_ZONE)
        else if bottom?
            res = @_getBottomDropTarget(bottom[0], bottom[1], 0, MAX_THREAD_BLIP_DROP_ZONE)
        else
            res = null
        return res

    _nodeHasAncestor: (node, ancestor) ->
        while node?
            return true if node is ancestor
            node = node.getParent()
        return false

    _canUseDropTarget: (dropTarget) ->
        return true if not dropTarget?
        # Нельзя вставить себя в потомка
        return false if @_nodeHasAncestor(dropTarget[0], @_movedNode)
        # Нельзя вставить тред или блип как текст
        return false if dropTarget[0] instanceof MindMapNodeBlock and
            (@_movedNode instanceof MindMapThread or @_movedNode instanceof MindMapNodeBlock)
        movedParent = @_movedNode.getParent()
        # Нельзя вставить себя на свое же место
        return true if dropTarget[0] isnt movedParent
        movedIndex = movedParent.getChildNodeRealIndex(@_movedNode)
        return dropTarget[1] not in [movedIndex, movedIndex + 1]

    _updateDropTarget: ->
        return if not @_movedNode?
        {x, y} = @_getSvgCoordinates(@_lastMoveEvent)
        left = @_rootBlock.getNodeToTheLeftOfCoords(x, y)
        if left? and not left[0].hasDescription() and left[1] < MAX_CHILD_BLIP_DROP_ZONE
            newDropTarget = @_getBlipLeftDropTarget(left[0])
        else
            if @_movedNode instanceof MindMapNode
                newDropTarget = @_getVerticalDropTargetForParagraph(x, y)
            else
                newDropTarget = @_getVerticalDropTargetForBlip(x, y)
        newDropTarget = null if not @_canUseDropTarget(newDropTarget)
        return if @_dropTargetsAreEqual(@_dropTarget, newDropTarget)
        @_removeDropTarget()
        @_setDropTarget(newDropTarget)

    _setDropTarget: (target) ->
        return if not target?
        if target[0] instanceof MindMapThread
            target[0].insertVirtualBlipsAt(target[1], @_movedBlipsSnapshot)
        else if target[0] instanceof MindMapNodeBlock
            target[0].insertVirtualParagraphAt(target[1], @_movedTextSnapshot)
        else
            target[0].insertVirtualDescription(@_movedBlipsSnapshot)
        @_dropTarget = target
        addClass(@_ghost, 'hidden') if @_ghost?

    _removeDropTarget: ->
        return if not @_dropTarget?
        @_dropTarget[0].removeAllVirtualNodes()
        delete @_dropTarget
        removeClass(@_ghost, 'hidden') if @_ghost?

    _getDragNode: (node) ->
        node = node.parentNode while node? and not node.dragNode?
        return node?.dragNode

    _processContainerMouseDown: (e) =>
        return if e.button isnt 0
        node = @_getDragNode(e.target) if @_canDrag
        if node
            @_movedOps = node.getCopyOps()
            if node instanceof MindMapNode
                @_ghostNode = node.getTextNodeContainer()
                @_movedTextSnapshot = convertTextOpsToSnapshot(@_movedOps)
                @_movedBlipsSnapshot = [@_movedTextSnapshot]
            # тред и блип не представляются в текстовом виде
            else if node instanceof MindMapNodeBlock
                @_ghostNode = node.getTextContainer()
                @_movedTextSnapshot = null
                @_movedBlipsSnapshot = convertBlipOpsToSnapshot(@_movedOps)
            else if node instanceof MindMapThread
                @_ghostNode = node.getBlockContainer()
                @_movedTextSnapshot = null
                @_movedBlipsSnapshot = convertBlipOpsToSnapshot(@_movedOps)
            @_lastMoveEvent = e
            @_startX = e.screenX
            @_startY = e.screenY
            @_movedNode = node
            @_createGhost()
        else if @_scrollable
            {x, y} = @_getContainerCoordinates(e)
            if (x < $(@_container).innerWidth() - 20) and (y < $(@_container).innerHeight() - 20)
                @_startX = e.screenX
                @_startY = e.screenY
                @_startScrollLeft = @_svgContainer.scrollLeft
                @_startScrollTop = @_svgContainer.scrollTop
                addClass(@_svgContainer, 'moving')
        @_initDragEvents()
        e.preventDefault()

    _performDrop: (dropNode, dropIndex, movedNode, movedOps) ->
        if dropNode instanceof MindMapNodeBlock
            dropNode.insertSnapshotParagraphOpsAt(dropIndex, movedOps)
        else
            if movedNode instanceof MindMapNode
                # Обернем текстовые операции в блип, чтобы вставить как тред или как часть треда
                ops = convertTextOpsToBlipOps(movedOps)
            else
                ops = movedOps
            if dropNode instanceof MindMapThread
                dropNode.insertBlipOpsAt(dropIndex, ops)
            else
                dropNode.insertBlipOpsAsDescription(ops)
        movedNode.removeFromSnapshot()

    _processContainerMouseUp: =>
        if @_dropTarget?
            [dropNode, dropIndex] = @_dropTarget
        @_removeDropTarget()
        @_performDrop(dropNode, dropIndex, @_movedNode, @_movedOps) if dropNode?
        @_movedNode = null
        @_movedOps = null
        @_startX = null
        removeClass(@_svgContainer, 'moving')
        @_dragStarted = false
        @_deinitDragEvents()
        @_removeGhost()
        @_removeAutoscrollTimer()

    _processContainerMouseMove: (e) =>
        if @_ghost
            if e.target.mindMapNode?
                e.target.mindMapNode.showDescription()
            @_lastMoveEvent = e
            if not @_dragStarted
                dist = Math.abs(e.screenX - @_startX) + Math.abs(e.screenY - @_startY)
                @_dragStarted = dist > DRAG_THRESHOLD_PIXELS
            if @_dragStarted
                @_updateGhostPosition()
                @_updateDropTarget()
                # Обновим повторно, чтобы избежать дрожания
                @_updateDropTarget() if @_dropTarget?
                @_rootBlock.updatePosition()
                @_updateAutoScroll()
        else if @_startX?
            @_svgContainer.scrollLeft = @_startScrollLeft - e.screenX + @_startX
            @_svgContainer.scrollTop = @_startScrollTop - e.screenY + @_startY

    _getScrollDelta: (coord, max) ->
        if coord > SCROLL_ZONE
            coord = max - coord
            changeSign = 1
        else
            changeSign = -1
        if coord <= MAX_SPEED_SCROLL_ZONE
            res = MAX_SCROLL_DELTA
        else if coord >= SCROLL_ZONE
            res = 0
        else
            delta = SCROLL_ZONE - MAX_SPEED_SCROLL_ZONE
            ratio = (SCROLL_ZONE - coord) / delta
            res = Math.floor(MAX_SCROLL_DELTA * ratio * ratio)
        return changeSign * res

    _updateAutoScroll: ->
        {x, y} = @_getContainerCoordinates(@_lastMoveEvent)
        @_dx = @_getScrollDelta(x, $(@_container).innerWidth())
        @_dy = @_getScrollDelta(y, $(@_container).innerHeight())
        if @_dx or @_dy
            @_setAutoscrollTimer()
        else
            @_removeAutoscrollTimer()

    _setAutoscrollTimer: ->
        return if @_autoscrollTimer?
        @_autoscrollTimer = window.setInterval(@_autoscroll, 50)

    _removeAutoscrollTimer: ->
        return if not @_autoscrollTimer?
        window.clearInterval(@_autoscrollTimer)
        @_autoscrollTimer = null

    _autoscroll: =>
        @_svgContainer.scrollLeft = window.parseInt(@_svgContainer.scrollLeft) + @_dx
        @_svgContainer.scrollTop = window.parseInt(@_svgContainer.scrollTop) + @_dy
        @_updateDropTarget()
        @_updateDropTarget() if @_dropTarget?
        @_rootBlock.updatePosition()

    _updateScrollability: =>
        @_scrollable = @_svgWidth > @_svgContainer.offsetWidth || @_svgHeight > @_svgContainer.offsetHeight
        if @_scrollable
            addClass(@_svgContainer, 'scrollable')
        else
            removeClass(@_svgContainer, 'scrollable')

    updateSize: =>
        # Обновляем размеры элемента, чтобы у пользователя была возможность его проскроллировать
        @_svgWidth = Math.floor(@_rootBlock.getTotalWidth() + 20)
        @_svgHeight = Math.floor(@_rootBlock.getTotalHeight() + 50)
        @_svg.style.width = @_svgWidth + 'px'
        @_svg.style.height = @_svgHeight + 'px'
        @_updateScrollability()

    fold: ->
        @_rootBlock?.foldAllRecursively()

    unfold: ->
        @_rootBlock?.unfoldAllRecursively()

    update: ->
        return if not @_rootBlock?
        # Обновим высоты, чтобы правильно отобразить изменения в свернутости и развернутости тредов
        @_rootBlock.invalidateIncludingChildren()
        @_rootBlock.updatePosition()

    _createGhostClipPath: ->
        clip = getElement('rect', {width: GHOST_MAX_WIDTH , height: GHOST_MAX_HEIGHT})
        clipPath = getElement('clipPath', {id: 'ghostClipPath'})
        clipPath.appendChild(clip)
        @_defs.appendChild(clipPath)

    _createGhost: ->
        @_ghostNode.setAttribute('id', 'dragNode')
        @_ghost?.parentNode.removeChild(@_ghost)
        @_ghost = getElement('use', {'clip-path': 'url(#ghostClipPath)', class: 'ghost'})
        @_ghost.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', "#dragNode")
        @_svg.appendChild(@_ghost)
        @_updateGhostPosition()

    _updateGhostPosition: ->
        {x, y} = @_getSvgCoordinates(@_lastMoveEvent)
        @_ghost.setAttribute('x', x + GHOST_X_OFFSET)
        @_ghost.setAttribute('y', y + GHOST_Y_OFFSET)
        # Поставим призрак в конец дочерних нод, чтобы он был поверх всего
        @_ghost.parentNode.appendChild(@_ghost)

    _removeGhost: ->
        @_ghostNode?.removeAttribute('id')
        return if not @_ghost?
        @_ghost.parentNode.removeChild(@_ghost)
        @_ghost = null

    isFirstRender: -> @_isFirstRender

    getMaxNodeTextLength: ->
        # Максимальное количество симоволов, отображаемых в текстовых нодах
        if @_isLongMode then LONG_MAX_NODE_TEXT_LENGTH else SHORT_MAX_NODE_TEXT_LENGTH

    getMaxThreadWidth: ->
        # Ширина треда, если количество символов в одном из параграфов больше максимального
        if @_isLongMode then LONG_MAX_THREAD_WIDTH else SHORT_MAX_THREAD_WIDTH

    setLongMode: ->
        return if @_isLongMode
        @_isLongMode = true
        @update()

    setShortMode: ->
        return if not @_isLongMode
        @_isLongMode = false
        @update()

    isDragging: -> @_startX?

    destroy: ->
        @_removeGhost()
        @_removeDropTarget()
        @_rootBlock?.destroy()
        @_deinitDrag()
        @_removeAutoscrollTimer()
        delete @_rootBlock
        delete @_svgContainer
        delete @_container


module.exports = {MindMap}