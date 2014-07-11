DomUtils = require('../utils/dom')
localStorage = require('../utils/localStorage').LocalStorage
History = require('../utils/history_navigation')
RootRouter = require('../modules/root_router_base').instance
{Timer} = require('./timer')
commonRenderer = require('./template')
BrowserEvents = require('../utils/browser_events')

SEARCH_TIMEOUT = 2000
SHOW_STATUSBAR_CLASS = 'show-status-bar'

class BaseSearchPanel
    constructor: (@_container) ->
        @__init()

    __init: (@_processor, @_resultsContainer, @_searchInput, @_searchButton, refreshParams, @_renderer) ->
        @_canSearch = true
        @_searchTimer = null
        @_lastSearchDate = null
        statusBar = DomUtils.parseFromString(commonRenderer.renderStatusBar())
        @_container.appendChild(statusBar)
        @_statusBar = @_container.getElementsByClassName('js-status-bar')[0]
        @_statusBarText = @_statusBar.getElementsByClassName('js-status-bar-text')[0]
        @_lastQueryString = ''
        @__lastSearchFunction = ''
        @__lastSearchResults = {}
        @__initTimer(refreshParams)
        @_searchButton.addEventListener 'click'
        , =>
            @_timer?.resetTimeout()
            @__setStatusBarText('Searching...')
            @__processSearchStart(true)
        , false
        @_searchInput.addEventListener 'keypress'
        , (e) =>
            return if e.keyCode != 13
            @_timer?.resetTimeout()
            @__setStatusBarText('Searching...')
            @__processSearchStart(true)
        , false
        @_resultsContainer.addEventListener 'click', @__linkClickHandler, false
        showStatusBar = false
        reRequestSearchResults = true
        if !window.openSearchQuery
            responseCache = localStorage.getSearchResults(@__getSearchFunction(), @__getInterfaceMode())
            if responseCache and responseCache.value
                @__lastSearchResults = responseCache.value
                @__renderResponse(true)
                if responseCache.savedTime
                    reRequestSearchResults = false if Date.now() - responseCache.savedTime < refreshParams.visibleUpdateInterval
        else
            @__setStatusBarText('Searching...')
            showStatusBar = true
        @__processSearchStart(true, !showStatusBar) if reRequestSearchResults

    __getInterfaceMode: -> 'desktop'

    __initTimer: (refreshParams) ->
        if !refreshParams or !refreshParams.isVisible? or !refreshParams.visibleUpdateInterval
            return console.warn("Variable refreshParams is wrong defined, updateTimer for #{@__getPanelName()} panel not inited")
        @_timer = new Timer(refreshParams)
        @_timer.on('intervalExpired', (scrollIntoView) =>
            @__processSearchStart(scrollIntoView, true) if RootRouter.isConnected())

    __processSearchStart: (scrollIntoView=false, autoSearch=false) =>
        @_markSearchProcess(true, autoSearch)
        clearTimeout @_searchTimer
        scrollIntoView = !!scrollIntoView
        if @_canSearch
            @_makeSearch(scrollIntoView, autoSearch)
            @_canSearch = false
        else
            @_searchTimer = setTimeout =>
                @_makeSearch(scrollIntoView, autoSearch)
            , SEARCH_TIMEOUT

    _makeSearch: (scrollIntoView, autoSearch) ->
        additionalParams = @__getAdditionalParams()
        @_lastSearchDate = null if @_lastQueryString != @_searchInput.value
        @_lastQueryString = @_searchInput.value
        lastSearchFunction = @__getSearchFunction()
        @_processor.search lastSearchFunction, @_lastQueryString, @_lastSearchDate, additionalParams, (err, response) =>
            @_markSearchProcess(false, autoSearch)
            return @__processError(err, autoSearch) if err
            @__processResponse(response, scrollIntoView)
            @__processAfterResponse()
        setTimeout =>
            @_canSearch = true
        , SEARCH_TIMEOUT

    _markSearchProcess: (isSearching, autoSearch) ->
        if isSearching
            return if autoSearch
            DomUtils.addClass(@_searchButton, 'search-icon-wait')
            DomUtils.addClass(@_statusBar, SHOW_STATUSBAR_CLASS)
        else
            return if autoSearch
            DomUtils.removeClass(@_searchButton, 'search-icon-wait')
            DomUtils.removeClass(@_statusBar, SHOW_STATUSBAR_CLASS)

    __setActiveItem: (scrollIntoView=false) ->
        ###
        Говорит выделить активный элемент поискового списка
        ###
        {waveId, serverBlipId} = History.getCurrentParams()
        lastActiveItems = @_resultsContainer.getElementsByClassName('active')
        if lastActiveItems.length > 0
            DomUtils.removeClass(lastActiveItems[0], 'active')
        activeItem = document.getElementById(@__getActiveItemId(waveId, serverBlipId))
        if activeItem?
            DomUtils.addClass(activeItem, 'active')
        activeItem.scrollIntoView() if scrollIntoView and activeItem

    __getActiveItemId: ->
        throw new Error("Method '__getActiveItemId' not implemented")

    __getAdditionalParams: ->
        {}

    __processAfterResponse: ->
        return

    __processError: (error, autoSearch) ->
        # @param err: объект ошибки
        console.error("Got server error for #{@__getPanelName()} search", error)
        return if autoSearch
        @__clearLastSearchResults()
        @__renderError()

    __parseResponse: (response) ->
        resultsById = {}
        for item, itemNum in response.searchResults
            parsedItem = @__parseResponseItem(item)
            if not parsedItem
                console.error("Invalid searchResult item in #{@__getPanelName()}, skipping item", item)
                continue
            parsedItem.num = itemNum
            resultsById[parsedItem.id] = parsedItem
        @__lastSearchResults = resultsById
        localStorage.setSearchResults(@__getSearchFunction(), @__lastSearchResults, @__getInterfaceMode()) if @__canCacheSearchResults()

    __canCacheSearchResults: ->
        @_lastQueryString == ''

    __addItem: (item, itemId, index) ->
        # добавляет пункт в объект результатов поиска
        # @param item: добавляемый объект
        # @param itemId: id объекта, получаемый из функции __getId()
        # @param index: порядковый номер объекта в поисковой выдаче, начинается с 0
        item.num = index
        for _, i of @__lastSearchResults
            if i.num >= index
                i.num += 1
        @__lastSearchResults[itemId] = item

    __removeItem: (itemId) ->
        # удаляет пункт из объекта результатов поиска
        # @param itemId: id объекта, получаемый из функции __getId()
        delete @__lastSearchResults[itemId]

    __setStatusBarText: (text) ->
        @_statusBarText.textContent = text

    __renderResponse: (scrollIntoView) =>
        DomUtils.empty(@_resultsContainer)
        itemList = @getLastSearchResults()
        if itemList.length == 0
            @__clearLastSearchResults()
            @_resultsContainer.innerHTML = commonRenderer.renderEmptyResult()
            return
        else
            result = ''
            for item in itemList
                result += @_renderer.renderResultItem({item, prefix: History.getPrefix()})
            result = DomUtils.parseFromString(result)
            @_resultsContainer.appendChild(result)
            @__setActiveItem(scrollIntoView)

    __processResponse: (response, scrollIntoView) ->
        #обрабатывает и рендерит результаты поиска
        try
            @_lastSearchDate = response.lastSearchDate
            @__parseResponse(response)
            @__renderResponse(scrollIntoView)
        catch e
            console.error("Got unexpected result for #{@__getPanelName()} search:", response, e)
            @__clearLastSearchResults()
            @__renderError()

    __clearLastSearchResults: ->
        @_lastSearchDate = null
        @__lastSearchResults = {}

    __renderError: ->
        _gaq.push(['_trackEvent', 'Error', 'Client error', 'Search error'])
        @__setStatusBarText('Awaiting Rizzoma...')
        DomUtils.addClass(@_statusBar, SHOW_STATUSBAR_CLASS)

    __getSearchFunction: ->
        #возвращает строку для вызова метода поиска. Например "network.message.searchMessageContent"
        throw new Error("Method '__getSearchFunction' not implemented")

    __parseResponseItem: ->
        #преобразует переданный объект к удобному для хранения и рендеринга виду
        throw new Error("Method '__parseResponseItem' not implemented")

    __getPanelName: ->
        #возвращает строку - имя поисковой панели, нужно для вывода ошибок
        throw new Error("Method '__getPanelName' not implemented")

    __linkClickHandler: (event) =>
        #обрабатывает клик на ссылку в списке результатов
        return if event.ctrlKey or event.metaKey or event.button
        event.preventDefault()
        target = event.target
        while not DomUtils.isAnchorElement(target) and DomUtils.contains(@_container, target)
            target = target.parentNode
        return if not DomUtils.isAnchorElement(target)
        {waveId, serverBlipId} = History.parseUrlParams(target.href)
        History.navigateTo(waveId, serverBlipId)
        @__setActiveItem()

    __getResultsContainer: ->
        @_resultsContainer

    __getProcessor: ->
        @_processor

    __getLastQueryString: ->
        @_lastQueryString

    __triggerSearch: ->
        e = BrowserEvents.createCustomEvent(BrowserEvents.CLICK_EVENT, yes, yes)
        @_searchButton.dispatchEvent(e)

    __triggerQueryInputEvent: ->
        e = BrowserEvents.createCustomEvent(BrowserEvents.INPUT_EVENT, yes, yes)
        @_searchInput.dispatchEvent(e)

    __clearSearchInput: ->
        @_searchInput.value = ''
        @__triggerSearch()
        @__triggerQueryInputEvent()

    getLastSearchResults: ->
        results = []
        for _, item of @__lastSearchResults
            results.push(item)
        results.sort (a, b) -> a.num - b.num
        return results

    getContainer: ->
        @_container

    getTimer: ->
        @_timer

    setActiveItem: (scrollIntoView=false) ->
        #выделяет активный пункт панели
        #@param scrollIntoView: boolean скроллировать ли наверх активный пункт панели
        @__setActiveItem(scrollIntoView)


exports.BaseSearchPanel = BaseSearchPanel