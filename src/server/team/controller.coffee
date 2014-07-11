async = require('async')
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
TeamCouchProcessor = require('./couch_processor').TeamCouchProcessor
WelcomeWaveBuilder = require('../wave/welcome_wave').WelcomeWaveBuilder
UserModel = require('../user/model').UserModel
isEmail = require('../../share/utils/string').isEmail
InvalidEmail = require('../user/exceptions').InvalidEmail
Notificator = require('../notification/').Notificator
Conf = require('../conf').Conf
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor

CREATION_REASON_ADD = require('../user/constants').CREATION_REASON_ADD
TOPIC_TYPES = require('../wave/constants').TOPIC_TYPES
ROLE_EDITOR = require('../wave/constants').ROLE_EDITOR
SHARED_STATE_PRIVATE = require('../wave/constants').SHARED_STATE_PRIVATE
TEMPLATE_URL = Conf.get('teamTopicTemplate').url
SUPPORT_EMAIL = Conf.get('supportEmail')
ACTION_DELETE_FROM_TOPIC = require('../wave/constants').ACTION_DELETE_FROM_TOPIC
ACTION_FULL_PROFILE_ACCESS = require('../wave/constants').ACTION_FULL_PROFILE_ACCESS
TEAM_STATES = require('../team/constants').TEAM_STATES

SUM_PER_USER = 5

