renderLinkPopup = require('./template').renderLinkPopup
BE = require('../../utils/browser_events')
DomUtils = require('../../utils/dom')
History = require('../../utils/history_navigation')

class LinkPopup
    MAX_OFFSET = 50

    constructor: (args...) ->
        $tmpNode = $(document.createElement 'span')
        $tmpNode.append renderLinkPopup()
        @_anchor = $tmpNode.find('.js-link-anchor')[0]
        @_anchorText = $(@_anchor).find('.js-link-text')
        @_changeButton = $tmpNode.find('.js-link-popup-change')[0]
        @_anchorImg = $tmpNode.find('.js-link-img')
        @_changeButton.addEventListener 'click', (e) =>
            e.stopPropagation()
            @_changeCallback() if @_changeCallback
            @hide()
        , false
        @_container = $tmpNode[0].firstChild
        BE.addBlocker(@_container, BE.MOUSE_DOWN_EVENT)
        BE.addBlocker(@_container, BE.MOUSE_UP_EVENT)

    _setText: (text) ->
        @_anchorText.empty().text(text)

    _setUrl: (url, originalUrl) ->
        @_anchor.href = url
        @_anchor.hrefOriginal = originalUrl

    _setExternal: () ->
        @_anchor.target = '_blank'
        @_anchorImg.removeClass('internal')
        @_anchorImg.addClass('external')

    _setInternal: () ->
        @_anchor.removeAttribute('target')
        @_anchorImg.removeClass('external')
        @_anchorImg.addClass('internal')

    getContainer: -> @_container

    hide: ->
        @_container.style.display = 'none'
        @_changeCallback = null
        @_lastTop = null
        @_lastLeft = null

    show: (url, rect, @_changeCallback, showAtBottom) ->
        @_setText(url)
        originalUrl = url
        urlParams = History.getUrlParams(url)
        if urlParams.host and urlParams.waveId
            @_setInternal()
            originalUrl = url
            res = url.split(window.HOST)
            url = res[1] if res.length > 1
        else
            @_setExternal()
        @_setUrl(url, originalUrl)
        top = rect.top
        left = rect.left
        @_container.style.display = 'block'
        containerWidth = @_container.offsetWidth
        containerHeight = @_container.offsetHeight
        parent = @_container.parentNode
        parentWidth = parent.offsetWidth
        parentHeight = parent.offsetHeight
        posTop = top + rect.bottom - rect.top + 4
        if left + containerWidth > parentWidth
            left = parentWidth - containerWidth
        if not showAtBottom and (posTop + containerHeight > parentHeight)
            posTop = top - containerHeight - 4
        if posTop != @_lastTop or Math.abs(left - @_lastLeft) > MAX_OFFSET
            @_lastTop = posTop
            @_lastLeft = left
            @_container.style.top = posTop + 'px'
            @_container.style.left = left + 'px'

    @get: -> @instance ?= new @

exports.LinkPopup = LinkPopup