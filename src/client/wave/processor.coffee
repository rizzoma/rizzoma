Request = require('../../share/communication').Request
OtProcessor = require('../ot/processor').OtProcessor
User = require('../user/models').User

exports.contactsUpdateWindowParams = contactsUpdateWindowParams =
    google: {width: 640, height: 400}
    facebook: {width: 1025, height: 585}

class WaveProcessor
    constructor: (@_rootRouter) ->
        @_init(@_rootRouter)

    _init: (@_rootRouter) ->
        @_updateContactsCallbacks = []
        send = (blipId, callId, operationData, callback) =>
            params =
                blipId: blipId
                callId: callId
                version: operationData.v
                op: operationData.op
                random: Math.random()
            request = new Request(params, callback)
            request.setProperty('recallOnDisconnect', true)
            request.setProperty('close-confirm', true)
            @_rootRouter.handle('network.wave.postOpToBlip', request)
        require('../ot/processor').instance = @_otProcessor = new OtProcessor(send, @showPageError)

    createWave: (callback) ->
        ###
        Отправляет на сервер запрос создания волны.
        @param callback: function
        ###
        request = @_createRequest({}, callback)
        @_rootRouter.handle('network.wave.createWave', request)

    initCreateWaveWithParticipants: (userIds) ->
        ###
        Просит модуль волны создать волну со списком userIds
        волны с waveId.
        @param userIds: Array
        ###
        request = new Request({userIds: userIds}, ->)
        @_rootRouter.handle('wave.createWaveWithParticipants', request)

    createWaveWithParticipants: (waveId, participants, callback) ->
        ###
        Отправляет на сервер запрос создания волны с указанными участниками
        @param participants: Array
        @param callback: function
        ###
        request = @_createRequest({waveId: waveId, participants: participants}, callback)
        @_rootRouter.handle('network.wave.createWaveWithParticipants', request)

    createWaveByWizard: (title, emails, callback) ->
        ###
        Создает топик со списком участников и заголовком
        @param participants: Array of emails
        @param title: String
        ###
        request = @_createRequest({title: title, emails: emails}, callback)
        @_rootRouter.handle('network.wave.createWaveByWizard', request)

    updateReaderForAllBlips: (waveId, callback) ->
        ###
        Помечает на сервере прочитанными все блипы топика
        ###
        request = @_createRequest({waveId: waveId}, callback)
        @_rootRouter.handle('network.wave.updateReaderForAllBlips', request)

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

    _processOp: (err, op, callId) =>
        if err
            @showPageError(err)
        else
            try
                @_otProcessor.processOp(op, callId)
            catch e
                @showPageError(e)

    subscribeForWaveData: (wave) ->
        ###
        Подписывается на изменения данных волны и ее блипов
        @param wave: WaveViewModel
        @return: string, callId для подписки на операции документа
        ###
        callId = null
        getRequest = =>
            processOp = (err, op) =>
                @_processOp(err, op, callId)
            res = @_createRequest({versions: wave.getWaveAndBlipsVersions()}, processOp, getRequest)
            res.setProperty('wait', true)
            return res
        request = getRequest()
        @_rootRouter.handle('network.wave.subscribeWaveWithBlips', request)
        callId = request.callId
        @_otProcessor.setGroupSubscriptionCallId(wave.getId(), callId)
        return callId

    _removeWaveDataSubscription: (subscriptionCallId) ->
        request = new Request {callId: subscriptionCallId}, (err) ->
            console.warn("Could not remove wave with subscription #{subscriptionCallId}:", err) if err
        @_rootRouter.handle('network.wave.removeCall', request)

    rootRouterIsConnected: ->
        @_rootRouter.isConnected()

    getWaveWithBlips: (serverWaveId, callback) ->
        ###
        Отправляет на сервер запрос получения волны и всех ее блипов.
        @param waveServerId: string, идентификатор открываемой волны
        @param callback: function
            callback(err, shareDoc, {blipId: blipShareDoc}, socialSharingUrl)
        ###
        processResponse = (err, data) =>
            return callback(err) if err
            {wave, blips} = data
            [err, shareDoc, shareBlips] = @_makeDocs(wave, blips)
            callback(err, shareDoc, shareBlips, wave.socialSharingUrl)
        if window.getWaveWithBlipsResults?[serverWaveId]?
            {err, data} = window.getWaveWithBlipsResults[serverWaveId]
            delete window.getWaveWithBlipsResults[serverWaveId]
            window.setTimeout ->
                processResponse(err, data)
            , 0
            return {}
        args = {waveId: serverWaveId}
        referalEmailHash = window.userInfo?.referalEmailHash
        args.referalEmailHash = referalEmailHash if referalEmailHash
        request = @_createRequest(args, processResponse, true)
        @_rootRouter.handle('network.wave.getWaveWithBlips', request)
        return request

    getPlaybackData: (waveId, blipId, callback) ->
        request = new Request({waveId, blipId}, (err, data) =>
            return callback(err) if err
            {wave, blips} = data
            [err, shareDoc, shareBlips] = @_makeDocs(wave, blips)
            callback(err, shareDoc, shareBlips, wave.socialSharingUrl)
        )
        @_rootRouter.handle('network.playback.getPlaybackData', request)

    _makeDocs: (wave, blips) ->
        waveId = Math.random().toString()
        try
            unpackedWave = @_otProcessor.makeDoc(waveId, wave, waveId)
        catch err
            return [err, null, null]
        unpackedBlips = {}
        unpackedBlips[blip.docId] = blip for blip in blips
        return [null, unpackedWave, unpackedBlips]

    markWaveAsSocialSharing: (serverWaveId, callback) ->
        ###
        Помечает волну как доступную для публикации в соц. сети
        ###
        request = new Request {waveId: serverWaveId}, (err) ->
            console.error("Could not mark wave #{serverWaveId} as social sharing:", err) if err
            callback()
        @_rootRouter.handle('network.wave.markWaveAsSocialSharing', request)

    closeWave: (serverWaveId, subscriptionCallId, waveId) ->
        ###
        Отписывает клиента от волны.
        @param waveId: string
        @param subscriptionCallId: string
        @param uniqueWaveId: string
        ###
        @_otProcessor.closeGroup waveId, =>
            request = @_createRequest({waveId: serverWaveId, callId: subscriptionCallId}, (err) =>
                console.warn("Got error when closing wave", err) if err
            , true)
            @_rootRouter.handle('network.wave.closeWave', request)
            @_removeWaveDataSubscription(subscriptionCallId)

    addParticipant: (serverWaveId, userId, roleId, callback) ->
        ###
        Отправляет запрос на добавления участника в волну
        @param waveId: string, идентификатор волны
        @param userId: string, идентификатор участника
        @param roleId: int, идентификатор роли участника
        @param callback: function
            callback(err, resp)
        ###
        return if not userId.length
        request = @_createRequest({waveId: serverWaveId, participantId: userId, role: roleId}, callback)
        @_rootRouter.handle('network.wave.addParticipant', request)

    addParticipants: (serverWaveId, userIds, roleId, noNotification, callback) ->
        ###
        Отправляет запрос добавления участников в волну
        @param waveId: string, идентификатор волны
        @param userIds: [string], идентификаторы участника
        @param roleId: int, идентификатор роли всех участников
        @param noNotification: boolean, true, если не надо рассылать письма добавленным участникам
        @param callback: function
            callback(err, resp)
        ###
        request = @_createRequest({waveId: serverWaveId, participantIds: userIds, role: roleId, noNotification}, callback)
        @_rootRouter.handle('network.wave.addParticipants', request)

    removeParticipant: (serverWaveId, userId, callback) ->
        ###
        Отправляет запрос на удаление участника из волны
        @param serverWaveId: string, идентификатор волны на сервере
        @param userId: string, идентификатор участника
        @param callback: function
            callback(err, resp)
        ###
        request = @_createRequest({waveId: serverWaveId, participantId: userId}, callback)
        @_rootRouter.handle('network.wave.deleteParticipant', request)

    removeParticipants: (serverWaveId, userIds, callback) ->
        request = @_createRequest({waveId: serverWaveId, participantIds: userIds}, callback)
        @_rootRouter.handle('network.wave.deleteParticipants', request)

    changeParticipantRole: (serverWaveId, userId, roleId, callback) ->
        request = @_createRequest({waveId: serverWaveId, participantId: userId, role: roleId}, callback)
        @_rootRouter.handle('network.wave.changeParticipantRole', request)

    showPageError: (err) =>
        ###
        Показывает ошибку на странице. Использовать для тех ошибок, которые приводят
        к необходимости перезагрузить страницу
        @param err: object
        ###
        console.error "Got severe topic error", new Date(), err
        console.error err.stack
        showErrRequest = new Request({error: err}, ->)
        @_rootRouter.handle('pageError.showError', showErrRequest)

    updateSearchUnreadCount: (serverWaveId, unreadCount, totalCount) ->
        ###
        Обновляет количество непрочитанных блипов в этой волне в результатах поиска
        @param serverWaveId: string
        @param unreadCount: Number
        @param totalCount: Number
        ###
        request = new Request({waveId: serverWaveId, unreadCount, totalCount}, ->)
        @_rootRouter.handle('navigation.updateTopicsUnreadCount', request)

    updateBlipIsRead: (serverWaveId, blipId, isRead) ->
        request = new Request({waveId: serverWaveId, blipId, isRead}, ->)
        @_rootRouter.handle('navigation.updateBlipIsRead', request)

    initContactsUpdate: (source, x, y, callback) ->
        ###
        Начинает обновление контактов из сервиса. Открывает окно, обновляющее контакты, в указанных координатах.
        @param source: string, источник для новых контактов
        @param x: float
        @param y: float
        @param callback: function
        ###
        @_updateContactsCallbacks.push(callback)
        params = contactsUpdateWindowParams[source]
        if not @_updatingContacts
            @_updatingContacts = true
            window.open("/contacts/#{source}/update/", 'Updating', "width=#{params.width},height=#{params.height},left=#{x},top=#{x}")

    setWaveShareState: (serverWaveId, state, defaultRoleId, callback) ->
        ###
        Устанавливает "расшаренность" волны
        @param serverWaveId: string
        @param isPublic: boolean
        @param defaultRoleId: int
        @param callback: function
            callback(err)
        ###
        request = new Request {waveId: serverWaveId, sharedState: state, defaultRole: defaultRoleId}, callback
        @_rootRouter.handle('network.wave.setShareState', request)

    getUserContacts: (callback, fromServer=false) ->
        return callback(null, @_userContacts) if @_userContacts? and !fromServer
        request = new Request {}, (err, contacts) =>
            @_userContacts = @_convertUserContacts(contacts) if not err
            callback(err, @_userContacts )
        @_rootRouter.handle('network.user.getUserContacts', request)

    _convertUserContacts: (serverContacts) ->
        (new User(null, entry.email, entry.name, entry.avatar, null, entry.source)) for entry in serverContacts

    updateUserContacts: (contacts) ->
        ###
        Вызывается, когда из открытого окна будут получены контакты пользователя
        ###
        @_userContacts = @_convertUserContacts(contacts)
        callback() for callback in @_updateContactsCallbacks
        @_updateContactsCallbacks = []
        @_updatingContacts = false

    addOrUpdateContact: (user) ->
        return if window.userInfo? and window.userInfo.email == user.email
        for userContact in @_userContacts
            return if userContact.getEmail() == user.email
        @_userContacts.push(new User(null, user.email, user.name, user.avatar, null, 'manually'))

    showTips: ->
        request = new Request({force: true}, ->)
        @_rootRouter.handle('wave.showNextTip', request)

    showNextTip: ->
        request = new Request({}, ->)
        @_rootRouter.handle('wave.showNextTip', request)

    openAccountWizard: ->
        request = new Request({}, ->)
        @_rootRouter.handle('wave.openAndInitAccountWizard', request)

    setUserClientOption: (name, value, callback) ->
        request = new Request({name, value}, callback)
        @_rootRouter.handle('network.user.setUserClientOption', request)

    sendAccessRequest: (waveId, callback) ->
        request = new Request({waveId}, callback)
        @_rootRouter.handle('network.wave.sendAccessRequest', request)


module.exports.WaveProcessor = WaveProcessor
module.exports.instance = null