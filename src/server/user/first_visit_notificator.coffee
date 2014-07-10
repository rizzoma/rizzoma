_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Notificator = require('../notification').Notificator
NotificationUtils = require('../notification/utils').Utils
DateUtils = require('../utils/date_utils').DateUtils
USER_DENY_NOTIFICATION = require('../notification/exceptions').USER_DENY_NOTIFICATION


class FirstVisitNotificator
    constructor: () ->
        @AFTER_PERIOD = 60 * 60 * 24 # пользователи зареганные больше чем
        @BEFORE_PERIOD = 60 * 60 * 48 # пользователи зареганные меньше 2-х суток
        @USERS_LIMIT = 500 # скольким пользователям высылаем оповещения за 1 запуск
        @_now = DateUtils.getCurrentTimestamp()
        @_logger = Conf.getLogger('first-visit-notificator')

    _saveFirstVisitNotificationSent: (users, callback) ->
        ###
        Saving last sent to messages
        ###
        action = (model, callback) ->
            model.firstVisitNotificationSent = DateUtils.getCurrentTimestamp()
            callback(null, true, model, false)
        UserCouchProcessor.bulkSaveResolvingConflicts(_.values(users), action, callback)

    _getNotificationContents: (users) ->
        return ({user, context: {}} for userId, user of users)


    _notificateUsers: (users, callback) ->
        notifications = @_getNotificationContents(users)
        Notificator.notificateUsers(notifications, "first_visit", (err, errState) ->
            return callback(err, null) if err
            errs = {}
            for err, i in errState
                errs[notifications[i].user.id] = err
            callback(null, errs)
        )

    run: (callback) ->
        ###
        Запускатор
        ###
        @_logger.info("Started")
        Notificator.initTransports()
        tasks = [
            (callback) =>
                # loading first visited users with nonsent notifications
                UserCouchProcessor.getByFirstVisitNotNotificated(@_now - @BEFORE_PERIOD, @_now - @AFTER_PERIOD, @USERS_LIMIT, callback)
            (users, callback) =>
                @_logger.info("Loaded #{_.keys(users).length} first visited users")
                @_saveFirstVisitNotificationSent(users, (err, res) =>
                    return callback(err, null) if err
                    updatedUsers = []
                    usersToNotificate = {}
                    for userId, row of res
                        if not row.error
                            updatedUsers.push(userId)
                            usersToNotificate[userId] = users[userId]
                        else
                            @_logger.error(row.error)
                    @_logger.info("Succesfully saved firstVisitNotificationSent #{updatedUsers.length} users: #{updatedUsers.join(', ')}")
                    callback(null, usersToNotificate, res)
                )
            (users, res, callback) =>
                @_notificateUsers(users, (err, res) =>
                    return callback(err, null) if err
                    notificatedUsers = []
                    for own userId, user of users
                        err = res[userId]
                        if err and err.code != USER_DENY_NOTIFICATION
                            @_logger.error(err)
                        else
                            notificatedUsers.push(userId)
                    @_logger.info("Succesfully notificated #{notificatedUsers.length} users: #{notificatedUsers.join(', ')}")
                    callback(null)
                )
        ]
        async.waterfall(tasks, (err) =>
            Notificator.closeTransports()
            @_logger.error(err) if err
            @_logger.info('Finished')
            callback?(null)
        )


module.exports.FirstVisitNotificator = new FirstVisitNotificator()