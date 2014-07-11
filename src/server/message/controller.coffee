_ = require('underscore')
async = require('async')
BlipController = require('../blip/controller').BlipController
BlipProcessor = require('../blip/processor').BlipProcessor
WaveController = require('../wave/controller').WaveController
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
{CouchBlipProcessor} = require('../blip/couch_processor')
Notificator = require('../notification/').Notificator
Conf = require('../conf').Conf

USER_DENY_NOTIFICATION = require('../notification/exceptions').USER_DENY_NOTIFICATION

ACTIONS = require('../wave/constants').ACTIONS

class MessageController
    ###
    Класс представляющий контроллер сообщений.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('message')

    send: (blipId, user, callback) ->
        ###
        Отправляет сообщение.
        @param blipId: string
        @param callback: function
        ###
        tasks = [
            async.apply(@_getBlip, blipId, user)
            (blip, callback) =>
                @_getSendersAndRecipients(blip, (err, users, errState) ->
                    callback(err, blip, users, errState)
                )
            (blip, users, errState, callback) =>
                randoms = blip.message.generateNotificationRandoms()
                @_sendNotifications(blip, users, randoms, (err, errById={}) =>
                    return callback(err) if err
                    for own id, err of errById
                        errState[id] = err.toClient() if err and err.code != USER_DENY_NOTIFICATION
                        @_logger.warn(err.message) if err and err.code == USER_DENY_NOTIFICATION
                    callback(null, blip, errState, randoms)
                )
            (blip, errState, randoms, callback) =>
                return callback(null, errState) if not _.isEmpty(errState)
                @updateSentTimestamp(blip, user, (err) =>
                    callback(err)
                    @_saveBlipNotificationRandoms(blip, randoms)
                )
        ]
        async.waterfall(tasks, callback)

    addRecipientByEmail: (blipId, user, version, position, email, callback) ->
        ###
        Добавляет в топик нового участника (если нужно создает)
        и генерирут операцию на вставку получателя в блип.
        @param  blipId: string
        @param user: UserModel
        @param version: int
        @param position: int
        @param email: string
        @param callback: function
        ###
        tasks = [
            async.apply(@_getBlip, blipId, user)
            (blip, callback) ->
                WaveController.addParticipantEx(blip.getWave().getUrl() , user, email, null, no, (err, recipient) ->
                    callback(err, blip, recipient)
                )
            (blip, recipient) ->
                op = blip.message.genereateRecipientAddOp(position, recipient.id)
                BlipProcessor.postOp(blip, null, op, version, null, null, null, (err) ->
                    callback(err, recipient)
                )
        ]
        async.waterfall(tasks, callback)

    updateSentTimestamp: (blip, user, callback) ->
        ###
        Обновляет время последней отправки сообщения.
        @param blip: BlipModel
        @param callback: function
        ###
        op = blip.message.generatePluginDataOp(user)
        BlipProcessor.postOp(blip, user, op, blip.version, null, null, null, callback)

    _getBlip: (blipId, user, callback) =>
        ###
        Загружает блип с приврепренным к нему плагином сообщеней.
        @param blipId: string
        @param user: UserModel
        @param callback: function
        ###
        BlipController.getBlip(blipId, user, (err, blip) ->
            return callback(err, null) if err
            err = blip.checkPermission(user, ACTIONS.ACTION_PLUGIN_ACCESS)
            return callback(err, null) if err
            callback(null, blip)
        )

    _saveBlipNotificationRandoms: (blip, randoms) ->
        action = (blip, callback) ->
            for userId, random of randoms
                blip.notificationRecipients[random] = userId
            callback(null, true, blip, false)
        CouchBlipProcessor.saveResolvingConflicts(blip, action, (err, res) =>
            @_logger.warn(err) if err
        )

    _getSendersAndRecipients: (blip, callback) ->
        senderId = blip.message.getSenderId()
        recipientIds = blip.message.getRecipientIds()
        tasks = [
            async.apply(UserCouchProcessor.getByIdsAsDict, recipientIds.concat([senderId]))
            (users, callback) =>
                errSate = @_checkRecipientPermissions(blip, users, recipientIds)
                callback(null, users, errSate)
        ]
        async.waterfall(tasks, callback)

    _checkRecipientPermissions: (blip, users, recipientIds) ->
        errState = {}
        for id in recipientIds
            err = blip.checkPermission(users[id], ACTIONS.ACTION_READ)
            continue if not err
            errState[id] = err.toClient()
            delete users[id]
        return errState

    _sendNotifications: (blip, users, randoms, callback) ->
        ###
        Инициирует отправку сообщений.
        @param blip: BlipModel
        @param sender: UserModel
        @param recipients: array UserModel
        @param callback: function
        ###
        rootBlipId = blip.getWave().rootBlipId
        BlipProcessor.getBlip(rootBlipId, (err, rootBlip) ->
            return callback(err) if err
            notifications = blip.message.getNotifications(rootBlip, users, randoms)
            name = blip.message.getName()
            Notificator.notificateUsers(notifications, name, (err, errState)->
                return callback(err, null) if err
                errs = {}
                for err, i in errState
                    errs[notifications[i].user.id] = err
                callback(null, errs)
            )
        )

module.exports.MessageController = new MessageController()
