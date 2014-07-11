BaseRouter = require('../../share/base_router').BaseRouter
Request = require('../../share/communication').Request
MicroEvent = require('../utils/microevent')
REQUEST_KEY = 'network.team.getTeamTopics'
{LocalStorage} = require('../utils/localStorage')

LIST_UPDATE_INTERVAL = 60 * 60 * 1000 # Обновлять список топиков команд не чаще, чем раз в час

class AccountSetupProcessor extends BaseRouter
    constructor: (args...) ->
        super(args...)
        @_isBusinessUser = false

    _createRequest: (args, callback, shouldRecall=false) ->
        ###
        Создает Request
        @param args: object, аргументы вызова
        @param callback: function, будет вызван при получении ошибки или результата
        @param shouldRecall: boolean, повторять ли запрос при ошибках сети
        @return: Request
        ###
        res = new Request(args, callback)
        res.setProperty('recallOnDisconnect', shouldRecall)
        return res

    createTeamByWizard: (emails, teamName, callback) ->
        ###
        Отправляет на сервер запрос группового топика
        @param callback: function
        ###
        request = @_createRequest({emails, teamName}, callback)
        @_rootRouter.handle('network.team.createTeamByWizard', request)

    sendEnterpriseRequest: (companyName, contactEmail, comment, callback) ->
        ###
        Отправляет на сервер поля для письма-запроса на ентерпрайз аккаунт
        @param callback: function
        ###
        request = @_createRequest({companyName, contactEmail, comment}, callback)
        @_rootRouter.handle('network.team.sendEnterpriseRequest', request)

    getTeamTopics: (callback) ->
        ###
        Получает с сервера список командных топиков
        @param callback: function
        ###
        request = @_createRequest({}, (err, res) =>
            return callback(err) if err
            @_emitDebtEvent(res.hasDebt)
            callback(null, res)
        )
        @_rootRouter.handle('network.team.getTeamTopics', request)

    _emitDebtEvent: (hasDebt) ->
        @emit('team-debt-change', hasDebt)

    setAccountTypeSelected: (callback) ->
        ###
        Помечает что тип аккаунта выбран
        @param callback: function
        ###
        request = @_createRequest({}, callback)
        @_rootRouter.handle('network.team.onAccountTypeSelected', request)

    getCachedTeamTopics: ->
        res = LocalStorage.getSearchResults(REQUEST_KEY, window.userInfo?.teamsCacheKey)
        if not res
            # Удалим старое значение, если cachekey не совпал
            @clearCachedTeamTopics()
        else
            hasDebt = res.value?.hasDebt
            @_emitDebtEvent(hasDebt) if hasDebt?
        return res

    setCachedTeamTopics: (topics, hasDebt) ->
        dateToCache = {topics}
        dateToCache.hasDebt = hasDebt if hasDebt?
        LocalStorage.setSearchResults(REQUEST_KEY, dateToCache, window.userInfo?.teamsCacheKey)

    clearCachedTeamTopics: ->
        LocalStorage.clearSearchResult(REQUEST_KEY)

    checkIsBusinessUser: ->
        responseCache = @getCachedTeamTopics()
        if responseCache and responseCache.value
            interval = Date.now() - responseCache.savedTime
            if interval < LIST_UPDATE_INTERVAL
                return @changeBusinessType(!!responseCache.value.topics?.length)
        @getTeamTopics (err, res) =>
            return if err
            @changeBusinessType(!!res.topics.length)

    isBusinessUser: -> @_isBusinessUser

    changeBusinessType: (isBusinessUser) ->
        return if isBusinessUser is @_isBusinessUser
        @_isBusinessUser = isBusinessUser
        @emit('is-business-change', @_isBusinessUser)

    forceIsBusinessUpdate: ->
        LocalStorage.clearSearchResult(REQUEST_KEY)
        @emit('force-is-business-update')
MicroEvent.mixin(AccountSetupProcessor)

module.exports =
    AccountSetupProcessor: AccountSetupProcessor
    instance: null
    LIST_UPDATE_INTERVAL: LIST_UPDATE_INTERVAL