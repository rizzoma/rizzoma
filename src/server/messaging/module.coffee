BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
MessagingController = require('./controller').MessagingController

class MessagingModule extends BaseModule
    ###
    Модуль предоставляющей API для обмена сообщениями пользователями.
    ###
    constructor: (args...) ->
        super(args..., Response)

    sendToUser: (request, args, callback) ->
        ###
        Принимает сообщение для отправки другому пользователю.
        Есть проверка прав, чтобы нельзя было любому указанному пользователю посылать сообщение
        (необходимо указывать url топика, в котором ты есть с этим пользователем).
        @TODO: ограничение на размер сообщения (?), строковые типы полей приводить к строке
        ###
        waveId = args.waveId # this is wave url
        fromResource = args.fromResource
        toUserId = args.toUserId
        toResource = args.toResource
        message = args.message
        ttl = args.ttl
        #console.debug(arguments...)
        MessagingController.sendToUser(waveId, request.user, fromResource, toUserId, toResource, message, ttl, callback)
    #@::v('sendToUser', ['waveId(not_null)', 'toUserId(not_null)', 'toResource', 'message(not_null)', 'ttl'])
    @::v('sendToUser', ['waveId(not_null)', 'toUserId(not_null)', 'message(not_null)'])

    subscribeUser: (request, args, callback) ->
        ###
        подписывает пользователя на получение сообщений от других пользователей
        отправляет ему все накопившиеся сообщения

        @TODO: сохранять from - номер полученного сообщения, для надежной доставки
               (с несколькими вкладками и дисконнектом в одной из них сейчас может
               не во все вкладки доставиться сообщение)
        @TODO: приводить аргумент к строке
        ###
        resource = args.resource
        getListener = (userId, callback) ->
            return (err, messageData) ->
                callback(new Response(err, (if err then null else messageData), userId))
        listener = getListener(request.user?.id, request.callback)
        MessagingController.subscribeUser(request.user, resource, listener)
    #@::v('subscribeUser', ['resource(not_null)', 'from'])
    @::v('subscribeUser', ['resource(not_null)'])

    #TODO: unsubscribeUser(resource)

    subscribeWaveWithBlips: (request, args, callback) ->
        ###
        Подписывается на изменение волны и всех ее блипов.
        в request.versions ожидается обект вида
            wave:
                id: id волны
                version: версия волны
            blips:
                id: version
                ...
        ###
        versions = args.versions
        getListener = (userId, callback) ->
            return (err, op, clientDocId) ->
                clientOp = if err then null else OperationOtConverter.toClient(op, clientDocId)
                callback(new Response(err, clientOp, userId))
        listener = getListener(request.user?.id, request.callback)
        listenerId = "#{request.sessionId}#{request.callId}"
        WaveController.subscribeWaveWithBlips(versions, request.user, listenerId, listener, (err) ->
            callback(err) if err
        )
    @::v('subscribeWaveWithBlips', ['versions'])

    getUsersInfo: (request, args, callback) ->
        ###
        Возвращет профиль пользователя.
        ###
        waveId = args.waveId
        userIds = args.participantIds
        UserController.getUsersInfo(waveId, request.user, userIds, callback)
    @::v('getUsersInfo', ['waveId(not_null)', 'participantIds'])

    getUserContacts: (request, args, callback) ->
        ###
        Возвращет контакты пользователя.
        ###
        ContactsController.getContacts(request.user, callback)
    @::v('getUserContacts')

    setUserSkypeId: (request, args, callback) ->
        user = request.user
        skypeId = args.skypeId
        UserController.setUserSkypeId(user, skypeId, callback)
    @::v('setUserSkypeId', ['skypeId'])

    setUserClientOption: (request, args, callback) ->
        user = request.user
        optName = args.name
        optValue = args.value
        UserController.setUserClientOption(user, optName, optValue, callback)
    @::v('setUserClientOption', ['name', 'value'])

    changeProfile: (request, args, callback) ->
        user = request.user
        email = args.email
        name = args.name
        avatar = args.avatar
        UserController.changeProfile(user, email, name, avatar, callback)
    @::v('changeProfile', ['email', 'name', 'avatar'])

    installStoreItem: (request, args, callback) ->
        ###
        Инсталлирует позицию пользователю.
        ###
        itemId = args.itemId
        UserController.changeItemInstallState(request.user, itemId, ITEM_INSTALL_STATE_INSTALL, callback)
    @::v('installStoreItem', ['itemId(not_null)'])

    uninstallStoreItem: (request, args, callback) ->
        ###
        Деинсталлирует позицию.
        ###
        itemId = args.itemId
        UserController.changeItemInstallState(request.user, itemId, ITEM_INSTALL_STATE_UNINSTALL, callback)
    @::v('uninstallStoreItem', ['itemId(not_null)'])

    giveBonus: (request, args, callback) ->
        ###
        Добавляет пользователю бонус определенного типа.
        ###
        bonusType = args.bonusType
        UserController.giveBonus(request.user, bonusType, callback)
    @::v('giveBonus', ['bonusType'])

module.exports.MessagingModule = MessagingModule