async = require('async')
WaveGenerator = require('./generator').WaveGenerator
BlipGenerator = require('../blip/generator').BlipGenerator
WaveProcessor = require('./processor').WaveProcessor
BlipProcessor = require('../blip/processor').BlipProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Conf = require('../conf').Conf
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
CouchWaveProcessor = require('./couch_processor').CouchWaveProcessor
WaveModel = require('./models').WaveModel
ParticipantModel = require('./models').ParticipantModel
BlipModel = require('../blip/models').BlipModel
WaveNotificator = require('./notificator').WaveNotificator

ROLES = require('./constants').ROLES
SHARED_STATES = require('./constants').SHARED_STATES
NON_BLOCKED = require('./constants').NON_BLOCKED
TOPIC_TYPES = require('./constants').TOPIC_TYPES

Ptag = require('../ptag').Ptag
ALL_PTAG_ID = Ptag.ALL_PTAG_ID
FOLLOW_PTAG_ID = Ptag.FOLLOW_PTAG_ID
UNFOLLOW_PTAG_ID = Ptag.UNFOLLOW_PTAG_ID

ACTION_ADD_TO_TOPIC = require('./constants').ACTION_ADD_TO_TOPIC

taskConsts = require('../task/constants')

{DateUtils} = require('../utils/date_utils')
BlipSearchController = require('../blip/search_controller').BlipSearchController
WELCOME_WAVE_SEARCH_TIMEOUT = 5 # будем искать welcome tpoic не более 5ти секнуд

