###
Вспомогательные функции для работы с DOM
###

exports.BLOCK_TAGS =
    ADDRESS: null
    ARTICLE: null
    ASIDE: null
    BLOCKQUOTE: null
    BODY: null
    CANVAS: null
    CAPTION: null
    COL: null
    COLGROUP: null
    DD: null
    DETAILS: null
    DIV: null
    DL: null
    DT: null
    FIELDSET: null
    FIGCAPTION: null
    FIGURE: null
    FOOTER: null
    FORM: null
    H1: null
    H2: null
    H3: null
    H4: null
    H5: null
    H6: null
    HEADER: null
    HGROUP: null
    HR: null
    LEGEND: null
    LI: null
    OL: null
    OUTPUT: null
    P: null
    PRE: null
    PROGRESS: null
    SECTION: null
    TABLE: null
    TBODY: null
    TFOOT: null
    TH: null
    THEAD: null
    SUMMARY: null
    TR: null
    UL: null

exports.isElement = (node) ->
    node.nodeType is 1

exports.isTextNode = (node) ->
    node.nodeType is 3

exports.isBlockElement = (element) ->
    element.tagName of exports.BLOCK_TAGS

exports.isAnchorElement = (element) ->
    element.tagName is 'A'

exports.isButtonElement = (element) ->
    element?.tagName is 'BUTTON'

exports.isBrElement = (element) ->
    element?.tagName is 'BR'

exports.isFrameElement = (element) ->
    element?.tagName is 'FRAME' or element?.tagName is 'IFRAME'

exports.parseFromString = (str) ->
    tmpEl = document.createElement('span')
    fragment = document.createDocumentFragment()
    tmpEl.innerHTML = str
    fragment.appendChild(firstChild) while firstChild = tmpEl.firstChild
    fragment

exports.remove = remove = (element) ->
    element.parentNode?.removeChild(element)

insertNextTo = module.exports.insertNextTo = (node, nextTo) ->
    ###
    Вставляет узел после указанного
    Возвращает вставленный узел
    @param node: HTMLNode
    @param nextTo: HTMLNode
    @return: HTMLNode
    ###
    parentNode = nextTo.parentNode
    return unless parentNode
    siblingNode = nextTo?.nextSibling
    if siblingNode
        parentNode.insertBefore(node, siblingNode)
    else
        parentNode.appendChild(node)
    node

moveNodesNextTo = module.exports.moveNodesNextTo = (nodes, nextTo) ->
    ###
    Переносит указанные узлы вслед за nextTo
    @param nodes: HTMLNode
    @param nodes: [HTMLNode]
    @param nextTo: HTMLNode
    ###
    nodes = [nodes] unless nodes instanceof Array
    for node in nodes
        insertNextTo(node, nextTo)
        nextTo = node

moveChildNodesToEnd = module.exports.moveChildNodesToEnd = (toNode, fromNode) ->
    ###
    Переносит узлы из одной вершины в конец другой
    @param toNode: HTMLNode, узел-приемник
    @param fromNode: [HTMLNode], узел-источник
    ###
    childNode = fromNode.firstChild
    while childNode
        nextChild = childNode.nextSibling
        toNode.appendChild childNode
        childNode = nextChild

moveNodesToEnd = module.exports.moveNodesToEnd = (toNode, nodes) ->
    ###
    Переносит указанные узлы в конец указанной вершины
    @param toNode: HTMLNode, узел-приемник
    @param nodes: [HTMLNode], переносимые узлы
    ###
    for node in nodes
        toNode.appendChild(node)

moveNodesToStart = module.exports.moveNodesToStart = (toNode, nodes) ->
    ###
    Переносит указанные узлы в начало указанной вершины
    @param toNode: HTMLNode, узел-приемни
    @param nodes: [HTMLNode], переносимые узлы
    ###
    firstChild = toNode.firstChild
    if not firstChild
        moveNodesToEnd(toNode, nodes)
        return
    for node in nodes
        toNode.insertBefore(node, firstChild)

moveChildNodesNextTo = module.exports.moveChildNodesNextTo = (nextToNode, fromNode) ->
    ###
    Вставляет узлы из одной вершины после другой
    @param nextToNode: HTMLNode, узел, после которого вставлять
    @param fromNode: HTMLNode, узел, детей которого переносить
    ###
    while fromNode.firstChild
        curNode = fromNode.firstChild
        insertNextTo fromNode.firstChild, nextToNode
        nextToNode = curNode

