###
Компонент со списком топиков-collection
###

History = require('../utils/history_navigation')
renderer = require('../search_panel/topic/template')
DomUtils = require('../utils/dom')
MicroEvent = require('../utils/microevent')
{LIST_UPDATE_INTERVAL} = require('../account_setup_wizard/processor')

renderCollectionPickerTopicListButton = window.CoffeeKup.compile ->
    button '.collection-list-button.button', 'Team list'

renderCollectionPickerTopicsWarning  = window.CoffeeKup.compile ->
    div '.collection-list-warning', ->
        span '', 'Unable to collect monthly payment. '
        a '', {href: '/settings/teams-menu/', target: '_blank'}, ->
            'Details'

renderCollectionTopic = window.CoffeeKup.compile ->
    a ".js-search-result.search-result-item", {id: @item.id, href:"/topic/#{h(@item.url)}/"}, ->
        div ".text-content", ->
            div '.wave-title', ->
                span h(@item.title)
                br '', ''
                span '.item-snippet', h(' ' + @item.snippet)
        div '.js-wave-info.wave-info', ->
            div '.js-info.info', ->
                nameTitle = @item.name || ''
                avatar = @item.avatar || '/s/img/user/unknown.png'
                div '.last-editing.avatar', {style:"background-image: url(#{h(avatar)})", title: h(nameTitle)}
                div '.last-changed', ''
        div '.clearer', ''

renderCollectionFooter = window.CoffeeKup.compile ->
    div '.collection-footer', ->
        div '', ->
            button '.new-collection-button.button', 'Create new team'


#              onclick: "window.open('/settings/teams-menu/')",


class CollectionPicker
    constructor: (@_parent) ->
        @_createDOM()
        @_waveModule = require('../modules/wave').instance
        @_initTopicCloseEvents()

    _createDOM: ->
        @_createTopicList()
        @_createTopicListButton()
        @_createTopicWarning()

    _createTopicList: ->
        @_topicListContainer = $('<div class="topic-list-container"></div>')[0]
        @_panel = new CollectionPanel(@)
        @_topicListContainer.appendChild(@_panel.getContainer())
        @_topicListIsShown = false
        @_panel.on 'topic-change', (waveId) =>
            @_hideTopicList()
            @emit('topic-change', waveId)
        @_panel.on 'topics-loaded', (searchResults) =>
            haveCollections = !!searchResults.length
            @emit('collection-inited', haveCollections)
        footer = renderCollectionFooter()
        footer = DomUtils.parseFromString(footer)
        @_topicListContainer.appendChild(footer)
        $(@_topicListContainer).find('.new-collection-button').click(=> @_newTeamHandler());

    _newTeamHandler: ->
        @_hideTopicList()
        window.open('/settings/teams-menu/new')

    _hideTopicList: ->
        $(@_topicListContainer).removeClass('visible')
        $(document.body).off('click.collection-topic-list-hide')

    _showTopicList: ->
        @_updateOpenedWavesInfo()
        $(@_topicListContainer).addClass('visible')
        @_panel.setActiveItem()
        $(document.body).on 'click.collection-topic-list-hide', (e) =>
            # Не скрываем список топиков, если клик был произведен по списку либо по кнопке
            return if $(e.target).closest($([@_topicListContainer, @_topicListButton])).length > 0
            @_hideTopicList()

    _createTopicListButton: ->
        $topicListButton = $(renderCollectionPickerTopicListButton())
        @_topicListButton = $topicListButton[0]
        $topicListButton.click =>
            if $(@_topicListContainer).hasClass('visible')
                @_hideTopicList()
            else
                @_showTopicList()

    _createTopicWarning: ->
        @_topicWarning = $(renderCollectionPickerTopicsWarning())[0]

    getTopicListButton: -> @_topicListButton

    getTopicsWarning: -> @_topicWarning

    hideTopicsWarning: ->
        $(@_topicWarning).hide()

    showTopicsWarning: ->
        $(@_topicWarning).show()

    getTopicListContainer: -> @_topicListContainer

    getFirstTopicIdInList: -> @_panel.getFirstTopicIdInList()

    hasTopicIdInList: (id) -> return @_panel.hasTopicIdInList(id)

    getActiveTopicId: ->
        @_parent.getCurrentWave()?.getServerId()

    getPanel: -> @_panel

    _updateWaveInfo: (wave) =>
        rootBlipId = wave?.getModel()?.getRootBlipId()
        return if not rootBlipId
        rootBlipModel = wave.getLoadedBlip(rootBlipId)?.getModel()
        return if not rootBlipModel
        @_panel.updateSearchResultParams(wave.getServerId(), rootBlipModel.getTitle(), rootBlipModel.getSnippet())

    _updateOpenedWavesInfo: ->
        ###
        Обновляет title и snippet из открытых топиков
        ###
        @_updateWaveInfo(@_waveModule.getCurrentWave())
        @_updateWaveInfo(@_parent.getCurrentWave())

    _initTopicCloseEvents: ->
        ###
        Следим за закрывающимися топиками, чтобы перед закрытием получить из них свежие title и snippet
        ###
        @_parent.on('wave-close', @_updateWaveInfo)
        @_waveModule.on('wave-close', @_updateWaveInfo)
