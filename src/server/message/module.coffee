BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
MessageController = require('./controller').MessageController
MessageSearchController = require('./search_controller').MessageSearchController
IdUtils = require('../utils/id_utils').IdUtils

class MessageModule extends BaseModule
    ###
    Модуль предоставляющей API для отправки сообщений.
    ###
    constructor: (args...) ->
        super(args..., Response)

    send: (request, args, callback) ->
        blipId = args.blipId
        MessageController.send(blipId, request.user, callback)
    @::v('send', ['blipId(not_null)'])

    searchMessageContent: (request, args, callback) ->
        ###
        Обрабатывает запрос на поиско по содержимому сообщений.
        @param request: Request
        ###
        user = request.user
        queryString = args.queryString
        ptagNames = args.ptagNames
        senderId = args.senderId
        MessageSearchController.executeQuery(user, queryString, ptagNames, user, senderId, args.lastSearchDate, callback)
    @::v('searchMessageContent', ['queryString'])

    addRecipientByEmail: (request, args, callback) ->
        ###
        Добавляет в топик нового участника (если нужно создает)
        и генерирут операцию на вставку получателя в блип.
        ###
        blipId = args.blipId
        user = request.user
        version = args.version
        position = parseInt(args.position, 10)
        email = args.email
        return callback('invalid position format') if not position
        MessageController.addRecipientByEmail(blipId, user, version, position, email, (err, recipient) ->
            callback(err, recipient)
        )
    @::v('addRecipientByEmail', ['blipId(not_null)', 'version', 'position', 'email'])

module.exports.MessageModule = MessageModule
