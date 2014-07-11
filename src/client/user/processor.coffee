MicroEvent = require('../utils/microevent')
User = require('./models').User
Request = require('../../share/communication').Request

class UserProcessor
    constructor: (args...) ->
        @_init(args...)

    _init: (@_rootRouter) ->
        @_cache = {}

    _processResponse: (err, users) =>
        ###
        Обработчик ответа от сервера
        @param err: Error
        @param users: [Object]
        ###
        if err
            console.warn "Error in user info response", err
            return
        return if not users.length
        @addOrUpdateUsersInfo(users)

    addOrUpdateUsersInfo: (users) ->
        ###
        Обновляет информацию в кэше и вызывает событие 'update'
        @param users: [Object]
        ###
        userIds = []
        for info in users
            if not @_cache[info.id]
                @_cache[info.id] = new User(info.id, info.email, info.name, info.avatar, info.extra, info.source, info.skypeId)
            else
                @_cache[info.id].updateInfo(info.email, info.name, info.avatar, info.extra, info.source, info.skypeId)
            userIds.push(info.id)
        @emit('update', userIds)

    _getUsersInfo: (userIds, waveId) ->
        ###
        Отправляет запрос на получение информации о пользователях волны
        @param userIds: [string], идентификаторы пользователей
        @param waveId: string, идентификатор волны
        ###
        request = new Request({participantIds: userIds, waveId: waveId}, @_processResponse)
        request.setProperty('recallOnDisconnect', true)
        @_rootRouter.handle('network.user.getUsersInfo', request)

    getUsers: (userIds, waveId, force) ->
        ###
        Метод позволяет получить модели пользователей по идентификаторам
        @param userIds: [string], идентификаторы пользователей
        @param waveId: string, идентификатор волны
        @returns [Users], массив моделей пользователей
        ###
        # emptyUsers - пользователи, которые будут запрошены с сервера
        emptyUsers = []
        resultUsers = []
        for userId in userIds
            now = Date.now()
            user = @_cache[userId] ||= User.getUserStub(userId)
            if force or (!user.isLoaded() and (now - user.lastRequestedTime > 10000))
                user.lastRequestedTime = now
                emptyUsers.push(userId)
            resultUsers.push(user)
        @_getUsersInfo(emptyUsers, waveId) if emptyUsers.length
        resultUsers

    getMyPrefs: ->
        @_myPrefs ?= window.userInfo?.clientPreferences

    prepareMerge: (emailToMerge, callback) ->
        request = new Request({emailToMerge}, callback)
        @_rootRouter.handle('network.user.prepareMerge', request)

    mergeByOauth: (code, callback) ->
        request = new Request({code}, callback)
        @_rootRouter.handle('network.user.mergeByOauth', request)

MicroEvent.mixin UserProcessor

instance = null

exports.UserProcessor = UserProcessor
exports.instance = instance