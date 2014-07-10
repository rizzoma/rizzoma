History = require('../utils/history_navigation')
{renderNavigationPanel, renderTipsBox} = require('./template')
TopicsPanel = require('../search_panel/topic/panel_desktop').TopicsPanel
MentionsPanel = require('../search_panel/mention/panel_desktop').MentionsPanel
TasksPanel = require('../search_panel/task/panel_desktop').TasksPanel
PublicTopicsPanel = require('../search_panel/public_topic/panel_desktop').PublicTopicsPanel
MarketPanel = require('../market_panel').MarketPanel
TipsVideoPopup = require('../tips_video').TipsVideoPopup
BrowserSupport = require('../utils/browser_support')
Resizer = require('./resizer').Resizer
{HelpMenu} = require('./help_menu')
MicroEvent = require('../utils/microevent')

class NavigationPanel
    ###
    Навигационная панель, переключающая поиск и список сообщений
    ###

    HIDE_TIPS_COOKIE_NAME = 'hide_tips_box'

    constructor: (@_container) ->
        c = $(@_container)
        @_$tabsContainer = $('.js-tabs-container')
        c.append renderNavigationPanel({loggedIn: window.loggedIn})
        @_initTipsBox()
        @_resizer = new Resizer()
        @_resizer.on 'activateCurrentTab', @_activateCurrentTab
        @_resizer.on 'deactivateAllTabs', @_deactivateTabs
        @_topicsPanelContainer = c.find('.js-search-container')[0]
        @_topicsPanel = new TopicsPanel(@_topicsPanelContainer)
        @_tabs = {'.js-topics': {container: @_topicsPanelContainer, panel: @_topicsPanel, name: 'topics list'}}
        @_currentTabClass = '.js-topics'
        if window.loggedIn
            @_mentionsPanelContainer = c.find('.js-message-list-container')[0]
            @_mentionsPanel = new MentionsPanel(@_mentionsPanelContainer)
            @_tabs['.js-mentions'] = {container: @_mentionsPanelContainer, panel: @_mentionsPanel, name: 'mentions list'}
            @_publicTopicsPanelContainer = c.find('.js-public-search-container')[0]
            @_publicTopicsPanel = new PublicTopicsPanel(@_publicTopicsPanelContainer)
            @_tabs['.js-publics'] = {container: @_publicTopicsPanelContainer, panel: @_publicTopicsPanel, name: 'publics list'}
            @_marketPanelContainer = c.find('.js-market-panel-container')[0]
            require('../market_panel').instance = new MarketPanel(@_marketPanelContainer)
            @_marketPanel = require('../market_panel').instance
            @_tabs['.js-market'] = {container: @_marketPanelContainer, panel: @_marketPanel, name: 'store list'}

            @_$tabsContainer.find('.js-tasks, .js-collection').click(@_showAccountWizard).prop('title', 'Business and Enterprise accounts only. Click for details')

            accountProcessor = require('../account_setup_wizard/processor').instance
            accountProcessor.on('team-debt-change', @_onTeamDebtChange)
            if accountProcessor.isBusinessUser()
                @_initTasksPanel(yes)
            else
                accountProcessor.on('is-business-change', @_initTasksPanel)
            @_initEvents()
            @_initHelpMenu()
            @_resizer.foldNavPanel() if History.isGDrive()

    _showAccountWizard: ->
        if $(@).hasClass('debt')
            url = '/settings/teams-menu/'
        else
            url = '/settings/account-menu/'
        window.open(url, '_blank')

    addCollection: (container) ->
        tab = @_$tabsContainer.find('.js-collection')
        tab.removeClass('locked')
        tab.off("click", @_showAccountWizard)
        tab.prop('title', '')
        tab.click => @_showTab('.js-collection')
        $(container).addClass('search').hide()
        $(@_container).find('.js-lists-container').append(container)
        @_tabs['.js-collection'] = {container, name: 'collection'}

    _initTasksPanel: (isBusiness) =>
        return if not isBusiness
        require('../account_setup_wizard/processor').instance.removeListener('is-business-change', @_initTasksPanel)
        tab = @_$tabsContainer.find('.js-tasks')
        tab.removeClass('locked')
        tab.off("click", @_showAccountWizard)
        tab.prop('title', '')
        tab.click => @_showTab('.js-tasks')
        @_tasksPanelContainer = $(@_container).find('.js-task-list-container')[0]
        @_tasksPanel = new TasksPanel(@_tasksPanelContainer)
        @_tabs['.js-tasks'] = {container:@_tasksPanelContainer, panel: @_tasksPanel, name: 'tasks list'}

    _onTeamDebtChange: (value) =>
        teamTab = @_$tabsContainer.find('.js-collection')
        tasksTab = @_$tabsContainer.find('.js-tasks')
        if value
            teamTab.addClass('debt')
            tasksTab.addClass('debt')
            $('#navigation-panel').addClass('debt')
        else
            teamTab.removeClass('debt')
            tasksTab.removeClass('debt')
            $('#navigation-panel').removeClass('debt')

    _initTipsBox: ->
        $panelContainer = $(@_container)
        $panelContainer.append(renderTipsBox({isDesktopChrome: BrowserSupport.isDesktopChrome()}))
        toggleTips = ->
            $panelContainer.toggleClass('tips-hidden')
            expires = if $panelContainer.hasClass('tips-hidden') then 200 else -1
            $.cookie(HIDE_TIPS_COOKIE_NAME, true, {path: '/', expires})
        $('.js-tips-box .js-tips-toggle').bind('click', toggleTips)
        toggleTips() if $.cookie(HIDE_TIPS_COOKIE_NAME)
        $('.js-tips-box .js-play-pict').on 'click', (e) =>
            source = if e.target.nodeName == 'DIV' then  'Image' else 'Button'
            _gaq.push(['_trackEvent', 'Tips block', 'Play tips video', source])
            new TipsVideoPopup

    _initEvents: ->
        for searchClass of @_tabs
            @_$tabsContainer.find(searchClass).click do(searchClass) =>=> @_showTab(searchClass)
            
    _initHelpMenu: ->
        menu = new HelpMenu()
        menu.render(@_$tabsContainer.find('.js-help')[0])

    updateBlipIsRead: (waveId, blipId, isRead) =>
        ###
        Обновление непрочитанных сообщений и задач
        ###
        @_mentionsPanel?.updateMessageIsRead(waveId, blipId, isRead)
        @_tasksPanel?.updateTaskIsRead(waveId, blipId, isRead)

    updateTopicsUnreadCount: (waveId, unreadCount, totalCount) =>
        ###
        Обновление непрочитанных топиков
        ###
        @_topicsPanel?.updateTopicsUnreadCount(waveId, unreadCount, totalCount)
        @_publicTopicsPanel?.updateTopicsUnreadCount(waveId, unreadCount, totalCount)

    _deactivateTabs: (excludingTabClass=null) =>
        for searchClass, tab of @_tabs
            continue if excludingTabClass and searchClass == excludingTabClass
            t = @_$tabsContainer.find(searchClass)
            if t.hasClass('active') and not excludingTabClass?
                _gaq.push(['_trackEvent', 'Navigation', 'Hide list', tab.name])
            t.removeClass('active')
            tab.panel?.getTimer()?.setTabAsHidden()
            $(tab.container).hide()

    _activateCurrentTab: =>
        @_$tabsContainer.find(@_currentTabClass).addClass('active')
        tab = @_tabs[@_currentTabClass]
        $(tab.container).show()
        tab.panel?.getTimer()?.setTabAsVisible()
        @emit('tab-show', @_currentTabClass)

    _showTab: (targetClass) ->
        for searchClass, tab of @_tabs
            if searchClass is targetClass
                tabElem = @_$tabsContainer.find(searchClass).addClass('active')
                @_currentTabClass = targetClass
                break
        if @_resizer.getLastWidth() > 0
            if $(tab.container).is(':visible')
                @_resizer.foldNavPanel()#при вызове этого метода @_resizer эмитит событие deactivateAllTabs
            else
                _gaq.push(['_trackEvent', 'Navigation', "Switch to #{tab.name}"])
                @_activateCurrentTab()
                @_deactivateTabs(targetClass)
        else
            _gaq.push(['_trackEvent', 'Navigation', "Switch to #{tab.name}"])
            @_resizer.unfoldNavPanel()#при вызове этого метода @_resizer эмитит событие activateCurrentTab

    showTopicPanel: ->
        for targetClass, val of @_tabs
            break if val.panel instanceof TopicsPanel
        return if $(val.container).is(':visible')
        @_showTab(targetClass)

    showPublicTopicPanel: ->
        for targetClass, val of @_tabs
            break if val.panel instanceof PublicTopicsPanel
        return if $(val.container).is(':visible')
        @_showTab(targetClass)

    showMarketPanel: ->
        for targetClass, val of @_tabs
            break if val.panel instanceof MarketPanel
        return if $(val.container).is(':visible')
        @_showTab(targetClass)

    getTopicsPanel: -> @_topicsPanel

    getPublicTopicsPanel: -> @_publicTopicsPanel

    getTasksPanel: -> @_tasksPanel
MicroEvent.mixin(NavigationPanel)


exports.NavigationPanel = NavigationPanel
exports.instance = null