class WelcomeWaveBuilder

    constructor: () ->
        @_logger = Conf.getLogger('welcome-wave-builder')

    getOrCreateWelcomeWaves: (user, callback) ->
        @_findWelcomeWave(user, (err, welcomeWave) =>
            return callback(err, null) if err
            return @createWelcomeWaves(user, callback) if not welcomeWave
            welcomeWaves = [welcomeWave]
            settings = Conf.get('welcomeWaves')
            return callback(null, welcomeWaves, true) if not settings or settings.length < 2
            @createWelcomeWave(user, settings[1], (err, faqWave) ->
                return callback(err, null) if err
                welcomeWaves.push(faqWave)
                callback(null, welcomeWaves, true)
            )
        )

    _findWelcomeWave: (user, callback) ->
        cancelTimeout = setTimeout () =>
            @_logger.error("Search welcome wave took too long")
            finish = callback
            callback = null
            finish(null, null)
        , WELCOME_WAVE_SEARCH_TIMEOUT * 1000
        BlipSearchController.searchBlips(user, "Our Groupwork Sandbox", "ALL", 0, (err, results) =>
            clearTimeout(cancelTimeout)
            return callback?(err, null) if err or not results or not results.searchResults.length
            callback?(null, results.searchResults[0])
        )

    createWelcomeWaves: (user, callback) ->
        wavesSettings = Conf.get('welcomeWaves')
        tasks = []
        for waveSettings in wavesSettings
            tasks.push do(waveSettings) =>
                return (callback) =>
                    @createWelcomeWave(user, waveSettings, callback)
        async.series(tasks, callback)

    createWelcomeWave: (user, waveSettings, callback) ->
        ###
        Создает приветственную волну для впервые авторизованного пользователя
        waveSettings:
            sourceWaveUrl: string - обязательный параметр, url топика-шаблона
            ownerUserEmail: string -хозяин топика, если не задан, будет влят user
            participants: [UserMOdel] - кого еще нужно добавить
            role: int - с какими правами добавлять других пользователей, по умолчанию комментаторы
            sharedState: int
            context: object - словарь содержащий значения, для замены в топике-шаблоне.
        ###
        tasks = [
            (callback) =>
                return callback(null, user) if not waveSettings.ownerUserEmail
                @_getWelcomeOwnerUser(waveSettings, callback)
            (supportUser, callback) =>
                @_getWelcomeTemplateWaveAndBlips(waveSettings, (err, templateWave, templateBlips) ->
                    return callback(err, null) if err
                    callback(null, supportUser, templateWave, templateBlips)
                )
            (supportUser, templateWave, templateBlips, callback) =>
                @_generateWelcomeIds(templateBlips, (err, waveId, blipIds) ->
                    return callback(err, null) if err
                    callback(null, supportUser, templateWave, templateBlips, waveId, blipIds)
                )
            (supportUser, templateWave, templateBlips, waveId, blipIds, callback) =>
                topicType = waveSettings.topicType
                waveOptions = waveSettings.waveOptions
                participants = [supportUser]
                if waveSettings.participants
                    participants = participants.concat(waveSettings.participants)
                else
                    participants.push(user)
                role = waveSettings.role
                sharedState = waveSettings.sharedState
                context = waveSettings.context
                @_composeWelcomeWaveAndBlips(context, topicType, waveOptions, waveSettings.ownerUserEmail, participants, role, sharedState, templateWave, templateBlips, waveId, blipIds, (err, welcomeWave, welcomeBlips) ->
                    return callback(err, null) if err
                    callback(null, welcomeWave, welcomeBlips, supportUser, participants)
                )
            (welcomeWave, welcomeBlips, supportUser, participants, callback) ->
                CouchBlipProcessor.bulkSave(welcomeBlips, (err, revs) ->
                    return callback(err, null) if err
                    for id, r of revs
                        return callback(err, null) if r.error
                    callback(null, welcomeWave, welcomeBlips, supportUser, participants)
                , true)
            (welcomeWave, welcomeBlips, supportUser, participants, callback) ->
                CouchWaveProcessor.save(welcomeWave,(err, revs) ->
                    return callback(err, null) if err
                    for id, r of revs
                        return callback(err, null) if r.error
                    callback(null, welcomeWave, welcomeBlips, supportUser, participants)
                , true)
            (welcomeWave, welcomeBlips, supportUser, participants, callback) =>
                rootBlip = @_findRootBlip(welcomeBlips)
                toNotificate = []
                for participant in participants
                    continue if participant.isEqual(user) or participant.isEqual(supportUser)
                    toNotificate.push(participant)
                if toNotificate.length
                    WaveNotificator.sendInvite(welcomeWave, supportUser, toNotificate, (err) =>
                        @_logger.error("Error while welcome wave notification sending", {err: err, sender: supportUser.id, wave: welcomeWave.id})
                    )
                callback(null, {
                    internalId: welcomeWave.id
                    waveId: welcomeWave.getUrl()
                    title: if rootBlip then rootBlip.getTitle() else 'Welcome to Rizzoma! '
                    snippet: if rootBlip then rootBlip.getSnippet() else 'Place cursor here and try to edit this sentence'
                    totalBlipCount: welcomeBlips.length
                    totalUnreadBlipCount: welcomeBlips.length
                    changeDate: Date.now()
                    name: supportUser.name or supportUser.email
                    avatar: supportUser.avatar
                    changed: yes
                })
        ]
        async.waterfall(tasks, callback)

    _findRootBlip: (blips) ->
        for blip in blips
            return blip if blip.isRootBlip
        console.error("Bugcheck. No root blip while creating welcome topic", blips)
        return null

    _getWelcomeOwnerUser: (waveSettings, callback) ->
        ###
        Загружает пользователя техподдержки, он будет создателем приветственного топика
        ###
        try
            ownerUserEmail = waveSettings.ownerUserEmail
        return callback(new Error("welcomeWave.ownerUserEmail does not set"), null) if not ownerUserEmail
        UserCouchProcessor.getByEmail(ownerUserEmail, callback)

    _getWelcomeTemplateWaveAndBlips: (waveSettings, callback) ->
        ###
        Загружает шаблон волны приветствия
        ###
        sourceWaveUrl = waveSettings.sourceWaveUrl
        return callback(new Error("welcomeWave.sourceWaveUrl does not set")) if not sourceWaveUrl
        tasks = [
            (callback) ->
                WaveProcessor.getWaveByUrl(sourceWaveUrl, callback)
            (templateWave, callback) ->
                BlipProcessor.getBlipsByWaveId(templateWave.id, (err, templateBlips) ->
                    return callback(err, null) if err
                    callback(null, templateWave, templateBlips)
                )
        ]
        async.waterfall(tasks, callback)

    _generateWelcomeIds: (templateBlips, callback) ->
        ###
        Генерит новые  id волны и блипов для топика приветствия
        ###
        tasks = [
            (callback) ->
                WaveGenerator.getNext(callback)
            (waveId, callback) ->
                BlipGenerator.getNextRange(waveId, templateBlips.length, (err, blipIds) ->
                    return callback(err, null) if err
                    blipIdsStructure = {}
                    for blip in templateBlips
                        blipIdsStructure[blip.id] = blipIds.pop()
                    callback(null, waveId, blipIdsStructure)
                )
        ]
        async.waterfall(tasks, callback)


    _composeWelcomeWaveAndBlips: (context, topicType, waveOptions, ownerUserEmail, participants, role, sharedState, templateWave, templateBlips, waveId, blipIds, callback) ->
        ###
        Создает на основе шаблона новую волну и блипы для топика приветствия
        ###
        welcomeWave = @_composeWelcomeWave(topicType, waveOptions, ownerUserEmail, participants, role, sharedState, templateWave, waveId, blipIds)
        welcomeBlips = @_composeWelcomeBlips(context, participants[0], participants[1], waveId, templateBlips, blipIds)
        callback(null, welcomeWave, welcomeBlips)

    _composeWelcomeWave: (topicType, waveOptions, ownerUserEmail, participants, role=ROLES.ROLE_PARTICIPANT, sharedState=SHARED_STATES.SHARED_STATE_LINK_PUBLIC, templateWave, waveId, blipIds) ->
        welcomeWave = new WaveModel()
        welcomeWave.id = waveId
        welcomeWave.topicType = topicType
        welcomeWave.setOptions(waveOptions)
        welcomeWave.rootBlipId = blipIds[templateWave.rootBlipId]
        welcomeWave.containerBlipId = blipIds[templateWave.containerBlipId]
        creator = null
        for user, i in participants
            isOwner = ownerUserEmail and user.isMyEmail(ownerUserEmail)
            if i==0 and topicType == TOPIC_TYPES.TOPIC_TYPE_TEAM
                welcomeWave.team.setTrialBalance(user)
            participant = new ParticipantModel(
                user.id
                if i == 0 then ROLES.ROLE_TOPIC_CREATOR else role
                if isOwner then [ALL_PTAG_ID, UNFOLLOW_PTAG_ID] else [ALL_PTAG_ID, FOLLOW_PTAG_ID]
                NON_BLOCKED
            )
            creator = participant if i == 0
            participant.addAction(creator, ACTION_ADD_TO_TOPIC)
            welcomeWave.participants.push(participant)
        welcomeWave.sharedState = sharedState
        return welcomeWave

    _numWithZero: (num) ->
        ###
        Дописывает 0 в начало если число меньше 10
        ###
        return (if num < 10 then '0' else '') + num

    _getWelcomeTemplateBlipContentPluginFragment: (m, context={}, params, supportUser, user) ->
        ###
        Возвращает в зависимости от m нужный фрагмент (меншен или задачу)
        - если в шаблон велкам топика написать *@* то в вэлкам топике поставится меншен на пользователя
        - если в шаблон велкам топика написать *~* то поставится задача без даты на чела, если *~+0*, то на сегодня, +1 на завтра и т.д.
        ###
        fr =
            t: ' '
            params:
                RANDOM: Math.random()
        if m == '*@*'
            fr.params.__TYPE = 'RECIPIENT'
            fr.params.__ID = user.id
        else if m == '*~*'
            fr.params.__TYPE = "TASK"
            fr.params.senderId = supportUser.id
            fr.params.recipientId = user.id
            fr.params.status = taskConsts.NOT_PERFORMED_TASK
            fr.params.lastSent = DateUtils.getCurrentTimestamp()
            fr.params.lastSenderId = supportUser.id
            days = m.match(/\d+/)
            if days and days.length
                days = parseInt(days[0])
                dd = new Date(Date.now() + 1000 * 60 * 60 * 24 * days)
                fr.params.deadlineDate = "#{dd.getFullYear()}-#{@_numWithZero(dd.getMonth()+1)}-#{@_numWithZero(dd.getDate())}"
        else
            m = m.replace(/\s?\*\s?/g, '')
            value = context[m]
            return if not value
            fr.t = value
            fr.params = params
        return fr

    _parseWelcomeTemplateBlipContentTextFragment: (fragment, context, supportUser, user) ->
        ###
        Разбирает текстовый фрагмент контента блипа велкам топика из шаблона и генерит соотвсетствующий/ие фрагменты
        ###
        content= []
        regEx = /\*(?:\@|(?:~(?:\+\d+)?)|(\s?[a-zA-Z0-9]+\s?))\*/
        m = fragment.t.match(regEx)
        while m and m.length
            index = fragment.t.indexOf(m[0])
            if index != 0
                frt =
                    t: fragment.t.substr(0, index)
                    params: fragment.params
                content.push(frt)
            fr = @_getWelcomeTemplateBlipContentPluginFragment(m[0], context, fragment.params, supportUser, user)
            content.push(fr) if fr
            fragment.t = fragment.t.substr(index + m[0].length)
            m = fragment.t.match(regEx)
        if fragment.t.length
            content.push(fragment)
        return content

    _parseWelcomeTemplateBlipContentFragment: (fragment, context, supportUser, user, blipIds) ->
        ###
        Разбирает фрагмент контента блипа велкам топика из шаблона и генерит соотвсетствующий/ие фрагменты
        ###
        content = []
        if fragment.params.__TYPE == "TEXT"
            content = content.concat(@_parseWelcomeTemplateBlipContentTextFragment(fragment, context, supportUser, user))
        else
            if fragment.params.__TYPE == "BLIP"
                fragment.params.__ID = blipIds[fragment.params.__ID]
                if fragment.params.__THREAD_ID and blipIds[fragment.params.__THREAD_ID]
                    fragment.params.__THREAD_ID = blipIds[fragment.params.__THREAD_ID]
            content.push(fragment)
        return content

    _composeWelcomeBlipContent: (context, supportUser, user, templateBlip, blipIds) ->
        ###
        Копирует контент блипа велкам топика из шаблона
        ###
        content = []
        for fragment in templateBlip.content
            content = content.concat(@_parseWelcomeTemplateBlipContentFragment(fragment, context, supportUser, user, blipIds))
        return content

    _fillBlipPluginData: (blip, supportUser) ->
        ###
        костыль чтобы проставить lastSent для меншенов в вэлкам топике
        ###
        for fr in blip.content
            if fr.params.__TYPE == 'RECIPIENT'
                blip.pluginData.message =
                    lastSent: DateUtils.getCurrentTimestamp()
                    lastSenderId: supportUser.id if supportUser
                return

    _composeWelcomeBlip: (context, supportUser, user, waveId, templateBlip, blipIds) ->
        ###
        Копирует блип велкам топика из шаблона
        ###
        blip = new BlipModel()
        blip.id = blipIds[templateBlip.id]
        blip.removed = false
        blip.waveId = waveId
        blip.isRootBlip = templateBlip.isRootBlip
        blip.isContainer = templateBlip.isContainer
        blip.contributors.push({id: supportUser.id})
        blip.readers[supportUser.id] = blip.contentVersion
        blip.isFoldedByDefault = templateBlip.isFoldedByDefault
        blip.pluginData = templateBlip.pluginData
        blip.content = @_composeWelcomeBlipContent(context, supportUser, user, templateBlip, blipIds)
        @_fillBlipPluginData(blip, supportUser)
        return blip

    _composeWelcomeBlips: (context, supportUser, user, waveId, templateBlips, blipIds) ->
        ###
        Копирует блипы велкам топика из шаблонов
        ###
        welcomeBlips = []
        for templateBlip in templateBlips
            blip = @_composeWelcomeBlip(context, supportUser, user, waveId, templateBlip, blipIds)
            welcomeBlips.push(blip)
        return welcomeBlips

module.exports.WelcomeWaveBuilder = new WelcomeWaveBuilder()