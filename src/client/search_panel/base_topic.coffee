BaseSearchPanel = require('./base').BaseSearchPanel
{formatDate} = require('../../share/utils/datetime')
renderer = require('./template')
getUserInitials = require('../../share/user/utils').getUserInitials


class BaseTopicsPanel extends BaseSearchPanel
    ###
    Базовый класс для панелей поиска топиков
    ###

    TOPIC_TYPES = [
        {value: 'FOLLOW', text: 'Followed', buttonText: 'Follow'},
        {value: 'UNFOLLOW', text: 'Unfollowed', buttonText: 'Unfollow'},
        {value: null, text: 'All topics'}
    ]

    _getTopicTypes: ->
        TOPIC_TYPES

    SHOW_FOLLOW_BUTTON_TIMEOUT = 500

    __init: (@_processor, @_resultsContainer, @_searchInput, @_searchButton, refreshParams, renderer) ->
        $(@getContainer()).on('click', '.js-follow', @__followButtonClickHandler)
        $(@_resultsContainer).on('mouseenter', '.js-search-result:not(.active) .js-text-content', @__mouseenterSearchListItem)
        $(@_resultsContainer).on('mouseleave', '.js-search-result', @__mouseleaveSearchListItem)
        super(@_processor, @_resultsContainer, @_searchInput, @_searchButton, refreshParams, renderer)

    __mouseenterSearchListItem: (event) =>
        @_showFollowButtonTimeout = setTimeout =>
            $(event.currentTarget).parent('.js-search-result').addClass('show-follow-button')
        , SHOW_FOLLOW_BUTTON_TIMEOUT

    __mouseleaveSearchListItem: (event) =>
        if @_showFollowButtonTimeout?
            clearTimeout(@_showFollowButtonTimeout)
            $(event.currentTarget).removeClass('show-follow-button')

    __followButtonClickHandler: (event) =>
        event.stopPropagation()
        event.preventDefault()
        topic = $(event.currentTarget).parent().parent()
        waveId = topic.attr('id').split('-')[1]
        for tt in @_getTopicTypes()
            if $(event.currentTarget).text() == tt.buttonText
                ttIndex = @_getTopicTypes().indexOf(tt)
                callback = (error) =>
                    if not error
                        if @_getTopicTypes()[2].text == @_topicsType
                            $(event.currentTarget).text(@_getTopicTypes()[1-ttIndex].buttonText)
                        else
                            topic.remove()
                    else
                        console.error 'Error while follow/unfollow: ', error
                if ttIndex == 0
                    @_processor.followTopic(waveId, callback)
                if ttIndex == 1
                    @_processor.unfollowTopic(waveId, callback)
                break

    __getFollowButtonText: (wave = null) ->
        if wave
            if wave.follow?
                followButtonText = @_getTopicTypes()[1].buttonText
            else
                followButtonText = @_getTopicTypes()[0].buttonText
            return followButtonText
        switch @_topicsType
            when @_getTopicTypes()[0].value
                return @_getTopicTypes()[1].buttonText
            when @_getTopicTypes()[1].value
                return @_getTopicTypes()[0].buttonText
            else
                return null

    __getTopicUnreadIndicatorLen: (unreadCount, totalBlips) =>
        # log(unreadCount)*100/log(totalBlips)
        ALL_UNREAD = 100
        return 0 if unreadCount is 0
        return ALL_UNREAD if totalBlips is 1
        unreadCount += 1
        totalBlips += 1
        return Math.log(unreadCount) * ALL_UNREAD / Math.log(totalBlips)

    __getActiveItemId: (waveId) ->
        @_getId(waveId)

    __parseResponseItem: (topic) ->
        id = @_getId(topic.waveId)
        return @__lastSearchResults[id] if not topic.changed
        topic.id = id
        topic.fullChangeDate = formatDate(topic.changeDate, true)
        topic.changeDate = formatDate(topic.changeDate)
        topic.unreadLineLen = @__getTopicUnreadIndicatorLen(topic.totalUnreadBlipCount, topic.totalBlipCount)
        topic.followButtonText = @__getFollowButtonText(topic if @_getTopicTypes()[2].text == @_topicsType)
        topic.initials = getUserInitials(topic.avatar, topic.name)
        return topic

    __linkClickHandler: (event) =>
        return if event.target.tagName is 'BUTTON'
        super(event)

    __updateUnreadTopicsInTitle: ->

    __getTopicTypes: -> @_getTopicTypes()

    updateTopicsUnreadCount: (waveId, unreadCount, totalCount) =>
        ###
        Обновляет количество непрочитанных сообщений волны в результатах поиска
        @param waveId: string
        @param unreadCount: int
        @param totalCount: int
        ###
        topicId = @_getId(waveId)
        return if topicId not of @__lastSearchResults
        topic = @__lastSearchResults[topicId]
        topic.totalUnreadBlipCount = unreadCount
        topic.totalBlipCount = totalCount
        topic.unreadLineLen = @__getTopicUnreadIndicatorLen(unreadCount, totalCount)
        $activeTopic = $(@getContainer()).find("##{topicId}")
        if topic.unreadLineLen > 0
            $activeTopic.find('.js-unread-blips-indicator > div').css('height', "#{topic.unreadLineLen}%")
        else
            $activeTopic.find('.js-unread-blips-indicator > div').css('height', "0")
            $activeTopic.removeClass('unread')
        @__updateUnreadTopicsInTitle()

    findTopicListByText: (text) ->
        @_searchInput.value = "##{text}"
        @__triggerQueryInputEvent()
        @__triggerSearch()


exports.BaseTopicsPanel = BaseTopicsPanel