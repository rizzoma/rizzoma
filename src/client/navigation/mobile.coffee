History = require('../utils/history_navigation')
DomUtils = require('../utils/dom')
{TopicsPanel} = require('../search_panel/topic/panel_mobile')
{MentionsPanel} = require('../search_panel/mention/panel_mobile')
{TasksPanel} = require('../search_panel/task/panel_mobile')
{PublicTopicsPanel} = require('../search_panel/public_topic/panel_mobile')


class NavigationPanel
    ###
    Навигационная панель, переключающая поиск и список сообщений
    ###

    constructor: (@_container) ->
        throw new Error('Navigation panel should be inited once') if module.exports.instance?
        module.exports.instance = @
        if window.loggedIn
            @_initPanels()
            @_initTabs()
            @_initChangeFollow()

    _initPanels: ->
        @_topicsPanel = @_initPanel(TopicsPanel, 'tab-topics-content', @_handleTopicsCountChange)
        @_mentionsPanel = @_initPanel(MentionsPanel, 'tab-messages-content', @_handleMentionsCountChange)
        @_publicTopicsPanel = @_initPanel(PublicTopicsPanel, 'tab-public-topics-content', ->)
        @_panels = [@_topicsPanel, @_mentionsPanel, @_publicTopicsPanel]

        accountProcessor = require('../account_setup_wizard/processor').instance
        if accountProcessor.isBusinessUser()
            @_initTasksPanel(yes)
        else
            accountProcessor.on('is-business-change', @_initTasksPanel)

    _initTasksPanel: (isBusiness) =>
        return unless isBusiness
        tasksTab = document.getElementById('tab-tasks')
        $(tasksTab).parent().removeClass('hidden').parent().removeClass('hidden-tasks')
        require('../account_setup_wizard/processor').instance.removeListener('is-business-change', @_initTasksPanel)
        @_tasksPanel = @_initPanel(TasksPanel, 'tab-tasks-content', @_handleTasksCountChange)
        @_panels.push(@_tasksPanel)

    _initPanel: (classObject, id, counterFunction) ->
        panel = new classObject(id)
        panel.on('linkClick', @_handleLinkClick)
        panel.on('countChanged', counterFunction)

    _initTabs: ->
        @_activeTab = null
        tabs = document.getElementsByClassName('js-tab-selector')
        __this = @
        for tab in tabs
            tab.addEventListener 'click', ->
                __this._activateTab(@, false)
            , no
        @_activateTab(tabs[0], true)

    _trackAnalytics: (tab) ->
        if tab instanceof TopicsPanel then event = 'Switch to topics list'
        else if tab instanceof MentionsPanel then event = 'Switch to mentions list'
        else if tab instanceof TasksPanel then event = 'Switch to tasks list'
        else if tab instanceof PublicTopicsPanel then event = 'Switch to publics list'
        else event = 'Switch to unknown'
        _gaq.push(['_trackEvent', 'Navigation', event])

    _activateTab: (tabEl, firstTime) ->
        tabId = tabEl.id + '-content'
        for panel in @_panels
            if panel.getId() is tabId
                if @_activeTab is panel
                    @_activeTab.dispatchLinkClickOnNextBolded()
                    return
                @_activeTab.hide() if @_activeTab
                tabEl.checked = yes unless tabEl.checked
                (@_activeTab = panel).show()
                @_trackAnalytics(panel) if not firstTime
                break

    _initChangeFollow: ->
        activate = (waveId, blipId) =>
            return unless waveId
            @_topicsPanel.switchActiveItem(waveId)
            @_publicTopicsPanel.switchActiveItem(waveId)
            return unless blipId
            @_mentionsPanel.switchActiveItem(waveId, blipId)
            @_tasksPanel?.switchActiveItem(waveId, blipId)
        History.on 'statechange', activate
        {waveId, serverBlipId} = History.getCurrentParams()
        activate(waveId, serverBlipId)

    updateBlipIsRead: (waveId, blipId, isRead) =>
        ###
        Обновление непрочитанных сообщений и задач
        ###
        @_mentionsPanel?.updateBoldState(waveId, blipId, !isRead)
        @_tasksPanel?.updateBoldState(waveId, blipId, !isRead)
        
    updateTopicsUnreadCount: (waveId, unreadCount, totalCount) =>
        ###
        Обновление непрочитанных топиков
        ###
        @_topicsPanel?.updateTopicsUnreadCount(waveId, unreadCount, totalCount)
        @_publicTopicsPanel?.updateTopicsUnreadCount(waveId, unreadCount, totalCount)

    getTasksPanel: -> @_tasksPanel

    scrollToActiveItem: ->
        @_activeTab?.scrollToActiveItem()

    _handleLinkClick: (href) ->
        {waveId, serverBlipId} = History.parseUrlParams(href)
        History.navigateTo(waveId, serverBlipId)

    _updateCounter: (counter, count) ->
        if count <= 0
            counter.textContent = ''
        else
            text = if count > 99 then '99+' else count
            counter.textContent = text

    _handleTopicsCountChange: (count) =>
        @_updateCounter(document.getElementById('topics-counter'), count)

    _handleMentionsCountChange: (count) =>
        @_updateCounter(document.getElementById('messages-counter'), count)

    _handleTasksCountChange: (count) =>
        @_updateCounter(document.getElementById('tasks-counter'), count)

module.exports =
    NavigationPanel: NavigationPanel
    instance: null