moveNodesBefore = module.exports.moveNodesBefore = (nodes, beforeNode) ->
    for node in nodes
        beforeNode.parentNode.insertBefore(node, beforeNode)

getNodeAndNextSiblings = module.exports.getNodeAndNextSiblings = (node) ->
    ###
    Возвращает всех "правых" соседей ноды (nextSibling)
    @param node: HTMLNode
    @return [HTMLNode]
    ###
    res = []
    while node
      res.push(node)
      node = node.nextSibling
    return res

getDeepestLastNode = module.exports.getDeepestLastNode = (node) ->
    ###
    Возвращает самого вложенного из последних наследников указнной ноды
    Возвращает саму ноду, если у нее нет наследников
    Не заходит внутрь нод, у которых contentEditable == false
    @param node: HTMLNode
    @return: HTMLNode
    ###
    return node if node.contentEditable is 'false'
    return node if not node.lastChild
    return getDeepestLastNode node.lastChild

contains = module.exports.contains = (container, selectedNode) ->
    ###
    Возврващает true, если selectedNode содержится внутри container
    @param container: HTMLElement
    @param selectedNode: HTMLElement
    @return: boolean
    ###
    return no unless selectedNode
    return container.contains(selectedNode) unless container.compareDocumentPosition
    not not (container.compareDocumentPosition(selectedNode) & Node.DOCUMENT_POSITION_CONTAINED_BY)

getCursor = module.exports.getCursor = ->
    ###
    Возвращает текущее положение курсора
    @return: [HTMLNode, int]|null
    ###
    range = getRange()
    return null if range is null
    return [range.startContainer, range.startOffset]

setCursor = module.exports.setCursor = (cursor) ->
    ###
    Устанавливает положение курсора
    @param cursor: [HTMLNode, int]
    ###
    range = document.createRange()
    range.setStart(cursor[0], cursor[1])
    range.setEnd(cursor[0], cursor[1])
    setRange(range)

setRange = module.exports.setRange = (range, directionForward = yes) ->
    ###
    Устанавливает выбранную часть элементов
    @param range: HTMLRange
    ###
    selection = window.getSelection()
    selection.removeAllRanges()
    if directionForward or not selection.extend?
        selection.addRange(range)
    else
        r = range.cloneRange()
        startContainer = r.startContainer
        startOffset = r.startOffset
        r.collapse(no)
        selection.addRange(r)
        selection.extend(startContainer, startOffset)

getRange = module.exports.getRange = ->
    ###
    Возвращает текущую выбранную часть элементов
    Если ничего не выбрано, возвращает null
    @return HTMLRange|null
    ###
    selection = window.getSelection()
    if selection.rangeCount
        return selection.getRangeAt(0)
    else
        return null

module.exports.findAndBind = ($container, selector, event, handler) ->
    btn = $container.find(selector)
    btn.bind(event, handler)
    return btn[0]

exports.getParentOffset = getParentOffset = (node) ->
    ###
    Возвращает индекс переданной ноды в родильской ноде
    @param node: HTMLNode
    @returns: int
    ###
    offset = 0
    child = node.parentNode.firstChild
    while child isnt node
        child = child.nextSibling
        offset++
    offset

exports.convertWindowCoordsToRelative = (coord, relative) ->
    ###
    Приводит координаты объекта coord от body к элементу relative
    @param coord: Object {top: int, left: int, bottom: int, right: int}
    @param relative: HtmlElement
    ###
    offsetTop = offsetLeft = scrollTop = scrollLeft = 0
    current = relative
    while current
        scrollTop += current.scrollTop if current.scrollTop
        scrollLeft += current.scrollLeft if current.scrollLeft
        if current is relative
            style = window.getComputedStyle(relative)
            offsetTop += relative.offsetTop if relative.offsetTop
            offsetTop += topWidth  if topWidth = parseInt(style.borderTopWidth, 10)
            offsetLeft += relative.offsetLeft if relative.offsetLeft
            offsetLeft += leftWidth if leftWidth = parseInt(style.borderLeftWidth, 10)
            relative = relative.offsetParent
        current = current.parentNode
    coord.top -= offsetTop - scrollTop
    coord.bottom -= offsetTop - scrollTop
    coord.left -= offsetLeft - scrollLeft
    coord.right -= offsetLeft - scrollLeft

