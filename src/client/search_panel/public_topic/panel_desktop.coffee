BaseTopicsPanel = require('../base_topic').BaseTopicsPanel
{formatDate} = require('../../../share/utils/datetime')
History = require('../../utils/history_navigation')
renderer = require('./template')
BrowserEvents = require('../../utils/browser_events')

class PublicTopicsPanel extends BaseTopicsPanel
    ###
    Панель, отвечающая за работу поиска публичных топиков
    ###
    __init: () ->
        @_topicsType = 'All topics'
        $(@getContainer()).append(renderer.renderHeader())
        $container = $(@getContainer())
        @_searchInput = $container.find('#js-public-search-query')[0]
        @_searchButton = $container.find('#js-run-public-search')[0]
        @_resultsContainer = $container.find('#js-public-search-results')[0]
        refreshParams = {
            isVisible: false
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: null
            unvisibleBrowserTabUpdateInterval: null
        }
        @_$tagsBlock = $container.find('.js-tags-block')
        @_$tagsBlock.on(BrowserEvents.CLICK_EVENT, 'a', @_handleTagClick)
        super(require('./processor').instance, @_resultsContainer, @_searchInput, @_searchButton, refreshParams, renderer)

    _handleTagClick: (e) =>
        $target = $(e.target)
        $search = $('#js-public-search-query')
        console.log '1111', $search, $target, $target.data('tag')
        $search.val($target.data('tag').trim?())
        @_lastSearchDate = null
        @__triggerSearch()
        @__triggerQueryInputEvent()

    __linkClickHandler: (event) =>
        _gaq.push(['_trackEvent', 'Navigation', 'Publics list click'])
        super(event)

    _getId: (waveId) ->
        "public-#{waveId}"

    __getSearchFunction: ->
        'network.wave.searchBlipContentInPublicWaves'

    __getPanelName: ->
        'public topics'

exports.PublicTopicsPanel = PublicTopicsPanel