MicroEvent.mixin(CollectionPicker)


class CollectionPanel
    constructor: (@_parent) ->
        @_initProcessor()
        @_createDOM()
        @_startTopicListUpdates()
        @_initVisibilityUpdate()

    getContainer: -> @_container

    _initProcessor: ->
        @_processor = require('../account_setup_wizard/processor').instance
        @_processor.on 'force-is-business-update', =>
            @_lastResultTime = 0
            @_updateTopicList()

    _createDOM: ->
        @_container = $('<div class="collection-list"></div>')[0]
        @_container.addEventListener('click', @_linkClickHandler, false)

    _startTopicListUpdates: ->
        @_loadCachedTopicList()
        if @_lastSearchResults
            @_renderTopicList()
            window.setTimeout =>
                @emit('topics-loaded', @_lastSearchResults)
            , 0
        @_updateTopicList()

    _updateTopicList: ->
        window.clearTimeout(@_updateHandler)
        nextUpdateTime = Math.max(@_lastResultTime + LIST_UPDATE_INTERVAL, Date.now())
        @_updateHandler = window.setTimeout =>
            @_loadTopicList()
            @_lastResultTime = Date.now()
            @_updateTopicList()
        , nextUpdateTime - Date.now()

    _loadCachedTopicResults: ->
        responseCache = @_processor.getCachedTeamTopics()
        return if not responseCache or not responseCache.value or not responseCache.value.topics
        @_lastSearchResults = responseCache.value.topics

    _loadCachedTopicList: ->
        responseCache = @_processor.getCachedTeamTopics()
        return if not responseCache or not responseCache.value or not responseCache.value.topics
        @_lastSearchResults = responseCache.value.topics
        @_lastResultTime = responseCache.savedTime

    _loadTopicList: ->
        @_processor.getTeamTopics (err, res) =>
            return console.warn("Got an error for collection topic list request", err) if err
            @_processTopicList(res)

    _processTopicList: (res) ->
        @_parseTopicList(res)
        @_renderTopicList()

    _getDOMTopicId: (topicId) -> "collection-topic-#{topicId}"

    _parseTopicList: (response) ->
        for item in response.topics
            item.id = @_getDOMTopicId(item.url)
        @_lastSearchResults = response.topics
        @_processor.setCachedTeamTopics(@_lastSearchResults, response.hasDebt)
        @emit('topics-loaded', @_lastSearchResults)

    _renderTopicList: ->
        DomUtils.empty(@_container)
        result = ''
        for item in @_lastSearchResults
            result += renderCollectionTopic({item})
        result = DomUtils.parseFromString(result)
        @_container.appendChild(result)
        @setActiveItem()

    _linkClickHandler: (event) =>
        #обрабатывает клик на ссылку в списке результатов
        return if event.ctrlKey or event.metaKey or event.button
        event.preventDefault()
        target = event.target
        while not DomUtils.isAnchorElement(target) and DomUtils.contains(@_container, target)
            target = target.parentNode
        return if not DomUtils.isAnchorElement(target)
        {waveId} = History.parseUrlParams(target.href)
        @emit('topic-change', waveId)

    getFirstTopicIdInList: ->
        @_lastSearchResults[0]?.url

    hasTopicIdInList: (id) ->
        return true for item in @_lastSearchResults when item.url == id

    setActiveItem: ->
        topicId = @_parent.getActiveTopicId()
        lastActiveItems = @_container.getElementsByClassName('active')
        if lastActiveItems.length > 0
            DomUtils.removeClass(lastActiveItems[0], 'active')
        activeItem = document.getElementById(@_getDOMTopicId(topicId))
        DomUtils.addClass(activeItem, 'active') if activeItem?

    updateSearchResultParams: (waveId, title, snippet) ->
        return if not @_lastSearchResults
        for item in @_lastSearchResults when item.url is waveId
            item.title = title
            item.snippet = snippet
        @_processor.setCachedTeamTopics(@_lastSearchResults)
        @_renderTopicList()

    _initVisibilityUpdate: ->
        Visibility.change (e, state) =>
            return if state isnt 'visible'
            @_loadCachedTopicResults()
            @_renderTopicList()

MicroEvent.mixin(CollectionPanel)


module.exports = {CollectionPicker}