BlipSearchPanel = require('../base_mobile').BlipSearchPanel
Renderer = require('../renderer_mobile').TasksRenderer
{formatDate, formatAsShortDate, formatAsShortTime, formatFullDate} = require('../../../share/utils/datetime')
{convertDate, convertDatetime, convertDateTimeToServer, convertCalendricalDate} = require('../../../share/utils/date_converter')
{NOT_PERFORMED_TASK, PERFORMED_TASK} = require('./constants')
{compareTasks} = require('./common')
formatDate = require('../../../share/utils/datetime').formatDate

filter: -> yes

class TasksPanel extends BlipSearchPanel
    __init: ->
        processor = require('./processor').instance

        refreshParams = {
            isVisible: false
            visibleUpdateInterval: window.uiConf.search.refreshInterval.visible
            hiddenUpdateInterval: window.uiConf.search.refreshInterval.hidden
            unvisibleBrowserTabUpdateInterval: null
        }
        super(processor, refreshParams, Renderer)

    updateTaskInfo: (task) ->
        # TODO: this method is filter dependent
        emailToCheck = task.senderEmail
        return if emailToCheck isnt window.userInfo?.email
        parsedTask = @__parseResponseItem(task)
        @__lastSearchResults[parsedTask.id] = parsedTask
        @__renderResponse()

    __parseResponseItem: (item) ->
        id = @__getItemId(item.waveId, item.blipId)
        return @__getItem(id) if not item.changed
        {itemDatetime, itemFullDatetime} = @_getDates(item)
        resultItem = @__getCommonItem(id, item.title, item.snippet, itemDatetime, itemFullDatetime,
                item.senderName || item.senderEmail, item.senderAvatar, !item.isRead, item.waveId, item.blipId)
        resultItem.status = item.status
        resultItem.deadline = item.deadline
        resultItem

    __renderItems: ->
        [incompleteTasks, completedTasks] = @_filterItems(-> yes)
        if not incompleteTasks.length and not completedTasks.length
            return @__renderEmptyResult()
        incompleteTasks.sort(compareTasks)
        completedTasks.sort(compareTasks)
        @__getRenderer().renderItems(@__getResultsContainer(), incompleteTasks, completedTasks)

    __getAdditionalParams: ->
        ###
        @override
        ###

    __getBoldedCount: ->
        count = 0
        for id, item of @__lastSearchResults
            count += 1 if item.isBolded and item.status isnt PERFORMED_TASK
        count

    __getSearchFunction: ->
        "network.task.searchByRecipient"

    __getPanelName: ->
        'tasksPanel'

    _filterItems: (filter) ->
        return [[], []] if not @__lastSearchResults
        completedTasks = []
        incompleteTasks = []
        for _, task of @__lastSearchResults when filter(task)
            if task.status is PERFORMED_TASK
                completedTasks.push(task)
            else
                incompleteTasks.push(task)
        return [incompleteTasks, completedTasks]

    _getDates: (item) ->
        itemDatetime = ''
        itemFullDate = ''
        return {itemDatetime, itemFullDatetime} if not item.deadline
        {datetime, date} = item.deadline
        if datetime?
            dateObj = convertDatetime(datetime)
            todayDate = formatAsShortDate(Date.today())
            date = formatAsShortDate(dateObj)
            itemDatetime = formatAsShortTime(dateObj) || ''
            if todayDate isnt date
                itemDatetime += "\n#{date || ''}"
            itemFullDatetime = formatDate(datetime, true) || ''
        else if date?
            dateObj = convertDate(date)
            itemFullDatetime = formatFullDate(dateObj) || ''
            itemDatetime = formatAsShortDate(dateObj) || ''
        {itemDatetime, itemFullDatetime}

exports.TasksPanel = TasksPanel
