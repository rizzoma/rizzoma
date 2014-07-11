PERFORMED_TASK = require('./constants').PERFORMED_TASK
TaskController = require('./controller').TaskController

class TaskAutosender
    ###
    Вспомогательный класс для автоотправки задач.
    @see: blip/plugin_autosender
    ###
    constructor: () ->

    getName: () ->
        return 'task'

    getSendersAndRecipientsIdsForOneItem: (blip) ->
        ids = []
        recipientIds = []
        for own task in blip.task.getList()
            continue if task.status == PERFORMED_TASK
            recipientId = task.recipientId
            senderId = task.senderId
            continue if senderId == recipientId
            recipientIds.push(recipientId)
            ids.push(recipientId, senderId)
        return [ids, recipientIds]

    getNotifications: (blip, rootBlip, users, randoms) ->
        return blip.task.getNotifications(rootBlip, users, randoms)

    updateSentTimestamp: (blip, callback) ->
        TaskController.updateSentTimestamp(blip, null, callback)

module.exports = new TaskAutosender()
