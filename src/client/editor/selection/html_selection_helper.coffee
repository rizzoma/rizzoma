DomUtils = require('../../utils/dom')
ModelType = require('../model').ModelType

isSelectionFullyInside = (selection, container) ->
    anchorNode = selection.anchorNode
    focusNode = selection.focusNode
    (anchorNode is container or DomUtils.contains(container, anchorNode)) and
            (focusNode is container or DomUtils.contains(container, focusNode))

getClosestToContainerContentEditableFalsedElement = (startNode, container) ->
    res = null
    while startNode and startNode isnt container
        if startNode.contentEditable is 'false' or startNode.getAttribute?('contentEditable') is 'false'
            res = startNode
        startNode = startNode.parentNode
    res or startNode

isNodeInEditingAllowedContainer = (node, container) ->
    closest = getClosestToContainerContentEditableFalsedElement(node, container)
    closest is container

isSelectionInEditingAllowedContainer = (selection, container) ->
    if selection.isCollapsed
        isNodeInEditingAllowedContainer(selection.anchorNode, container)
    else
        isNodeInEditingAllowedContainer(selection.anchorNode, container) or
                isNodeInEditingAllowedContainer(selection.focusNode, container)

getEditableSelectionInside = (container) ->
    sel = window.getSelection()
    if(!sel? or !isSelectionFullyInside(sel, container) or !isSelectionInEditingAllowedContainer(sel, container))
        return null
    sel

setRange = (r, directionForward = yes) ->
    sel = window.getSelection()
    return unless sel
    sel.removeAllRanges()
    if directionForward or not sel.extend?
        sel.addRange(r)
    else
        startContainer = r.startContainer
        startOffset = r.startOffset
        r.collapse(no)
        sel.addRange(r)
        sel.extend(startContainer, startOffset)

getRangeObject = (startElement, startElementType, startOffset, endElement, endElementType, endOffset) ->
        getThread = (element) ->
            element = element.parentNode until element.rzBlipThread
            element.rzBlipThread
        range = document.createRange()
        if startElementType is ModelType.BLIP
            startElement = getThread(startElement).getContainer()
        if endElementType is ModelType.BLIP
            endElement = getThread(endElement).getContainer()
        if startElementType is ModelType.TEXT
            range.setStart(startElement.firstChild, startOffset)
        else if not startOffset
            range.setStartBefore(startElement)
        else if startElementType is ModelType.LINE
            range.setStart(startElement, 0)
        else
            range.setStartAfter(startElement)

        if endElementType is ModelType.TEXT
            range.setEnd(endElement.firstChild, endOffset)
        else if not endOffset
            range.setEndBefore(endElement)
        else if endElementType is ModelType.LINE
            range.setEnd(endElement, 0)
        else
            range.setEndAfter(endElement)
        range

wrapRangeOnSingleItem = (range, node, index) ->
    range.setStart(node, index)
    range.setEnd(node, index + 1)

collapseRangeByXRelationToRect = (node, range, x, rect) ->
    collapseToStart = (rect.right - rect.left) / 2 + rect.left > x
    collapseOutside = not node.contentEditable? || node.contentEditable is 'false'
    if collapseToStart
        return range.collapse(yes) if collapseOutside
        offset = 0
    else
        return range.collapse(no) if collapseOutside
        offset = if node.length? then node.length else node.childNodes?.length || 0
    range.setStart(node, offset)
    range.setEnd(node, offset)

getRangeFromNodeSelectionByX = (node, x) ->
    r = document.createRange()
    r.selectNode(node)
    collapseRangeByXRelationToRect(node, r, x, r.getBoundingClientRect())
    r

getRangeFromTextNode = (x, y, textNode) ->
    index = 0
    length = textNode.length
    r = document.createRange()
    wrapRangeOnSingleItem(r, textNode, index)
    while (rect = r.getBoundingClientRect()) and rect.bottom < y and index < length - 1
        index += 1
        wrapRangeOnSingleItem(r, textNode, index)
    bottom = rect.bottom
    while (rect = r.getBoundingClientRect()) and bottom is rect.bottom and rect.right < x and index < length - 1
        index += 1
        wrapRangeOnSingleItem(r, textNode, index)
    if bottom isnt rect.bottom and index
        index -= 1
        wrapRangeOnSingleItem(r, textNode, index)
        rect = r.getBoundingClientRect()
    collapseRangeByXRelationToRect(textNode, r, x, rect)
    r

getDeepestRangeInside = (x, y, node, container) ->
    return getRangeFromTextNode(x, y, node) if DomUtils.isTextNode(node)
    return getRangeFromNodeSelectionByX(node, x) if node isnt container and node.contentEditable is 'false'
    child = node.firstChild
    range = document.createRange()
    while child
        range.selectNode(child)
        rect = range.getBoundingClientRect()
        if y <= rect.bottom and x <= rect.right
            # if we iterate from the first child to the last one we can be sure that we found
            # correct node if point is located to the left/above of the bottom-right corner of the rect
            return getDeepestRangeInside(x, y, child, container) || collapseRangeByXRelationToRect(child, range)
        child = child.nextSibling
    null

class SelectionHelper
    @clearSelection: ->
        window.getSelection()?.removeAllRanges()

    @getRange: ->
        s = window.getSelection()
        return null if not s or not s.rangeCount
        s.getRangeAt(0)

    @setRange: (args...) ->
        setRange(args...)

    @setCaret: (container, offset) ->
        r = document.createRange()
        r.setStart(container, offset)
        r.setEnd(container, offset)
        setRange(r)

    @getRangeInside: (container) ->
        selection = getEditableSelectionInside(container)
        return null if not selection or not selection.rangeCount
        selection.getRangeAt(0)

    @getRangeFromPoint: (x, y, container) ->
        pointElement = document.elementFromPoint(x, y)
        closest = getClosestToContainerContentEditableFalsedElement(pointElement, container)
        if closest and closest isnt container
            return getRangeFromNodeSelectionByX(closest, x)
        getDeepestRangeInside(x, y, pointElement, container) || getRangeFromNodeSelectionByX(pointElement, x)

    @getRangeObject: (args...) ->
        getRangeObject(args...)

    @setRangeObject: (startElement, startElementType, startOffset, endElement, endElementType, endOffset) ->
        range = getRangeObject(startElement, startElementType, startOffset, endElement, endElementType, endOffset)
        setRange(range)

    @selectNodeContents: (node) ->
        r = document.createRange()
        r.selectNodeContents(node)
        setRange(r)

module.exports = SelectionHelper