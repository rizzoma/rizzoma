BlipSearchPanel = require('../base_mobile').BlipSearchPanel
Renderer = require('../renderer_mobile').Renderer
formatDate = require('../../../share/utils/datetime').formatDate

class MentionsPanel extends BlipSearchPanel
    __init: ->
        mentionsProcessor = require('./processor').instance

        refreshParams = {
            isVisible: false
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: window.uiConf.search.refreshInterval.hidden
            unvisibleBrowserTabUpdateInterval: null
        }
        super(mentionsProcessor, refreshParams, Renderer)

    __parseResponseItem: (item) ->
        id = @__getItemId(item.waveId, item.blipId)
        return @__getItem(id) if not item.changed
        @__getCommonItem(id, item.title, item.snippet, formatDate(item.lastSent), formatDate(item.lastSent, true),
                item.senderName || item.senderEmail, item.senderAvatar, !item.isRead, item.waveId, item.blipId)

    __getSearchFunction: ->
        'network.message.searchMessageContent'

    __getPanelName: ->
        'mentionsPanel'

exports.MentionsPanel = MentionsPanel
