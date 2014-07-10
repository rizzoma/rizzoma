TopicsPanelBase = require('../base_mobile').TopicsPanelBase
Renderer = require('../renderer_mobile').TopicsRenderer

class TopicsPanel extends TopicsPanelBase
    __init: ->
        processor = require('./processor').instance
        refreshParams = {
            isVisible: no
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: null
            unvisibleBrowserTabUpdateInterval: null
        }
        super(processor, refreshParams, Renderer)

    __getAdditionalParams: ->
        {ptagNames: 'FOLLOW'}

    __getSearchFunction: ->
        'network.wave.searchBlipContent'

    __getPanelName: ->
        'topic'

exports.TopicsPanel = TopicsPanel
