BaseTopicsPanel = require('../base_topic').BaseTopicsPanel
MicroEvent = require('../../utils/microevent')
{formatDate} = require('../../../share/utils/datetime')
{LocalStorage, CHANGE_TOPIC_LIST} = require('../../utils/localStorage')
DomUtils = require('../../utils/dom')
History = require('../../utils/history_navigation')
BrowserEvents = require('../../utils/browser_events')
renderer = require('./template')

class TopicsPanel extends BaseTopicsPanel
    ###
    Панель, отвечающая за работу поиска топиков
    ###

    __init: () ->
        @_topicsType = 'FOLLOW'
        @_initTagRegexp()
        $container = $(@getContainer())
        $container.append(renderer.renderHeader({topicTypes: @__getTopicTypes()}) )
        @_resultsContainer = $container.find('#js-search-results')[0]
        searchButton = $container.find('#js-run-search')[0]
        searchInput = $('#js-search-query')[0]
        searchInput.addEventListener(BrowserEvents.INPUT_EVENT, @_handleQueryInputEvent, no)
        if window.openSearchQuery?
            $(searchInput).val(window.openSearchQuery)
        lbound = window.uiConf.search.refreshInterval.hiddenTab.lbound
        ubound = window.uiConf.search.refreshInterval.hiddenTab.ubound
        hiddenTabRefreshInterval = Math.floor(Math.random() * (ubound - lbound)) + lbound
        refreshParams = {
            isVisible: true
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: window.uiConf.search.refreshInterval.hidden
            unvisibleBrowserTabUpdateInterval: hiddenTabRefreshInterval
        }
        $searchMenu = $container.find('.js-search-menu')
        BrowserEvents.addBlocker($searchMenu[0], BrowserEvents.CLICK_EVENT)
        @_topicFilter = $container.find('.js-topic-filter')
#        @_topicFilter.selectBox().change(@_topicFilterChangeHandler)
        @_topicFilter.on(BrowserEvents.CLICK_EVENT, 'a', @_topicFilterChangeHandler)
        @_followButton = $container.find('.js-follow')
        @_$tagsBlock = $container.find('.js-tags-block')
        @_$tagsBlock.on(BrowserEvents.CLICK_EVENT, 'a', @_handleTagClick)
        $container.find('.js-show-search-menu').click =>
            if $searchMenu.hasClass('hidden')
                document.addEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_handleSearchMenuMouseDownEvent, yes)
                $searchMenu.removeClass('hidden')
            else
                @_hideSearchMenu()
        $container.find('.js-clear-search-query').click =>
            @__clearSearchInput()
