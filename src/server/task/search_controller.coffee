_ = require('underscore')
async = require('async')
SearchController = require('../search/controller').SearchController
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
getSearchUserId = require('./utils').TaskUtils.getSearchUserId
ALL = require('./constants').ALL
TASK_SEARCH_LIMIT = 200

class TaskSearchController extends SearchController
    ###
    Процессор поисковой выдачи для задач.
    ###
    constructor: () ->
        super()
        @_idField = 'blip_id'
        @_changedField = 'changed'
        @_ptagField = 'ptags'

    executeQuery: (user, queryString, status=ALL, recipient, sender, lastSearchDate, callback) ->
        return if @_returnIfAnonymous(user, callback)
        query = @_getQuery()
            .select(['blip_id', 'wave_url', 'changed', 'content_timestamp', 'ptags'])
            .addPtagsFilter(user, null)
            .addQueryString(queryString)
            .orderBy('content_timestamp')
            .limit(TASK_SEARCH_LIMIT)
        query.addAndFilter("task_recipient_ids in (#{getSearchUserId(recipient, status).join(',')})") if recipient
        query.addAndFilter("task_sender_ids in (#{getSearchUserId(sender, status).join(',')})") if sender
        super(query, lastSearchDate, callback)

    _getItem: (result, changed) ->
        return {
            blipId: result[@_idField]
            waveId: result.wave_url
        }

    _getChangedItems: (ids, callback) ->
        return callback(null, {}) if not ids.length
        tasks = [
            async.apply(CouchBlipProcessor.getByIdsAsDict, ids)
            (blips, callback) ->
                usersIds = []
                tasksByBlipId = {}
                for own id, blip of blips
                    tasksList = blip.task.getList()
                    tasksByBlipId[id] = tasksList
                    for task in tasksList
                        usersIds.push(task.recipientId, task.senderId)
                callback(null, blips, tasksByBlipId, usersIds)
            (blips, tasksByBlipId, usersIds, callback) ->
                UserCouchProcessor.getByIdsAsDict(usersIds, (err, users) ->
                    callback(err, blips, tasksByBlipId, users)
                )
            (blips, tasksByBlipId, users, callback) =>
                @_compileItems(blips,  tasksByBlipId, users, callback)
        ]
        async.waterfall(tasks, callback)

    _compileItems: (blips, tasksByBlipId, users, callback) ->
        ###
        Собирает выдачу для изменившихся результатов поиска.
        @param blips: object - блипы-сообщения
        @param senders: object - отправители
        @param recipient: object - получатели
        ###
        items = {}
        for own id, blip of blips
            tasks = tasksByBlipId[id]
            if not tasks.length
                items[id] = null
                continue
            validTasks = []
            for task in tasks
                recipient = users[task.recipientId]
                sender = users[task.senderId]
                continue if not (recipient and sender)
                validTasks.push({
                    deadline: task.deadline,
                    status: task.status,
                    recipientName: recipient.name,
                    recipientEmail: recipient.email,
                    recipientAvatar: recipient.avatar,
                    senderName: sender.name
                    senderEmail: sender.email
                    senderAvatar: sender.avatar
                    isRead: blip.getReadState(recipient)
                })
            items[id] =
                title: blip.getTitle()
                snippet: blip.getSnippet()
                tasks: validTasks
        callback(null, items)

    _extendItems: (items, indexes, changedItems) ->
        for own id, changedItem of changedItems
            index = indexes[id]
            if changedItem == null
                delete items[index]
                continue
            item = items[index]
            item.changed = true
            tasks = changedItem.tasks
            delete changedItem.tasks
            items[index] = _.extend(item, changedItem, if tasks.length then tasks[0] else {})
        return _.compact(items)

module.exports.TaskSearchController = new TaskSearchController()
