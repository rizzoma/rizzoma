TopicsPanelBase = require('../base_mobile').TopicsPanelBase
Renderer = require('../renderer_mobile').TopicsRenderer

class PublicTopicsPanel extends TopicsPanelBase
    __init: ->
        publicTopicsProcessor = require('./processor').instance
        refreshParams = {
            isVisible: no
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: null
            unvisibleBrowserTabUpdateInterval: null
        }
        super(publicTopicsProcessor, refreshParams, Renderer)

    __getBoldedCount: ->
        ###
        @override
        ###
        0

    __getSearchFunction: ->
        'network.wave.searchBlipContentInPublicWaves'

    __getPanelName: ->
        'publicPanel'

exports.PublicTopicsPanel = PublicTopicsPanel
