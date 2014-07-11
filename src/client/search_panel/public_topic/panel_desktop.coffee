BaseTopicsPanel = require('../base_topic').BaseTopicsPanel
{formatDate} = require('../../../share/utils/datetime')
History = require('../../utils/history_navigation')
renderer = require('./template')

class PublicTopicsPanel extends BaseTopicsPanel
    ###
    Панель, отвечающая за работу поиска публичных топиков
    ###
    __init: () ->
        @_topicsType = 'All topics'
        $(@getContainer()).append(renderer.renderHeader())
        @_searchInput = $(@getContainer()).find('#js-public-search-query')[0]
        @_searchButton = $(@getContainer()).find('#js-run-public-search')[0]
        @_resultsContainer = $(@getContainer()).find('#js-public-search-results')[0]
        refreshParams = {
            isVisible: false
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: null
            unvisibleBrowserTabUpdateInterval: null
        }
        super(require('./processor').instance, @_resultsContainer, @_searchInput, @_searchButton, refreshParams, renderer)

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