#        LocalStorage.on(CHANGE_TOPIC_LIST, @_changeListHandler)
        super(require('./processor').instance, @_resultsContainer, searchInput, searchButton, refreshParams, renderer)

    _handleSearchMenuMouseDownEvent: (e) =>
        return if DomUtils.contains($(@getContainer()).find('.js-search-header')[0], e.target)
        @_hideSearchMenu()

    _hideSearchMenu: ->
        document.removeEventListener(BrowserEvents.MOUSE_DOWN_EVENT, @_handleSearchMenuMouseDownEvent, yes)
        $(@getContainer()).find('.js-search-menu').addClass('hidden')

    __linkClickHandler: (event) =>
        _gaq.push(['_trackEvent', 'Navigation', 'Topics list click'])
        super(event)

    _changeListHandler: (lastSearchResults) =>
        return if !@__canCacheSearchResults()
        @__lastSearchResults = lastSearchResults
        @getTimer()?.resetTimeout()
        @__renderResponse()
        @__processAfterResponse()

    _initTagRegexp: ->
        {badCharacters} = require('../../tag/constants')
        @_tagRegexp = new RegExp("#[^#{badCharacters}]")

    _highlightTags: (text) ->
        words = text.split(' ')
        @_$tagsBlock.find('[data-tag]').removeClass('active')
        for word in words
            continue if word[0] isnt '#'
            continue if @_lastTags.indexOf(word.substr(1)) is -1
            @_$tagsBlock.find("[data-tag='#{word}']").addClass('active')

    _handleTagClick: (e) =>
        $target = $(e.target)
        $search = $('#js-search-query')
        if $target.hasClass('active')
            $search.val($search.val().replace(new RegExp("#{$target.data('tag')}(\\s|$)"), '').trim?())
        else
            $search.val(($search.val() + ' ' + $target.data('tag')).trim?())
            @_hideSearchMenu()
        @_lastSearchDate = null
        @__triggerSearch()
        @__triggerQueryInputEvent()

    _handleQueryInputEvent: (e) =>
        text = e.target.value
        $searchQuery = $(@getContainer()).find('.js-clear-search-query')
        @_highlightTags(text)
        return $searchQuery.addClass('hidden') unless text
        $searchQuery.removeClass('hidden')

    _topicFilterChangeHandler: (event) =>
        $target = $(event.target)
        return if $target.hasClass('active')
        @_topicFilter.find('.active').removeClass('active')
        $target.addClass('active')
        @_topicsType = $target.data('value') || $target.data('text')
        topicTypes = @__getTopicTypes()
        $container = $(@getContainer())
        $topicFilterLabel = $container.find('.js-topic-filter-label')
        $searchHeader = $container.find('.js-search-header')
        if topicTypes[0].value is @_topicsType
            $searchHeader.removeClass('show-filter-label')
        else
            $searchHeader.addClass('show-filter-label')
            $topicFilterLabel.text($target.data('text'))
        followButtonText = @__getFollowButtonText()
        @_followButton.text(followButtonText) if followButtonText
        @_lastSearchDate = null
        @__triggerSearch()
        @_hideSearchMenu()

    _getId: (waveId) ->
        "topic-#{waveId}"

    __processSearchStart: (scrollIntoView=false, autoSearch=false) =>
        super(scrollIntoView, autoSearch)
        return if not @__getLastQueryString().match(@_tagRegexp)
        _gaq.push(['_trackEvent', 'Tag', 'Tag search'])

    __processAfterResponse: =>
        @emit('topicsLoaded')
        if @_resultsContainer.children.length >= 10 and LocalStorage.getTopicsCount() < 10
            mixpanel.track('Over 10 topics', {'count':@_resultsContainer.children.length})
            LocalStorage.setTopicsCount(@_resultsContainer.children.length)
        @__updateUnreadTopicsInTitle()

    __parseResponse: (response) ->
        super(response)
        return unless window.welcomeWaves and window.welcomeWaves.length
        for topic, topicNum in window.welcomeWaves
            continue if @__lastSearchResults[@_getId(topic.waveId)]
            topic.changeDate = Math.round(topic.changeDate/1000)
            @__addItem(@__parseResponseItem(topic), @_getId(topic.waveId), topicNum)

    __getAdditionalParams: ->
        {ptagNames: @_topicsType}

    __getSearchFunction: ->
        'network.wave.searchBlipContent'

    __getPanelName: ->
        'topics'

    __canCacheSearchResults: ->
        @_lastQueryString == '' and @_topicsType == 'FOLLOW'

    __updateUnreadTopicsInTitle: ->
        window.title.unreadTopicsCount = $(@_resultsContainer).find('.unread').length
        History.setPageTitle()

    findNextUnreadTopic: ->
        topicList = $(@_resultsContainer).find('.js-search-result')
        return if topicList.length == 0
        activeItemIndex = $(@_resultsContainer).find('.active').index()
        # под условием обработка ситуации когда нет активного топика и
        # в первом топике есть непрочитанные сообщения
        if activeItemIndex == -1
            if $(topicList[0]).find('.js-unread-blips-indicator div').height() > 0
                return topicList[0]
            activeItemIndex = 0
        i = activeItemIndex + 1
        while true
            return if i == activeItemIndex
            if $(topicList[i]).find('.js-unread-blips-indicator div').height() > 0
                return topicList[i]
            if i >= topicList.length - 1
                i = 0
            else
                i += 1

    updateTopicsUnreadCount: (args...) =>
        super(args...)
        @emit('unreadCountUpdate')

    updateTagList: (tags) ->
        return unless tags.length
        @_lastTags = tags
        $container = @_$tagsBlock.empty()
        $container.append(renderer.renderTagList(tags: tags.sort()))
        @__triggerQueryInputEvent()

MicroEvent.mixin TopicsPanel
exports.TopicsPanel = TopicsPanel
