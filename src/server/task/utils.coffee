_ = require('underscore')
IdUtils = require('../utils/id_utils').IdUtils

STATUS_OFFSET = 2

class TaskUtils
    ###
    Утилиты для работы с задачами.
    ###
    constructor: () ->

    getSearchUserId: (user, status) ->
        ###
        Преобразует id пользователя в id для поиска (ддобавляет статус).
        @param id: string
        @param status: int
        @returns: int
        ###
        ids = if _.isString(user) then [user] else user.getAllIds()
        searchIds = ((IdUtils.getOriginalId(id) << STATUS_OFFSET) | status for id in ids)
        return searchIds

module.exports.TaskUtils = new TaskUtils()
