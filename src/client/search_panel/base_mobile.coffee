PanelInt = require('./base').BaseSearchPanel
History = require('../utils/history_navigation')
MicroEvent = require('../utils/microevent')
DomUtils = require('../utils/dom')
formatDate = require('../../share/utils/datetime').formatDate

DEFAULT_AVATAR = '/s/img/user/unknown.png'
VISIBILITY_CLASS = 'shown-content-tab'
SCROLL_OFFSET = -100

class PanelBase extends PanelInt
    ###
    @interface
    ###

    ### Block unimplemented functions ###
    __getPanelName: ->
        super()

    __getAdditionalParams: ->
        super()

    __processAfterResponse: ->
        super()

    __getSearchFunction: ->
        super()

    __parseResponseItem: ->
        super()

    ### EndBlock unimplemented functions ###

    constructor: (@_id) ->
        super(document.getElementById(@_id))

    __init: (processor, refreshParams, SearchItemRendererClass) ->
        ###
        @param isVisible: boolean
        @param processor: instance /client/search_panel/base_processor.BaseSearchProcessor
        @param refreshInterval: int
        @param SearchItemRendererClass: class /client/search_panel/renderer_mobile.Renderer
        ###
        container = @getContainer()
        searchButton = container.getElementsByClassName('js-run-search-button')[0]
        searchInput = container.getElementsByClassName('js-search-query')[0]
        resultsContainer = container.getElementsByClassName('js-search-results')[0]
        @_searchItemRenderer = new SearchItemRendererClass()
        @_lastBoldedCount = 0
        @_lastActiveItemId = null
        super(processor, resultsContainer, searchInput, searchButton, refreshParams, null)

    __getInterfaceMode: -> 'mobile'

    hide: ->
        DomUtils.removeClass(@getContainer(), VISIBILITY_CLASS)
        @getTimer()?.setTabAsHidden()

    show: ->
        DomUtils.addClass(@getContainer(), VISIBILITY_CLASS)
        @getTimer()?.setTabAsVisible()

    getId: ->
        @_id

    switchActiveItem: (waveId, blipId) ->
        @__switchActiveItem(@__getItemId(waveId, blipId))

    dispatchLinkClickOnNextBolded: ->
        return if not @__lastSearchResults
        startIndex = @_getActiveItemIndex()
        @_dispatchClickOnNextBolded(startIndex)

    __switchActiveItem: (id) ->
        return unless id
        @_lastActiveItemId = id
        domItem = @__getDomItem(id)
        activeItem = @__getResultsContainer().getElementsByClassName('active')[0]
        DomUtils.removeClass(activeItem, 'active') if activeItem
        DomUtils.addClass(domItem, 'active') if domItem

    __getCommonItem: (id, title, snippet, date, dateTitle, name, avatar, isBolded, waveId, blipId) ->
        avatar ||= DEFAULT_AVATAR
        item = {id, title, snippet, date, dateTitle, name, avatar, isBolded}
        url = "#{History.getPrefix()}#{waveId}"
        url += "/#{blipId}/" if blipId
        item.url = url
        item

    __getBoldedCount: ->
        count = 0
        for id, item of @__lastSearchResults
            count += 1 if item.isBolded
        count

    __getRenderer: ->
        @_searchItemRenderer

    __processAfterResponse: ->
        count = @__getBoldedCount()
        if count isnt @_lastBoldedCount
            @_lastBoldedCount = count
            @emit('countChanged', @_lastBoldedCount)

    __renderError: ->
        ###
        @override
        ###
        @_searchItemRenderer.renderError(@__getResultsContainer())

    __renderLoading: ->
        @_searchItemRenderer.renderLoading(@__getResultsContainer())

    __renderEmptyResult: ->
        @_searchItemRenderer.renderEmptyResult(@__getResultsContainer())

    __renderItems: ->
        itemList = []
        for _, item of @__lastSearchResults
            itemList.push(item)
        itemList.sort (a, b) -> a.num - b.num
        scrollTop = document.body.scrollTop || document.documentElement.scrollTop
        @_searchItemRenderer.renderItems(@__getResultsContainer(), itemList)
        # preserve user scroll
        document.body.scrollTop = scrollTop
        document.documentElement.scrollTop = scrollTop

    __renderResponse: ->
        hasItems = no
        try
            for _ of @__lastSearchResults
                hasItems = yes
                break
        catch e
        if hasItems
            @__renderItems()
            @__switchActiveItem(@_lastActiveItemId)
        else
            @__renderEmptyResult()

    __getItemId: (waveId, blipId) ->
        id = "#{@__getPanelName()}-#{waveId}"
        id += "-#{blipId}" if blipId
        id

    __getItem: (id) ->
        @__lastSearchResults[id]

    __setItem: (id, item) ->
        @__lastSearchResults[id] = item

    __getDomItem: (id) ->
        resultsContainer = @__getResultsContainer()
        document.getElementById(id)

    scrollToActiveItem: ->
        return unless @_lastActiveItemId
        item = @__getDomItem(@_lastActiveItemId)
        return unless item
        DomUtils.scrollTargetIntoView(item, document.body, yes, SCROLL_OFFSET)

    __linkClickHandler: (event) =>
        ###
        @override
        ###
        target = event.target
        resultsContainer = @__getResultsContainer()
        while not DomUtils.isAnchorElement(target) and target isnt resultsContainer
            target = target.parentNode
        return if not DomUtils.isAnchorElement(target)
        event.preventDefault()
        event.stopPropagation()
        @emit('linkClick', target.href)

    __updateDomItemBoldState: (item, domItem) ->
        if item.isBolded
            DomUtils.addClass(domItem, 'bold')
        else
            DomUtils.removeClass(domItem, 'bold')

    _dispatchClickOnNextBolded: (startIndex) ->
        results = @__getResultsContainer().children
        _this = @

        emitLinkClickOnBoldedItem = (index) ->
            item = results[index]
            if DomUtils.hasClass(item, 'bold')
                _this.emit('linkClick', item.href)
                return yes
            no
        for index in [startIndex..results.length-1]
            return if emitLinkClickOnBoldedItem(index)
        for index in [0...startIndex]
            return if emitLinkClickOnBoldedItem(index)

    _getActiveItemIndex: ->
        activeItem = @__getDomItem(@_lastActiveItemId)
        return 0 if not activeItem
        for item, index in @__getResultsContainer().children
            return index if item is activeItem
        0