class TeamController

    constructor: () ->
        @_logger = Conf.getLogger('team-controller')

    createTeamByWizard: (user, emails, teamName, callback) ->
        ###
        Создает топик для команды.
        @param user: UserModel
        @param emails: array
        @param teamName: string
        @param callback: function
        ###
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                UserCouchProcessor.getOrCreateByEmails(emails, CREATION_REASON_ADD, (err, participants) ->
                    callback(err, user, participants)
                )
            (user, participants, callback) ->
                participantsToAdd = (participant for email, participant of participants when not user.isEqual(participant))
                settings =
                    sourceWaveUrl: TEMPLATE_URL
                    topicType: TOPIC_TYPES.TOPIC_TYPE_TEAM
                    participants: participantsToAdd
                    role: ROLE_EDITOR
                    sharedState: SHARED_STATE_PRIVATE
                    waveOptions: {teamName}
                    context: {teamName}
                WelcomeWaveBuilder.createWelcomeWave(user, settings, (err, teamTopic) ->
                    return callback(err) if err
                    callback(null, [user].concat(participantsToAdd), teamTopic)
                )
            (users, teamTopic, callback) =>
                callback(null, teamTopic)
                @_setBonuses(users, teamTopic.waveId)
        ]
        async.waterfall(tasks, (err, teamTopic) =>
            return @_logger.error('Error while creating team-topic', {err: err, userId: user.id}) if err
            callback(err, teamTopic)
        )

    _setBonuses: (users, url) ->
        action = (user, url, callback) ->
            [err, changed] = user.setTeamBonus(url)
            callback(err, changed, user, false)
        UserCouchProcessor.bulkSaveResolvingConflicts(users, action, url, (err) =>
            @_logger.error("Error while setting bonuses to team users", {err: err, userId: users[0].id}) if err
        )

    sendEnterpriseRequest: (user, companyName, contactEmail, comment, callback) ->
        ###
        Отправляет саппорту письмо о создании интерпрайз-аккаунта.
        @param user: UserModel
        @param companyName: string
        @param contactEmail: string
        @param comment: string
        @param callback: function
        ###
        return callback(new InvalidEmail(contactEmail)) if not isEmail(contactEmail)
        callback()
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (from, callback) =>
                support = @_getUserFromEmail(SUPPORT_EMAIL)
                context = {companyName, comment, from, contactEmail}
                Notificator.notificateUser(support, 'enterprise_request', context, callback)
        ]
        async.waterfall(tasks, (err) =>
            @_logger.error('Error while sending enterprise request', {err: err, userId: user.id}) if err
        )

    _getUserFromEmail: (email) ->
        user = new UserModel()
        user.setEmail(email)
        #костыль для нотификатора @see: isNewUser. Исключант лишнее обращение к фс.
        user.firstVisit = 1
        return user

    getPayments: (endDate, callback) ->
        startDate = endDate - 30 * 24 * 3600
        tasks = [
            async.apply(TeamCouchProcessor.getByTopicTypeAndUserId, TOPIC_TYPES.TOPIC_TYPE_TEAM, null)
            (topics, callback) =>
                ids = []
                for topic in topics
                    id = topic.getTopicCreator()?.id
                    ids.push(id) if id
                UserCouchProcessor.getByIdsAsDict(ids, (err, creators) =>
                    return callback(err) if err
                    regularAmount = 0
                    totalTopicsCount = topics.length
                    totalUsersCount = 0
                    payments = []
                    for topic in topics
                        totalUsersCount += topic.getParticipantsWithRole(true).length
                        id = topic.getTopicCreator()?.id
                        continue if not id
                        creator = creators[id]
                        continue if not creator
                        payment = {teamCreator: {id}, url: topic.getUrl(), amount: 0, teammates: [], state: topic.team.getState()}
                        if creator
                            payment.teamCreator.email = creator.email
                            payment.teamCreator.name = creator.name
                        for participant in topic.participants
                            [time, participantAmount] = @_getParticipantAmount(startDate, endDate, participant)
                            payment.teammates.push({id: participant.id, amount: participantAmount, time: time})
                            payment.amount += participantAmount
                        continue if not payment.amount
                        regularAmount += payment.amount
                        payments.push(payment)
                    callback(null, {payments, regularAmount, totalTopicsCount, totalUsersCount})
                )
        ]
        async.waterfall(tasks, callback)

    _getParticipantAmount: (start, end, participant) ->
        actionLog = participant.actionLog
        time = 0
        len = actionLog.length-1
        return [0, 0] if len < 0
        for i in [0..len]
            #если на текущем интервале участник удален их топика, не берем его в рассмотрение
            continue if actionLog[i].action == ACTION_DELETE_FROM_TOPIC
            #end нхоодится либо внутри интервала, либо вне его
            localEnd = if i == len then end else Math.min(end, actionLog[i+1].date)
            #мы еще не дошли до интервала, который нам интересен
            continue if start > localEnd
            #start находится внури интервала
            localStart = Math.max(actionLog[i].date, start)
            continue if localStart > localEnd
            time += localEnd - localStart
            #дальше следуют более поздние интервалы, которые нас не интересуют, выйдем
            break if localEnd == end
        return [time, SUM_PER_USER * time / (end - start)]

    getTeamTopics: (user, attachParticipants=no, skipBlocked=no, callback) ->
        tasks = [
            async.apply(TeamCouchProcessor.getByTopicTypeAndUserIds, TOPIC_TYPES.TOPIC_TYPE_TEAM, user.getAllIds())
            (topics, callback) ->
                ids = []
                for topic in topics
                    if attachParticipants
                        ids = ids.concat((participant.id for participant in topic.getParticipantsWithRole(true)))
                    else
                        creator = topic.getTopicCreator()
                        continue if not creator
                        ids.push(creator.id)
                UserCouchProcessor.getByIdsAsDict(ids, (err, users) ->
                    callback(err, topics, users)
                )
            (topics, users, callback) ->
                ids = (topic.rootBlipId for topic in topics)
                CouchBlipProcessor.getByIdsAsDict(ids, (err, blips) ->
                    callback(err, topics, users, blips)
                )
            (topics, users, blips, callback) ->
                results = []
                regularParticipantCount = 0
                trialParticipantCount = 0
                debtParticipantCount = 0
                regularAmount = 0
                trialAmount = 0
                debtAmount = 0
                hasDebt = false
                allAllIsTrial = true
                for topic, i in topics
                    creator = users[topic.getTopicCreator()?.id]
                    continue if not creator
                    rootBlip = blips[topic.rootBlipId]
                    isOwnTopic = creator.isEqual(user)
                    amount = topic.team.getNextAmount(creator)
                    state = topic.team.getState()
                    if state == TEAM_STATES.TEAM_STATE_TRIAL and isOwnTopic
                        trialAmount += amount
                    if (state == TEAM_STATES.TEAM_STATE_DEBT or state == TEAM_STATES.TEAM_STATE_BLOCKED) and isOwnTopic
                        hasDebt = true
                        allAllIsTrial = false
                        debtAmount += amount
                    if state == TEAM_STATES.TEAM_STATE_PAYED and isOwnTopic
                        regularAmount += amount
                        allAllIsTrial = false
                    continue if skipBlocked and topic.team.isBlocked()
                    result =
                        url: topic.getUrl()
                        teamName: topic.getOptionByName('teamName') or "Team ##{i+1}"
                        isOwnTopic: isOwnTopic
                        name: creator.name or creator.email
                        avatar: creator.avatar
                        title: rootBlip?.getTitle()
                        snippet: rootBlip?.getSnippet()
                        state: topic.team.getState()
                        paidTill: topic.team.getPaidTill()
                        trialTill: topic.team.getTrialTill()
                        blockingDate: topic.team.getBlockingDate()
                        amount: amount
                    if attachParticipants
                        result.participants = []
                        err = topic.checkPermission(user, ACTION_FULL_PROFILE_ACCESS)
                        participants = topic.getParticipantsWithRole(true)
                        if state == TEAM_STATES.TEAM_STATE_TRIAL and isOwnTopic
                            trialParticipantCount += participants.length
                        if (state == TEAM_STATES.TEAM_STATE_DEBT or state == TEAM_STATES.TEAM_STATE_BLOCKED) and isOwnTopic
                            debtParticipantCount += participants.length
                        if state == TEAM_STATES.TEAM_STATE_PAYED and isOwnTopic
                            regularParticipantCount += participants.length
                        for participant in participants when users[participant.id]
                            infoUser = users[participant.id]
                            continue if not infoUser
                            infoItem = infoUser.toObject(not err)
                            infoItem.id = participant.id
                            result.participants.push(infoItem)
                    results.push(result)
                callback(null, {
                    topics: results
                    regularParticipantCount: regularParticipantCount
                    trialParticipantCount: trialParticipantCount
                    debtParticipantCount: debtParticipantCount
                    regularAmount: regularAmount
                    trialAmount: trialAmount
                    debtAmount: debtAmount
                    hasDebt: hasDebt
                    allAllIsTrial: allAllIsTrial
                })
        ]
        async.waterfall(tasks, callback)

    onAccountTypeSelected: (user) ->
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                action = (user, callback) ->
                    changed = user.setClientOption('isAccountTypeSelected', true)
                    callback(null, changed, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, callback)
        ]
        async.waterfall(tasks, (err) =>
            @_logger.error("Error while selected account type saving", {err: err, user: user.id}) if err
        )

module.exports.TeamController = new TeamController()
