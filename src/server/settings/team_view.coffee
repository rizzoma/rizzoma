async = require('async')
SettingsGroupView = require('./settings_group_view').SettingsGroupView
TeamController = require('../team/controller').TeamController
ContactsController = require('../contacts/controller').ContactsController
Conf = require('../conf/').Conf

TEAM_STATES = require('../team/constants').TEAM_STATES

class TeamSettingsView extends SettingsGroupView
    ###
    View группа настроек команд.
    ###
    getName: () ->
        return 'team'

    supplementContext: (context, user, profile, auths, callback) ->
        return callback(null, null) if not user or user.isAnonymous()
        context.TEAM_STATES = TEAM_STATES
        context.userInfo = user.toObject(true)
        context.userInfo.card = user.getCard()
        context.apiKey = Conf.getPaymentConf().apiPublicKey
        context.availableMonthNumbers = [1..12]
        currentYear = (new Date).getFullYear()
        context.availableYearNumbers = [currentYear..currentYear+10]
        tasks = [
            (callback) ->
                TeamController.getTeamTopics(user, yes, no, (err, result) ->
                    myTeams = []
                    otherTeams = []
                    for topic in result.topics
                        if topic.isOwnTopic then myTeams.push(topic) else otherTeams.push(topic)
                    context.teamTopics = result.topics
                    context.myTeams = myTeams
                    context.otherTeams = otherTeams
                    context.regularParticipantCount = result.regularParticipantCount
                    context.trialParticipantCount = result.trialParticipantCount
                    context.debtParticipantCount = result.debtParticipantCount
                    context.regularAmount = result.regularAmount
                    context.trialAmount = result.trialAmount
                    context.debtAmount = result.debtAmount
                    context.hasDebt = result.hasDebt
                    context.allAllIsTrial = result.allAllIsTrial
                    callback(err)
                )
            (callback) ->
                ContactsController.getContacts(user, (err, contacts) ->
                    context.userContacts = contacts
                    callback(err)
                )
        ]
        async.parallel(tasks, (err) ->
            callback(err, context)
        )


module.exports.TeamSettingsView = new TeamSettingsView()
