BaseSearchPanel = require('../base').BaseSearchPanel
{formatDate} = require('../../../share/utils/datetime')
{UNKNOWN_ICON_SRC} = require('../../user/models')
getUserInitials = require('../../../share/user/utils').getUserInitials

renderer = require('./template')
ck = window.CoffeeKup

class MentionsPanel extends BaseSearchPanel
    ###
    Панель списка сообщений
    ###

    __init: () ->
        $(@getContainer()).append(renderer.renderHeader())
        @_searchInput = $('#js-message-list-query')[0]
        @_searchButton = $('#js-run-message-list')[0]
        @_resultsContainer = $(@getContainer()).find('.js-message-list-results')[0]
        refreshParams = {
            isVisible: false
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: window.uiConf.search.refreshInterval.hidden
            unvisibleBrowserTabUpdateInterval: null
        }
        @_mentionsProcessor = require('./processor').instance
        super(@_mentionsProcessor, @_resultsContainer, @_searchInput, @_searchButton, refreshParams, renderer)

    _getUnreadCount: =>
        unreads = 0
        for id, r of @__lastSearchResults
            unreads++ if not r.isRead
        return unreads

    _setUnreadsInTab: =>
        unreadCount = @_getUnreadCount()
        tab = $('.js-mentions')
        return tab.removeClass('has-unread') if unreadCount is 0
        unreadMentionsCount = $('.js-unread-mentions-count')
        if unreadCount > 99
            unreadCountText = '99+'
        else
            unreadCountText = unreadCount
        unreadMentionsCount.text(unreadCountText)
        tab.addClass('has-unread')

    __renderResponse: (scrollIntoView) =>
        super(scrollIntoView)
        @_setUnreadsInTab()

    _getId: (waveId, blipId) ->
        "message-#{waveId}-#{blipId}"

    __parseResponseItem: (message) ->
        id = @_getId(message.waveId, message.blipId)
        return @__lastSearchResults[id] if not message.changed
        message.id = id
        message.strFullLastSent = formatDate(message.lastSent, true)
        message.strLastSent = formatDate(message.lastSent)
        message.initials = getUserInitials(message.senderAvatar, message.senderName)
        message.senderAvatar = message.senderAvatar or UNKNOWN_ICON_SRC
        return message

    __getSearchFunction: ->
        'network.message.searchMessageContent'

    __linkClickHandler: (event) =>
        _gaq.push(['_trackEvent', 'Navigation', 'Mentions list click'])
        super(event)

    __getActiveItemId: (waveId, blipId) ->
        @_getId(waveId, blipId)

    __getPanelName: ->
        'mentions'

    updateMessageIsRead: (waveId, blipId, isRead) =>
        ###
        @param waveId: String
        @param blipId: String
        @param isRead: Boolean
        Изменяет пометку прочитанности для указанного сообщения
        ###
        messageId = @_getId(waveId, blipId)
        return if messageId not of @__lastSearchResults
        message = @__lastSearchResults[messageId]
        message.isRead = isRead
        container = $(@getContainer()).find("##{messageId}")
        if isRead
            container.removeClass('unread')
        else
            container.addClass('unread')
        @_setUnreadsInTab()


exports.MentionsPanel = MentionsPanel