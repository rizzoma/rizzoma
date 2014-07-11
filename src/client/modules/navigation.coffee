BaseModule = require('../../share/base_module').BaseModule
NavigationPanel = require('../navigation').NavigationPanel
History = require('../utils/history_navigation')
{LocalStorage, BLIP_READ_STATE} = require('../utils/localStorage')
{WAVE_SHARED_STATE_PUBLIC} = require('../wave/model')
{Request} = require('../../share/communication')

class Navigation extends BaseModule

    constructor: (args...) ->
        super args...
        @_panelContainer = $('#navigation-panel')[0]
        @_panel = require('../navigation').instance = new NavigationPanel @_panelContainer
        @_panel.on('tab-show', @_processTabShow)
        @_$globalNextUnread = $('#global-next-unread')
        @_$globalNextUnread.on 'mousedown', =>
            _gaq.push(['_trackEvent', 'Topic content', 'Next unread click', 'Next unread through topic'])
        @_panel.getTopicsPanel().on('topicsLoaded', @_initGlobalNextUnread)
        @_panel.getTopicsPanel().on('unreadCountUpdate', @_initGlobalNextUnread)
        LocalStorage.on(BLIP_READ_STATE, @_processReadStateChange)

    _processReadStateChange: (changeInfo) =>
        {waveId, blipId, isRead, unreadBlipsCount, totalBlipsCount} = changeInfo
        @_panel.updateBlipIsRead(waveId, blipId, isRead)
        @_panel.updateTopicsUnreadCount(waveId, unreadBlipsCount, totalBlipsCount)

    _initGlobalNextUnread: () =>
        nextUnread = @_panel.getTopicsPanel().findNextUnreadTopic()
        if nextUnread
            @_$globalNextUnread.on 'mousedown.globalNextUnread', =>
                @_disableGlobalNextUnreadButton()
                History.navigateTo(History.parseUrlParams(nextUnread.href).waveId)
                @_panel.getTopicsPanel().setActiveItem(true)
                @_$globalNextUnread.hide()
            @_enableGlobalNextUnreadButton()
        else
            @_disableGlobalNextUnreadButton()

    _disableGlobalNextUnreadButton: ->
        @_$globalNextUnread.addClass('disabled')
        @_$globalNextUnread.attr('disabled', 'disabled')

    _enableGlobalNextUnreadButton: ->
        @_$globalNextUnread.removeClass('disabled')
        @_$globalNextUnread.removeAttr('disabled')

    updateTagList: (request) ->
        @_panel.getTopicsPanel().updateTagList(request.args.tags)

    updateTaskInfo: (request) ->
        @_panel.getTasksPanel()?.updateTaskInfo(request.args.taskInfo)
        
    loadTopicList: (request) ->
        topics = @_panel.getTopicsPanel().getLastSearchResults()
        request.callback(null, topics)

    findTopicListByTagText: (request) ->
        if request.args.sharedState is WAVE_SHARED_STATE_PUBLIC
            @_panel.showPublicTopicPanel()
            @_panel.getPublicTopicsPanel().findTopicListByText(request.args.text)
        else
            @_panel.showTopicPanel()
            @_panel.getTopicsPanel().findTopicListByText(request.args.text)

    addCollection: (request) ->
        @_panel.addCollection(request.args.container)

    _processTabShow: (tabClass) =>
        return if tabClass isnt '.js-collection'
        @_rootRouter.handle('collection.load', new Request())


module.exports.Navigation = Navigation