exports.hasClass = (el, value) ->
    return el.classList.contains(value) if el.classList
    value = ' ' + value + ' '
    className = (' ' + el.className + ' ')
    className.indexOf(value) > -1

exports.removeClass = (el, value) ->
    return el.classList.remove(value) if el.classList
    className = (' ' + el.className + ' ').replace(/[\n\t\r]/g, ' ').replace(' ' + value + ' ', ' ').trim()
    return if className is el.className
    el.className = className

exports.addClass = (el, value) ->
    return el.classList.add(value) if el.classList
    return if exports.hasClass(el, value)
    el.className = "#{el.className}  #{value}".trim()

exports.insertNodeAt = insertNodeAt = (node, parent, parentOffset) ->
    ###
    @param node: HTMLNode
    @param parent: HTMLElement
    @param parentOffset: int
    ###
    switch parentOffset
        when 0
            parent.insertBefore(node, parent.firstChild)
        when parent.childNodes.length
            parent.appendChild(node)
        else
            parent.insertBefore(node, parent.childNodes[parentOffset])

exports.getElementOffsets = getElementOffsets = (element) ->
    ###
    Возвращает смещение элемента относительно документа
    ###
    top = 0
    left = 0
    while element
        top += element.offsetTop
        left += element.offsetLeft
        element = element.offsetParent
    return {top, left}

getScrollAmount = (view, scrollableTarget, scrollToTop, offset) ->
    viewOffsets = getElementOffsets(view)
    targetOffsets = getElementOffsets(scrollableTarget)
    return viewOffsets.top - targetOffsets.top + offset

exports.scrollTargetIntoView = (view, scrollableTarget, scrollToTop, offset = 0) ->
    ###
    Скролирует элемент scrollableTarget к элементу view
    @param view: HTMLElement - целевой элемент, который скроллируем
    @param scrollableTarget: HTMLElement - скроллируемый элемент
    @param scrollToTop: boolean - NOT IMPLEMENTED(скроллирует строго к вверху) скролировать к верху или к низу целевому элементу
    @param offset: int - дополнительное смещение 
    ###
    # TODO: доделать, попытать отказаться от scrollableTarget
    scrollAmount = getScrollAmount(view, scrollableTarget, scrollToTop, offset)
    if scrollableTarget is document.body
        document.documentElement.scrollTop = scrollAmount
    scrollableTarget.scrollTop = scrollAmount

exports.scrollTargetIntoViewWithAnimation = (view, scrollableTarget, scrollToTop, offset = 0) ->
    ###
    Скролирует элемент scrollableTarget к элементу view с анимацией
    @param view: HTMLElement - целевой элемент
    @param scrollableTarget: HTMLElement - скроллируемый элемент
    @param scrollToTop: boolean - NOT IMPLEMENTED(скроллирует строго к вверху) скролировать к верху или к низу целевому элементу
    @param offset: int - дополнительное смещение
    ###
    # TODO: доделать, попытать отказаться от scrollableTarget
    scrollAmount = getScrollAmount(view, scrollableTarget, scrollToTop, offset)
    target = [scrollableTarget]
    if scrollableTarget is document.body
        target.push(document.documentElement)
    $(target).animate(scrollTop: scrollAmount, 300)

exports.empty = (element) ->
    while firstChild = element.firstChild
        element.removeChild(firstChild)
    element

exports.includeCssFile = (href) ->
    head = document.getElementsByTagName('head')[0]
    link = document.createElement('link')
    link.setAttribute('rel', 'stylesheet')
    link.setAttribute('type', 'text/css')
    link.setAttribute('href', href)
    head.appendChild(link)

IS_CSS_READY = no

exports.isCssReady = ->
    return IS_CSS_READY if IS_CSS_READY
    div = document.createElement('div')
    div.className = 'fake-element'
    document.body.appendChild(div)
    style = if window.getComputedStyle then window.getComputedStyle(div) else div.currentStyle
    display = style.display
    document.body.removeChild(div)
    IS_CSS_READY = display is 'none'
