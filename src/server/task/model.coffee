async = require('async')
DateUtils = require('../utils/date_utils').DateUtils
PluginModel = require('../blip/plugin_model').PluginModel
getSearchUserId = require('./utils').TaskUtils.getSearchUserId
IdUtils = require('../utils/id_utils').IdUtils
NotificationUtils = require('../notification/utils').Utils

InvalidTaskStatus = require('./exceptions').InvalidTaskStatus

TASK_NODE = 'TASK'

NOT_PERFORMED_TASK = require('./constants').NOT_PERFORMED_TASK
PERFORMED_TASK = require('./constants').PERFORMED_TASK
ALL = require('./constants').ALL
Conf = require('../conf').Conf
{PLUGIN_CHANGING_STATES_NOT_MY, PLUGIN_CHANGING_STATES_CHANGE, PLUGIN_CHANGING_STATES_NO_CHANGE} = require('../blip/constants')

class TaskModel extends PluginModel
    ###
    Можель задачи.
    ###
    constructor: (blip) ->
        super(blip)

    getName: () ->
        return 'task'

    getList: () ->
        ###
        Возврашает список задач.
        @returns: array
            recipientId: string
            senderId: string
            deadline: object
            status: int
        ###
        tasks = []
        @_blip.iterateBlocks((type, block, position) ->
            params = block.params
            return if type != TASK_NODE or not params
            tasks.push({
                recipientId: params.recipientId
                senderId: params.senderId
                deadline: {date: params.deadlineDate, datetime: params.deadlineDatetime}
                status: params.status
                lastSent: params.lastSent
                lastSenderId: params.lastSenderId
                position: position
                random: params.RANDOM
            })
        )
        return tasks

    generateAddTaskOp: (position, recipientId, senderId, deadline, status=NOT_PERFORMED_TASK) ->
        ###
        Генерирует операцию для добавления новой задачи в блип.
        @param position: int - позиция в тексте, куда нужно вставить метку задачи.
        @param recipientId: string - id исполнителя задачи
        @param senderId: string - id постановщика
        @deadline: object/null - объект с полями
            date: string or undefined
            datetime: int or undefined
        @callback: function
        ###
        op = {p: position, ti: ' ', params: {}}
        op.params =
            __TYPE: TASK_NODE
            RANDOM: Math.random()
            recipientId: recipientId
            senderId: senderId
            deadlineDate: deadline.date
            deadlineDatetime: deadline.datetime
            status: status
        return op

    generateSendTaskOp: (sender) ->
        ###
        Генерирует операцию, изменеющую время отправки и отправителя для задач блипа.
        @params senderId: string
        @returns: array
        ###
        op = []
        now = DateUtils.getCurrentTimestamp()
        for task in @getList()
            position = task.position
            lastSent = task.lastSent
            lastSenderId = task.lastSenderId
            op.push({p: position, paramsd: {lastSent}, len: 1}) if lastSent
            op.push({p: position, paramsi: {lastSent: now}, len: 1})
            op.push({p: position, paramsd: {lastSenderId}, len: 1}) if lastSenderId
            op.push({p: position, paramsi: {lastSenderId: sender.id}, len: 1}) if sender
        return op

    generateSetStatusOp: (random, status) ->
        ###
        Генерирует операцию для изменения статуса задачи.
        Если задачи с таким random нет в блипе вернет undefined.
        @param random: float - значение параметра RANDOM задачи (фактически id)
        @param status: int - присваеваемый стаус
        @returns: array or undefined
        ###
        task = null
        for task in @getList()
            break if task.random == random
        return if not task
        currentStatus = task.status
        position = task.position
        op = []
        op.push({p: position, paramsd: {status: currentStatus}, len: 1}) if currentStatus
        op.push({p: position, paramsi: {status}, len: 1})
        return op

    @getSearchIndexHeader: () ->
        ###
        Возвращает индексируемые поля для заголовка индекса.
        @returns: array
        ###
        return [
            {elementName: 'attr', name: 'task_sender_ids', type: 'multi'}
            {elementName: 'attr', name: 'task_recipient_ids', type: 'multi'}
        ]

    getSearchIndex: () ->
        ###
        Возвращает индексируемые поля для индекса.
        @returns: array
        ###
        senderField = {name: 'task_sender_ids', value: ''}
        recipientField = {name: 'task_recipient_ids', value: ''}
        senderIds = []
        recipientIds = []
        for task in @getList()
            status = task.status
            senderId = task.senderId
            recipientId = task.recipientId
            senderIds.push(getSearchUserId(senderId, status), getSearchUserId(senderId, ALL))
            recipientIds.push(getSearchUserId(recipientId, status), getSearchUserId(recipientId, ALL))
        senderField.value = senderIds.join(' ')
        recipientField.value = recipientIds.join(' ')
        return [senderField, recipientField]

    generateNotificationRandoms: () ->
        ###
        генерит рэндомы для тех кого оповещаем
        Используется в email_reply_fetcher
        ###
        randoms = {}
        for task in @getList()
            randoms[task.recipientId] = NotificationUtils.generateNotificationRandom()
        return randoms

    getNotifications: (rootBlip, users, randoms) ->
        ###
        Возвращает контекст для уведомления.
        @param rootBlip: BlipMOdel корневой блип топика в котором стоит задача.
        @param users: ubject, {userId: UserMOdel, ..} - словарь всех участников задач блипа по id (отправители и получатели вперемешку).
        @returns: array
        ###
        notifications = []
        replyEmail = Conf.get('replyEmail').split('@')
        for task in @getList()
            continue if task.status == PERFORMED_TASK
            sender = users[task.senderId]
            recipient = users[task.recipientId]
            continue if not sender or not recipient
            timezone = recipient.timezone or 0
            title = rootBlip.getTitle()
            text = @_blip.getText(null, null, "\n")
            waveId = @_blip.getWave().getUrl()
            replyTo = "#{replyEmail[0]}+#{waveId}/#{@_blip.id}/#{randoms[task.recipientId]}@#{replyEmail[1]}"
            context =
                title: title
                text: text
                waveId: waveId
                blipId: @_blip.id
                blipTime: new Date(@_blip.contentTimestamp * 1000 + timezone * 3600000)
                timezone: if timezone >= 0 then "GMT+#{timezone}" else "GMT#{timezone}"
                deadline: task.deadline
                sender: sender
                from: sender
                replyTo: replyTo
            notifications.push({context: context, user: recipient})
        return notifications

    verifyParams: (deadline, status, callback) ->
        ###
        Проверяет параметры задачи.
        @param deadline: object or undefimed
        @param status: int or undefined
        ###
        tasks = [
            async.apply(@verifyDeadline, deadline)
            async.apply(@verifyStatus, status)
        ]
        async.parallel(tasks, (err, params) ->
            callback(err, params...)
        )

    verifyDeadline: (deadline={}, callback) =>
        ###
        Проверяет формат дэдлайна. Должен быть null или объектом с полями date или datetime корректного формата времени.
        @param deadline: string or undefined
        @param callback: function
        ###
        datetime = parseInt(deadline.datetime, 10)
        date = if (new Date(deadline.date)).getTime() then deadline.date else null
        return callback(null, deadline) if not date and not datetime
        return callback(null, {datetime}) if datetime
        return callback(null, {date}) if date

    verifyStatus: (status, callback) =>
        ###
        Проверяет формат статуса. Дожен быть null или корректным числовым значением статуса.
        @param status: int or undefined
        @param callback: function
        ###
        return callback(null, status) if not status
        return callback(new InvalidTaskStatus()) if status not in [NOT_PERFORMED_TASK, PERFORMED_TASK]
        callback(null, status)

    checkOpPermission: (op, user) ->
        task = @_getByPosition(op.p)
        return task and user.isEqual(task.recipientId)

    getChangingState: (ops) ->
        ###
        @param ops: arrya
        @returns: int
        @see: PluginModel
        ###
        state = 0
        for op in ops
            state <<= 2
            if not @_getByPosition(op.p)
                state |= PLUGIN_CHANGING_STATES_NOT_MY #мимо
                continue
            params  = op.paramsd or op.paramsi
            if params and (params.lastSent or params.lastSenderId) #отправка таска
                state |= PLUGIN_CHANGING_STATES_NO_CHANGE
                continue
            if op.td #удаление таска
                state |= PLUGIN_CHANGING_STATES_NO_CHANGE
                continue
            state |= PLUGIN_CHANGING_STATES_CHANGE
        return state

module.exports.TaskModel = TaskModel
