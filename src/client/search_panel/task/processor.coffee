{ParamsField} = require('../../editor/model')
{Request} = require('../../../share/communication')
BaseSearchProcessor = require('../base_processor').BaseSearchProcessor

class TasksProcessor extends BaseSearchProcessor
    constructor: (@_rootRouter) ->

    assign: (params, callback) ->
        delete params.recipientId
        delete params.senderId
        delete params[ParamsField.TYPE]
        if params.deadlineDate?
            params.deadline = {date: params.deadlineDate}
        delete params.deadlineDate
        if params.deadlineDatetime?
            params.deadline = {datetime: params.deadlineDatetime}
        delete params.deadlineDatetime
        request = new Request(params, callback)
        request.setProperty('recallOnDisconnect', true)
        @_rootRouter.handle('network.task.assign', request)

    send: (blipId, callback) ->
        request = new Request({blipId}, callback)
        request.setProperty('recallOnDisconnect', true)
        @_rootRouter.handle('network.task.send', request)

    updateTaskSearchInfo: (taskInfo) ->
        request = new Request({taskInfo}, ->)
        @_rootRouter.handle('navigation.updateTaskInfo', request)

module.exports =
    TasksProcessor: TasksProcessor
    instance: null