BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
IdUtils = require('../utils/id_utils').IdUtils
SearchProcessor = require('../search/processor').SearchProcessor
TaskController = require('./controller').TaskController
TaskSearchController = require('./search_controller').TaskSearchController

class TaskModule extends BaseModule
    ###
    Модуль предоставляющей API для работы с задачами.
    ###
    constructor: (args...) ->
        super(args..., Response)

    send: (request, args, callback) ->
        blipId = args.blipId
        user = request.user
        TaskController.send(blipId, user, callback)
    @::v('send', ['blipId'])

    assign: (request, args, callback) ->
        ###
        Обрабатывает запрос на постановку задачи.
        ###
        blipId = args.blipId
        version = parseInt(args.version, 10)
        position = parseInt(args.position, 10)
        recipientEmail = args.recipientEmail
        deadline = args.deadline
        status = parseInt(args.status, 10)
        user = request.user
        TaskController.assign(blipId, user, version, position, recipientEmail, deadline, status, callback)
    @::v('assign', ['blipId(not_null)' , 'version', 'position','recipientEmail'])

    setStatus: (request, args, callback) ->
        ###
        Обрабатывает запрос на изменение статуса задачи.
        ###
        blipId = args.blipId
        random = args.random
        status = parseInt(args.status, 10)
        TaskController.setStatus(blipId, request.user, random, status, callback)
    @::v('setStatus', ['blipId(not_null)' , 'random', 'status'])

    searchByRecipient: (request, args, callback) ->
        ###
        Обрабатывает запрос на поиско по содержимому задач, поставленных на инициатора поиска.
        @param request: Request
        ###
        user = request.user
        queryString = args.queryString
        status = args.status
        TaskSearchController.executeQuery(user, queryString, status, user, null, args.lastSearchDate, callback)
    @::v('searchByRecipient', ['queryString'])

    searchBySender: (request, args, callback) ->
        ###
        Обрабатывает запрос на поиск по содержимому задач, поставленых инициаторм поиска.
        @param request: Request
        ###
        user = request.user
        queryString = args.queryString
        status = args.status
        TaskSearchController.executeQuery(user, queryString, status, null, user, args.lastSearchDate, callback)
    @::v('searchBySender', ['queryString'])

module.exports.TaskModule = TaskModule