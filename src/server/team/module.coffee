BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
TeamController = require('./controller').TeamController

PULSE_ACCESS = require('../user/constants').PULSE_ACCESS

class TeamModule extends BaseModule
    ###
    Модуль предоставляющей API для работы с командами.
    ###
    constructor: (args...) ->
        super(args..., Response)

    createTeamByWizard: (request, args, callback) ->
        emails = args.emails
        teamName = args.teamName
        TeamController.createTeamByWizard(request.user, emails, teamName, callback)
    @::v('createTeamByWizard', ['emails', 'teamName'])

    sendEnterpriseRequest: (request, args, callback) ->
        companyName = args.companyName
        contactEmail = args.contactEmail
        comment = args.comment
        TeamController.sendEnterpriseRequest(request.user, companyName, contactEmail, comment, callback)
    @::v('sendEnterpriseRequest', ['companyName', 'contactEmail', 'comment'])

    getPayments: (request, args, callback) ->
        endDate = args.endDate
        TeamController.getPayments(endDate, callback)
    @::v('getPayments', ['endDate'], PULSE_ACCESS)

    getTeamTopics: (request, args, callback) ->
        TeamController.getTeamTopics(request.user, no, yes, (err, result) ->
            callback(err, result)
        )
    @::v('getTeamTopics', [])

    onAccountTypeSelected: (request, args, callback) ->
        TeamController.onAccountTypeSelected(request.user)
        callback()
    @::v('onAccountTypeSelected', [])

module.exports.TeamModule = TeamModule
