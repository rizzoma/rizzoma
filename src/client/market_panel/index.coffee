History = require('../utils/history_navigation')
BaseSearchPanel = require('../search_panel/base').BaseSearchPanel
DomUtils = require('../utils/dom')
renderer = require('./template')

class MarketPanel extends BaseSearchPanel

    CHANGE_ITEM_STATE_DELAY = 500
    RELOAD_LIST_INTERVAL = 3600000

    __init: ->
        @_marketProcessor = require('./processor').instance
        @_currentSearchCategory = null
        @_createContainerDom()
        @_resultsContainer.addEventListener 'click', @__linkClickHandler, false
        $buttons = $(@_container).find('.js-market-items-filter')
        $buttons.on 'click', (e) =>
            $buttons.removeClass('pressed')
            $(e.target).addClass('pressed')
            @_currentSearchCategory = parseInt($(e.target).attr('searchParam'))
            @_renderByCategory()
            @__setActiveItem(true)
        @_loadAndInitItemList()
        setInterval(@_loadAndInitItemList, RELOAD_LIST_INTERVAL)

    __linkClickHandler: (event) =>
        if $(event.target).hasClass('js-market-panel-result')
            _gaq.push(['_trackEvent', 'Store', 'Store list click', $(event.target).attr('title')])
        else
            _gaq.push(['_trackEvent', 'Store', 'Store list click', $(event.target).parents('.js-market-panel-result').attr('title')])
        super(event)

    _loadAndInitItemList: =>
        @_storeItems = []
        @_marketProcessor.getVisibleItemList (error, response) =>
            return console.error(error) if error
            for item in response
                if item.id in window.userInfo.installedStoreItems
                    item.state = 2
                else
                    item.state = 1
                item.htmlId = @_getId(item.topicUrl)
                @_storeItems.push(item)
            @_renderByCategory()
            @__setActiveItem(true)

    _renderByCategory: ->
        DomUtils.empty(@_resultsContainer)
        result = ''
        for item in @_storeItems
            continue if @_currentSearchCategory and item.category != @_currentSearchCategory
            result += renderer.renderResultItem({ item, prefix: History.getPrefix() })
        result = DomUtils.parseFromString(result)
        @_resultsContainer.appendChild(result)
        @_initSwitches() if @_currentSearchCategory != 2

    _initSwitches: ->
        $labels = $(@_container).find('.js-gadget-checkbox-label')
        $labels.on 'mousedown mouseup', (e) ->
            # превентится mousedown - чтоб не было выделения и не запускалась проверка changeRange
            # mouseup - чтоб не запускалась проверка changeRange
            e.stopPropagation()
            e.preventDefault()
        .on 'click', (e) =>
            e.preventDefault()
            e.stopPropagation()
            $checkbox = $(e.target).prev()
            gadgetId = $checkbox.attr('id')
            item = @_getItemById(gadgetId)
            if $checkbox.attr('checked') then s = 'off' else s = 'on'
            _gaq.push(['_trackEvent', 'Store', 'Switch gadget '+s, $(e.target).parents('.js-market-panel-result').attr('title')])
            @_processCheckboxClick(item, $checkbox)

    _createContainerDom: ->
        $(@_container).append(renderer.renderPanelTmpl())
        $resultsContainer = $(@_container).find('.js-market-panel-results')
        @_resultsContainer = $resultsContainer[0]

    _getId: (waveId) ->
        "market-#{waveId}"

    __getActiveItemId: (waveId, blipId) ->
        @_getId(waveId)

    _getItemById: (id) ->
        for item in @_storeItems
            return item if item.id == id

    _processCheckboxClick: (item, $checkbox) ->
        return if @_waitResponse
        @_marketProcessor.getCurrentWave((currentWave) =>
            @_waitResponse = yes
            if currentWave
                currentWaveView = currentWave.getView()
                currentWaveView.enableActiveBlipControls()
                insertGadgetPopup = currentWaveView.getInsertGadgetPopup()
                insertGadgetPopup.show(currentWaveView.getActiveBlip()) if !insertGadgetPopup.isVisible()
                startTime = Date.now()
            if item.state != 1
                $checkbox.removeAttr('checked')
                @_marketProcessor.uninstallStoreItem(item.id, (err, response) =>
                    @_waitResponse = no
                    return console.error err if err
                    item.state = 1
                    window.userInfo.installedStoreItems.splice(window.userInfo.installedStoreItems.indexOf(item.id), 1)
                    if currentWave
                        finishTime = Date.now()
                        if finishTime - startTime >= CHANGE_ITEM_STATE_DELAY
                            insertGadgetPopup.removeGadget(item)
                        else
                            setTimeout( =>
                                insertGadgetPopup.removeGadget(item)
                            , CHANGE_ITEM_STATE_DELAY - finishTime + startTime)
                )
            else
                $checkbox.attr('checked', 'checked')
                @_marketProcessor.installStoreItem(item.id, (err, response) =>
                    @_waitResponse = no
                    return console.error err if err
                    item.state = 2
                    window.userInfo.installedStoreItems.push(item.id)
                    if currentWave
                        finishTime = Date.now()
                        if finishTime - startTime >= CHANGE_ITEM_STATE_DELAY
                            insertGadgetPopup.addGadget(item)
                        else
                            setTimeout( =>
                                insertGadgetPopup.addGadget(item)
                            , CHANGE_ITEM_STATE_DELAY - finishTime + startTime)
                )
        )

    getInstalledGadgets: ->
        installedGadgets = []
        for gadget in @_storeItems
            installedGadgets.push(gadget) if gadget.state is 2
        installedGadgets

    getTimer: ->

exports.MarketPanel = MarketPanel
exports.instance = null
