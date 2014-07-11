History = require('../../utils/history_navigation')
{UNKNOWN_ICON_SRC} = require('../../user/models')
getUserInitials = require('../../../share/user/utils').getUserInitials
BaseSearchPanel = require('../base').BaseSearchPanel
{formatDate, formatAsShortDate, formatAsShortTime, formatFullDate} = require('../../../share/utils/datetime')
{convertDate, convertDatetime, convertDateTimeToServer, convertCalendricalDate} = require('../../../share/utils/date_converter')
{NOT_PERFORMED_TASK, PERFORMED_TASK} = require('./constants')
{compareTasks} = require('./common')
renderer = require('./template')
renderNoResults = require('../template').renderEmptyResult

TASK_TYPES = [
    {method: 'searchByRecipient', text: 'Inbox', trackLabel: 'inbox'}
    {method: 'searchBySender', text: 'Outbox', trackLabel: 'outbox'}
]

hasDeadline = (task) ->
    task.deadline?.date? or task.deadline?.datetime?

filterByDate = (date, task) ->
    return false if not hasDeadline(task)
    if task.deadline.datetime?
        return date <= convertDatetime(task.deadline.datetime) < new Date(date).addDays(1)
    date.toYMD() is task.deadline.date

setTaskRenderedTimes = (task, today = false) ->
    return if not task.deadline?
    {datetime, date} = task.deadline
    if datetime?
        dateObj = convertDatetime(datetime)
        if today
            task.overdue = dateObj.getTime() < today.now
            task.today = dateObj.getTime() >= today.beginDate.getTime() and dateObj.getTime() < today.endDate.getTime()
        todayDate = formatAsShortDate(Date.today())
        date = formatAsShortDate(dateObj)
        if todayDate is date
            delete task.strDeadlineDate
        else
            task.strDeadlineDate = date
        task.strDeadlineTime = formatAsShortTime(dateObj)
        task.fullStrDeadline = formatDate(datetime, true)
    else if date?
        dateObj = convertDate(date)
        if today
            task.overdue = dateObj.getTime() < today.beginDate.getTime()
            task.today = dateObj.getTime() == today.beginDate.getTime()
        task.fullStrDeadline = formatFullDate(dateObj)
        task.strDeadlineDate = formatAsShortDate(dateObj)

renderTaskList = (incompleteTasks, completedTasks) ->
    now = new Date()
    today = {now: now.getTime(), beginDate: new Date(now.getFullYear(), now.getMonth(), now.getDate()), endDate: new Date(now.getFullYear(), now.getMonth(), now.getDate()+1)}
    setTaskRenderedTimes(task, today) for task in incompleteTasks
    setTaskRenderedTimes(task) for task in completedTasks
    renderer.renderResults({completedTasks, incompleteTasks, prefix: History.getPrefix()})