class TopicsPanelBase extends PanelBase
    ONE_UNREAD = 5
    ALL_UNREAD = 100

    updateTopicsUnreadCount: (waveId, unreadCount, totalCount) =>
        ###
        Обновляет количество непрочитанных сообщений волны в результатах поиска
        @param waveId: string
        @param unreadCount: int
        @param totalCount: int
        ###
        id = @__getItemId(waveId)
        item = @__getItem(id)
        return unless item
        @_setItemUnreadLength(item, unreadCount, totalCount)
        @_setDomItemUnreadLength(item)
        @__processAfterResponse()

    __getUnreadLen: (unreadCount, totalBlips) =>
        return ONE_UNREAD if unreadCount == 1
        return ALL_UNREAD if unreadCount == totalBlips
        return 0 if unreadCount == 0
        a_dividend = Math.pow(ONE_UNREAD,2) - Math.pow(ALL_UNREAD,2)
        a = Math.sqrt(a_dividend/(1 - totalBlips))
        b_dividend = Math.pow(ALL_UNREAD,2) - Math.pow(ONE_UNREAD,2)*totalBlips
        b = b_dividend/(Math.pow(ONE_UNREAD,2) - Math.pow(ALL_UNREAD,2))
        a*Math.sqrt(unreadCount + b)

    __parseResponseItem: (item) ->
        id = @__getItemId(item.waveId)
        return @__getItem(id) if not item.changed
        parsedItem = @__getCommonItem(id, item.title, item.snippet, formatDate(item.changeDate),
                formatDate(item.changeDate, true), item.name, item.avatar, !!item.totalUnreadBlipCount, item.waveId)
        @_setItemUnreadLength(parsedItem, item.totalUnreadBlipCount, item.totalBlipCount)

    _setItemUnreadLength: (item, unreadCount, totalCount) ->
        item.unreadLength = @__getUnreadLen(unreadCount, totalCount)
        item.isBolded = !!item.unreadLength
        item

    _setDomItemUnreadLength: (item) ->
        domItem = @__getDomItem(item.id)
        indicator = domItem.getElementsByClassName('js-unread-blips-indicator')[0]
        indicator.style.height = "#{item.unreadLength}%"
        @__updateDomItemBoldState(item, domItem)

class BlipSearchPanel extends PanelBase
    updateBoldState: (waveId, blipId, isBolded) ->
        id = @__getItemId(waveId, blipId)
        item = @__getItem(id)
        return unless item
        return if item.isBolded is isBolded
        item.isBolded = isBolded
        @__updateDomItemBoldState(item, @__getDomItem(item.id))
        @__processAfterResponse()

MicroEvent.mixin(PanelBase)
exports.PanelBase = PanelBase
exports.TopicsPanelBase = TopicsPanelBase
exports.BlipSearchPanel = BlipSearchPanel
