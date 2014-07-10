Conf = require('../../../conf').Conf
Request = require('../../../../share/communication').Request
PermissionError = require('../../../../share/exceptions').PermissionError
Anonymous = require('../../../user/anonymous')
AuthUtils = require('../../../utils/auth_utils').AuthUtils

PERMITTED_PROCEDURES =
    get: [
        'wave.searchBlipContent'
        'wave.searchBlipContentInPublicWaves'
        'wave.getWaveWithBlips'
        'wave.getBlip'
        'message.searchMessageContent'
        'store.getFullItemList'
        'task.searchByRecipient'
        'task.searchBySender'
        'team.getPayments'
        'user.getUserContacts'
        'user.getMyProfile'
        'user.getUsersInfo'
        'gtag.getGTagList'
        'store.getVisibleItemList'
        'team.getTeamTopics'
    ]
    put: [
        'wave.createWave'
        'wave.createWaveByWizard'
        'team.createTeamByWizard'
    ]
    post: [
        'user.getUsersInfo'
        'wave.postOpToBlip'
        'wave.deleteParticipant'
        'wave.addParticipant'
        'store.addItem'
        'store.editItem'
        'store.changeItemState'
        'task.assign'
        'task.send'
        'task.setStatus'
        'team.onAccountTypeSelected'
        'team.sendEnterpriseRequest'
    ]

class Rest
    ###
    HTTP-rest транспорт.
    ###
    constructor: (@_rootRouter, app) ->
        @_apiUrl = Conf.getApiTransportUrl('rest')
        for own httpMethod of PERMITTED_PROCEDURES
            app[httpMethod]("#{@_apiUrl}:moduleName/:procedureName", (req, res) =>
                procedureName = "#{req.params.moduleName}.#{req.params.procedureName}"
                permittedProcesuresForMethod = PERMITTED_PROCEDURES[req.method.toLowerCase()]
                return res.send(404) if not (permittedProcesuresForMethod and procedureName in permittedProcesuresForMethod)
                [args, token] = @_parseRequest(req)
                AuthUtils.authByToken(token, (err, user) =>
                    request = @_getApiRequest(user, args, res)
                    process.nextTick(() =>
                        #@see: sockjs transport
                        try
                            @_rootRouter.handle(procedureName, request)
                        catch err
                            console.error('Error while processing client request (rest)', err)
                    )
                )
            )

    _parseRequest: (req) ->
        ###
        Вернет args - аргументы вызова метода и token - внутренный ключь, полученые ранее от сервера на основе которого
        осуществляется авторизация запросовю
        ###
        args = req.query
        token = args.ACCESS_TOKEN
        delete args.ACCESS_TOKEN
        if req.method.toLowerCase() != 'get'
            args = req.body
        return [args, token]

    _getApiRequest: (user, args, res) ->
        #res.__$id = Math.random()
        #res.__$send = res.send
        #res.send = (args...) ->
        #    console.log('Args: ', args)
        #    console.log('Stack: ', (new Error()).stack)
        #    console.log('Id: ', res.__$id)
        #    @__$send(args...)
        request = new Request(args, (response) =>
            @_sendToClient(response, res)
        )
        request.setProperty('user', user)
        return request

    _sendToClient: (response, res) ->
        response.setProperty('callId', 'rest')
        try
            return @_sendErrToClient(response, res) if response.err
            res.json(response.serialize())
        catch e
            #console.error('Error while sending response', e, res.__$id)
            console.error('Error while sending response to client (rest)', e)

    _sendErrToClient: (response, res) ->
        message = response.err.message
        return res.send(403) if response.err instanceof(PermissionError)
        return res.send(404) if /^(Procedure|Module) .+ not found$/.test(message)
        res.json(response.serialize())

module.exports = Rest