class TasksPanel extends BaseSearchPanel
    __init: () ->
        $(@getContainer()).append(renderer.renderHeader({taskTypes: TASK_TYPES}))
        @_searchInput = $('#js-task-list-query')[0]
        @_searchButton = $('#js-run-task-list')[0]
        @_resultsContainer = $(@getContainer()).find('.js-task-list-results')[0]
        refreshParams = {
            isVisible: false
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: window.uiConf.search.refreshInterval.hidden
            unvisibleBrowserTabUpdateInterval: null
        }
        @_taskProcessor = require('./processor').instance
        @_taskFilter = $(@getContainer()).find('.js-task-filter')[0]
        $(@_taskFilter).selectBox().change(@_taskFilterChangeHandler)
        @_initTimeFilter()
        @_initCompletedTasksToggler()
        super(@_taskProcessor, @_resultsContainer, @_searchInput, @_searchButton, refreshParams)

    __linkClickHandler: (event) =>
        _gaq.push(['_trackEvent', 'Navigation', 'Tasks list click'])
        super(event)

    _initCompletedTasksToggler: ->
        $(@getContainer()).on 'click', '.js-completed-tasks-header', =>
            if $(@_resultsContainer).hasClass('completed-hidden')
                _gaq.push(['_trackEvent', 'Task', 'See completed tasks'])
            $(@_resultsContainer).toggleClass('completed-hidden')

    _setSelectBoxQuantity: (filterClass, q) =>
        $(@getContainer()).find(".js-close-date.selectBox-dropdown #{filterClass} .js-task-filter-quantity").text(q)
        $("ul.js-close-date-selectBox-dropdown-menu #{filterClass} .js-task-filter-quantity").text(q)

    _initTimeFilter: ->
        @_timeFilterShortcut = $(@getContainer()).find('.js-close-date')[0]
        #TODO разобраться с событием close
        $(@_timeFilterShortcut).selectBox().on('close', @_taskTimeFilterShortcutChangeHandler)
        $(@getContainer()).find('.selectBox, .selectBox-label').width('auto')
        @_initSelectBoxQuantities()
        setSelectBoxQuantity = @_setSelectBoxQuantity
        @_timeFilters =
            '.js-all-tasks':
                filter: -> true
                buttonClass: '.js-close-date'
                setQuantity: (q) -> setSelectBoxQuantity('.js-all-tasks', q)
                trackLabel: 'all'
            '.js-yesterday-tasks':
                filter: (task) -> filterByDate(Date.yesterday(), task)
                buttonClass: '.js-close-date'
                setQuantity: (q) -> setSelectBoxQuantity('.js-yesterday-tasks', q)
                trackLabel: 'yesterday'
            '.js-today-tasks':
                filter: (task) -> filterByDate(Date.today(), task)
                buttonClass: '.js-close-date'
                setQuantity: (q) -> setSelectBoxQuantity('.js-today-tasks', q)
                trackLabel: 'today'
            '.js-tomorrow-tasks':
                filter: (task) -> filterByDate(Date.tomorrow(), task)
                buttonClass: '.js-close-date'
                setQuantity: (q) -> setSelectBoxQuantity('.js-tomorrow-tasks', q)
                trackLabel: 'tomorrow'
            '.js-no-date-tasks':
                filter: (task) -> !hasDeadline(task)
                buttonClass: '.js-no-date-tasks'
                setQuantity: (q) ->
                    @button.find('.js-task-filter-quantity').text(q)
                trackLabel: 'no date'
            '.js-with-date-tasks':
                filter: (task) -> hasDeadline(task)
                buttonClass: '.js-with-date-tasks'
                setQuantity: (q) ->
                    @button.find('.js-task-filter-quantity').text(q)
                trackLabel: 'with date'

        for searchClass, filterInfo of @_timeFilters
            filterInfo.button = $(@getContainer()).find(filterInfo.buttonClass)
        @_timeFilters['.js-no-date-tasks'].button.click =>
            @_setTimeFilter('.js-no-date-tasks')
        @_initDateFilter()
        @_setTimeFilter('.js-all-tasks', false)

    _initSelectBoxQuantities: ->
        $('ul.js-close-date-selectBox-dropdown-menu li a')
            .append('<span class="js-task-filter-quantity task-filter-quantity"></span>')
        @_appendCloseDateFilterQuantity()

    _initDateFilter: ->
        filter = @_timeFilters['.js-with-date-tasks']
        filter.input = $('.js-tasks-with-date-filter-input')[0]
        $(filter.input).calendricalDate({positionInBody: true}).change =>
            date = $(filter.input).val()
            date = convertCalendricalDate(date)
            filter.filter = (task) -> filterByDate(date, task)
            $(@getContainer()).find('.js-tasks-with-date-filter-label').text(formatAsShortDate(date))
            $(@getContainer()).find('.js-with-date-tasks').addClass('has-date')
            @_setTimeFilter('.js-with-date-tasks')
        filter.button.click(@_activateDateFilterTask)

    _appendCloseDateFilterQuantity: ->
        label = $(@getContainer()).find('.js-close-date.selectBox-dropdown .selectBox-label')
        return if label.find('.js-task-filter-quantity').length > 0
        label.append('<span class="js-task-filter-quantity task-filter-quantity"></span>')

    _activateDateFilterTask: =>
        $(@_timeFilters['.js-with-date-tasks'].input).focus()
        # При focus'е input выделяется полностью
        window.getSelection().collapse()

    _taskTimeFilterShortcutChangeHandler: =>
        @_setTimeFilter($(@_timeFilterShortcut).val())
        window.setTimeout =>
            @_appendCloseDateFilterQuantity()
            @_updateFilterQuantities()
        ,0

    _setTimeFilter: (className, track=true) ->
        curFilter = @_timeFilters[className]
        neededButtonClass = curFilter.buttonClass
        for filterClassName, info of @_timeFilters
            if info.buttonClass is neededButtonClass
                info.button.addClass('active')
            else
                info.button.removeClass('active')
        @_timeFilter = curFilter.filter
        @__renderResponse() if @__lastSearchResults?
        if track
            label = "#{curFilter.trackLabel} #{@_getCurrentTypeFilter().trackLabel}"
            _gaq.push(['_trackEvent', 'Task', 'Filter', label])

    _updateFilterQuantities: ->
        for filterClass, info of @_timeFilters
            quantity = @_getIncompleteResultsCountByFilter(info.filter)
            info.setQuantity(quantity)

    _getIncompleteResultsCountByFilter: (filter) ->
        @_filterResultsBy(filter)[0].length

    _filterResultsBy: (filter) ->
        return [[], []] if not @__lastSearchResults
        completedTasks = []
        incompleteTasks = []
        for _, task of @__lastSearchResults when filter(task)
            if task.status is PERFORMED_TASK
                completedTasks.push(task)
            else
                incompleteTasks.push(task)
        return [incompleteTasks, completedTasks]

    _getCurrentTypeFilter: ->
        filterIndex = $(@_taskFilter).val() || 1
        filterIndex -= 1 # см. комментарий в рендеринге
        return TASK_TYPES[filterIndex]

    _updateTodayTasksInTab: (count) ->
        tab = $('.js-tasks')
        return tab.removeClass('has-unread') if count <= 0
        counter = $('.js-unread-tasks-count')
        text = if count > 99 then '99+' else count
        counter.text(text)
        tab.addClass('has-unread')

    _getId: (waveId, blipId) -> "task-#{waveId}-#{blipId}"

    __renderResponse: (scrollIntoView) ->
        @_updateFilterQuantities()
        container = $(@_resultsContainer)
        container.empty()
        [incompleteTasks, completedTasks] = @_filterResultsBy(@_timeFilter)
        if not incompleteTasks.length and not completedTasks.length
            return container.append(renderNoResults())
        incompleteTasks.sort(compareTasks)
        completedTasks.sort(compareTasks)
        container.append(renderTaskList(incompleteTasks, completedTasks))
        @__setActiveItem(scrollIntoView)

    _taskFilterChangeHandler: =>
        if @_getCurrentTypeFilter().method is 'searchBySender'
            _gaq.push(['_trackEvent', 'Task', 'Show outgoing tasks'])
        @__clearLastSearchResults()
        @__setStatusBarText('Synchronizing...')
        @__processSearchStart()

    __processAfterResponse: ->
        return if @_getCurrentTypeFilter().method isnt 'searchByRecipient' or @_searchInput.value isnt ''
        # Обновим количество невыполненных задач на сегодня, если запрос был подходящим
        unreadCount = $(@getContainer()).find('.js-task-list-results > .unread').length
        @_updateTodayTasksInTab(unreadCount)

    __getAdditionalParams: ->
        {status: @_getCurrentTypeFilter().status}

    __getSearchFunction: ->
        "network.task.#{@_getCurrentTypeFilter().method}"

    __parseResponseItem: (task) ->
        id = @_getId(task.waveId, task.blipId)
        return @__lastSearchResults[id] if not task.changed
        task.initials = getUserInitials(task.senderAvatar, task.senderName)
        task.senderAvatar = task.senderAvatar or UNKNOWN_ICON_SRC
        task.id = id
        return task

    __clearLastSearchResults: ->
        super()
        @_updateFilterQuantities()

    __renderError: ->
        ###
        Создает DOM-элементы для сообщения об ошибке поиска
        ###
        super()
        @_updateFilterQuantities()

    __getActiveItemId: (waveId, blipId) ->
        @_getId(waveId, blipId)

    __getPanelName: ->
        'tasks'

    __canCacheSearchResults: ->
        @_lastQueryString == '' and @_getCurrentTypeFilter().method == 'searchByRecipient'

    updateTaskIsRead: (waveId, blipId, isRead) ->
        ###
        @waveId: String
        @blipId: String
        @isRead: Boolean
        Меняет прочитанность, помечает в списке как прочитанное
        ###
        for taskId, res of @__lastSearchResults
            continue if res.waveId isnt waveId or res.blipId isnt blipId
            searchRes = res
            break
        return if not searchRes?
        return if isRead == searchRes.isRead
        searchRes.isRead = isRead
        $(@getContainer()).find("##{@_getId(waveId, blipId)}").toggleClass('unread')
        todayCount = $(@getContainer()).find('.unread').length
        @_updateTodayTasksInTab(todayCount)

    updateTaskInfo: (task) ->
        ###
        TODO если нигде не используется - снести
        ###
        filter = @_getCurrentTypeFilter()
        if filter.method is 'searchByRecipient'
            emailToCheck = task.recipientEmail
        else
            emailToCheck = task.senderEmail
        return if emailToCheck isnt window.userInfo?.email
        parsedTask = @__parseResponseItem(task)
        @__lastSearchResults[parsedTask.id] = parsedTask
        @__renderResponse(false)
        return if filter.method isnt 'searchByRecipient'
        # Обновим количество невыполненных задач на сегодня, если запрос был подходящим
        unreadCount = $(@getContainer()).find('.js-task-list-results > .unread').length
        @_updateTodayTasksInTab(unreadCount)

module.exports.TasksPanel = TasksPanel