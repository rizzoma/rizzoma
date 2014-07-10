_ = require('underscore')
async = require('async')
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
CouchWaveProcessor = require('../wave/couch_processor').CouchWaveProcessor
BlipProcessor = require('../blip/processor').BlipProcessor
BlipController = require('../blip/controller').BlipController
WaveController = require('../wave/controller').WaveController
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Notificator = require('../notification/').Notificator
TaskNotFound = require('./exceptions').TaskNotFound

PERFORMED_TASK = require('./constants').PERFORMED_TASK
ACTIONS = require('../wave/constants').ACTIONS
USER_DENY_NOTIFICATION = require('../notification/exceptions').USER_DENY_NOTIFICATION
Conf = require('../conf').Conf

class TaskController
    ###
    Класс, представляющий контроллер задач.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('task')

    send: (blipId, user, callback) ->
        ###
        Отправляет уведомление о задачах в блипе.
        @param blipId: string
        @param user: UserModel
        @param callback: function
        ###
        tasks = [
            async.apply(@_getBlip, blipId, user)
            (blip, callback) ->
                rootBlipId = blip.getWave().rootBlipId
                BlipProcessor.getBlip(rootBlipId, (err, rootBlip) ->
                    callback(err, blip, rootBlip)
                )
            (blip, rootBlip, callback) =>
                @_getSendersAndRecipients(blip, (err, users, errSate) ->
                    return callback(err) if err
                    callback(null, blip, rootBlip, users, errSate)
                )
            (blip, rootBlip, users, errSate, callback) =>
                randoms = blip.task.generateNotificationRandoms()
                notifications = blip.task.getNotifications(rootBlip, users, randoms)
                name =  blip.task.getName()
                Notificator.notificateUsers(notifications, name, (err, errById) =>
                    return callback(err) if err
                    errSate = {}
                    for err, i in errById
                        errSate[notifications[i].user.id] = err.toClient() if err and err.code != USER_DENY_NOTIFICATION
                        @_logger.warn(err.message) if err and err.code == USER_DENY_NOTIFICATION
                    callback(err, blip, errSate, randoms)
                )
            (blip, errSate, randoms, callback) =>
                return callback(null, errSate) if not _.isEmpty(errSate)
                @updateSentTimestamp(blip, user, (err) =>
                    callback(err)
                    @_saveBlipNotificationRandoms(blip, randoms)
                )
        ]
        async.waterfall(tasks, callback)

    updateSentTimestamp: (blip, user, callback) ->
        op = blip.task.generateSendTaskOp(user)
        BlipProcessor.postOp(blip, user, op, blip.version, null, null, null, callback)

    _saveBlipNotificationRandoms: (blip, randoms) ->
        action = (blip, callback) ->
            for userId, random of randoms
                blip.notificationRecipients[random] = userId
            callback(null, true, blip, false)
        CouchBlipProcessor.saveResolvingConflicts(blip, action, (err, res) =>
            @_logger.warn(err) if err
        )

    assign: (blipId, user, version, position, recipientEmail, deadline, status, callback) ->
        ###
        Ставит задачу от имени user на исполнителя recipientEmail.
        blipId: string
        user: UserModel
        version: int - версия блипа на момент постановки задачи
        position: int - позиция в которую нужно вставить метку задачи
        recipientEmail: string - почта исполнителя
        deadline: int - дэдлайн задачи
        status: int - статус задачи
        callback: function
        ###
        tasks = [
            async.apply(@_getBlip, blipId, user)
            (blip, callback) ->
                blip.task.verifyParams(deadline, status, (err, deadline, status) ->
                    callback(err, blip, deadline, status)
                )
            (blip, deadline, status, callback) ->
                WaveController.addParticipantEx(blip.getWave().getUrl() , user, recipientEmail, null, no, (err, recipient) ->
                    callback(err, blip, deadline, status, recipient)
                )
            (blip, deadline, status, recipient, callback) ->
                op = blip.task.generateAddTaskOp(position, recipient.id, user.id, deadline, status)
                callback(null, blip, recipient, op)
            (blip, recipient, op, callback) ->
                BlipProcessor.postOp(blip, null, op, version, null, null, null, (err) ->
                    callback(err, recipient)
                )
        ]
        async.waterfall(tasks, callback)

    setStatus: (blipId, user, random, status, callback) ->
        ###
        Изменяет статус задачи.
        @param blipId: string
        @user: UserModel
        @random: float - значение параметра RANDOM задачи (фактически id)
        @status: int - присваеваемый статус
        @param callback: function
        ###
        tasks = [
            async.apply(@_getBlip, blipId, user)
            (blip, callback) ->
                blip.task.verifyStatus(status, (err, status) ->
                    callback(err, blip, status)
                )
            (blip, status, callback) ->
                op = blip.task.generateSetStatusOp(random, status)
                callback(new TaskNotFound()) if not op
                BlipProcessor.postOp(blip, null, op, blip.version, null, null, null, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err)
        )

    _getBlip: (blipId, user, callback) =>
        ###
        Получает блип и проверяет права доступа к нему.
        @param blipId: string
        @param callback: function
        ###
        tasks = [
            async.apply(BlipController.getBlip, blipId, user)
            (blip, callback) ->
                callback(blip.checkPermission(user, ACTIONS.ACTION_PLUGIN_ACCESS), blip)
        ]
        async.waterfall(tasks, callback)

    _getSendersAndRecipients: (blip, callback) ->
        ###
        Возвращает словарь участников (отправители и получатели) всех задач в блипе.
        ###
        ids = []
        recipientIds = []
        for own task in blip.task.getList()
            continue if task.status == PERFORMED_TASK
            recipientId = task.recipientId
            recipientIds.push(recipientId)
            senderId = task.senderId
            ids.push(recipientId, senderId)
        UserCouchProcessor.getByIdsAsDict(ids, (err, users) ->
            return callback(err) if err
            errState = {}
            for id in recipientIds
                err = blip.checkPermission(users[id], ACTIONS.ACTION_READ)
                continue if not err
                errSate[id] = err.toClient()
                delete users[id]
            callback(null, users, errState)
        )

module.exports.TaskController = new TaskController()