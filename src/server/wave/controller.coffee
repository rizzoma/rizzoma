_ = require('underscore')
async = require('async')
WaveGenerator = require('./generator').WaveGenerator
WaveProcessor = require('./processor').WaveProcessor
WaveOtConverter = require('./ot_converter').WaveOtConverter
BlipProcessor = require('../blip/processor').BlipProcessor
BlipOtConverter = require('../blip/ot_converter').BlipOtConverter
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
Conf = require('../conf').Conf
IdUtils = require('../utils/id_utils').IdUtils
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
ContactsController = require('../contacts/controller').ContactsController
WaveNotificator = require('./notificator').WaveNotificator

WaveError = require('./exceptions').WaveError
WAVE_PERMISSION_DENIED = require('./exceptions').WAVE_PERMISSION_DENIED
WAVE_PARTICIPANT_ALREADY_IN = require('./exceptions').WAVE_PARTICIPANT_ALREADY_IN
NEED_MERGE_ERROR_CODE = require('../../share/constants').NEED_MERGE_ERROR_CODE

ROLES = require('./constants').ROLES
SHARED_STATES = require('./constants').SHARED_STATES
ACTIONS = require('./constants').ACTIONS

CREATION_REASON_ADD = require('../user/constants').CREATION_REASON_ADD
DbError = require('../common/db/exceptions').DbError

class WaveController
    constructor: () ->
        @_logger = Conf.getLogger('wave-controller')

    createWave: (user, callback) ->
        tasks = [
            async.apply(@_checkForCreationPermissions, user)
            async.apply(@_createWave, user, {})
        ]
        async.waterfall(tasks, callback)

    createWaveWithParticipants: (url, participantIds, user, callback) ->
        ###
        Замена для createWaveWithEveryoneHere
        Создает волну со списком участников, из множества учасников (с ролями) волны с url.
        Перемещает инициатора создания на первое место в списке участников.
        @param url: string
        @param participantIds: array - список id участников, которые должны быть в созданной волне.
        @param user: UserModel
        @param callback: function
        ###
        WaveProcessor.getWaveByUrl(url, (err, wave) =>
            callback(err) if err
            err = wave.checkPermission(user, ACTIONS.ACTION_ADD_TO_TOPIC)
            return callback(err) if err
            participantsToAdd = []
            for id in participantIds
                [participant, index] = wave.getParticipantById(id)
                continue if not participant or participant.role == ROLES.ROLE_NO_ROLE
                participantsToAdd.push(participant)
            @_createWave(user, {participants: participantsToAdd}, callback)
        )

    createWaveByWizard: (user, emails=[], title, role, needNotificate, callback) ->
        ###
        Создает топик заголовком title, добавляя в него участников emails (прии необходимости создастся пользователь).
        @param user: UserModel
        @params: emails: array
        @param title: string
        @param callback: function
        ###
        tasks = [
            async.apply(@_checkForCreationPermissions, user)
            async.apply(@_createWave, user, {title})
            (url, callback) =>
                @addParticipantsEx(url, user, emails, role, needNotificate, (err) ->
                    err = null if err and err.code == WAVE_PARTICIPANT_ALREADY_IN
                    callback(err, if err then null else url)
                )
        ]
        async.waterfall(tasks, callback)

    createWaveByGDrive: (user, gDriveDocId, gDrivePermissionId, title, callback) ->
        drivePermissions = {}
        drivePermissions[user.id] = [gDrivePermissionId]
        tasks = [
            async.apply(@_checkForCreationPermissions, user)
            async.apply(@_createWave, user, {title, gDriveId: gDriveDocId, gDrivePermissions: drivePermissions})
        ]
        async.waterfall(tasks, callback)

    _checkForCreationPermissions: (user, callback) =>
        err = null
        if user.isAnonymous()
            err = new WaveError("Anonymous can't create waves", WAVE_PERMISSION_DENIED)
        callback(err)

    _createWave: (user, options, callback) =>
        ###
        @param user: UserModel
        @param options: {participants, title, gDriveId, gDrivePermissions}
        ###
        options = _.defaults(options, { participants: [], title: '' })
        tasks = [
            async.apply(WaveGenerator.getNext)
            (waveId, callback) ->
                BlipProcessor.createRootBlip(waveId, user, options.title, (err, rootBlipId) ->
                    callback(err, waveId, rootBlipId)
                )
            (waveId, rootBlipId, callback) ->
                BlipProcessor.createContainerBlip(waveId, user, rootBlipId, (err, containerBlipId) ->
                    callback(err, waveId, rootBlipId, containerBlipId)
                )
            (waveId, rootBlipId, containerBlipId, callback) ->
                WaveProcessor.createWave(waveId, user, rootBlipId, containerBlipId, options, callback)
        ]
        async.waterfall(tasks, (err, waveId) ->
            callback(err, waveId)
        )

    getWaveByUrlEx: (url, user, referalEmailHash, callback) =>
        ###
        Открывает волну, для расшаренных по ссылке добавляет участника.
        @param waveId: string
        @param user: UserModel
        @param referalEmailHash: string
        @param callback: function
        ###
        WaveProcessor.processWaveGetting(url, user, (err, wave) =>
            err = wave.checkPermission(user, ACTIONS.ACTION_READ) if wave
            return callback(err, wave) if not (err and err.code == WAVE_PERMISSION_DENIED and referalEmailHash)
            # Return NEED_MERGE error when signed in user has no access to topic but URL from email notification used
            # to open the topic and recipient of this notification (identified by referralEmailHash)
            # should have access. "Merge accounts to access this topic" prompt will be shown to the user.
            participantId = wave.getParticipantIdByReferalEmailHash(referalEmailHash)
            return callback(err, wave) if not participantId
            UserCouchProcessor.getById(participantId, (gotUsersErr, participant) ->
                return callback(gotUsersErr) if gotUsersErr
                callback(new WaveError(participant.email, NEED_MERGE_ERROR_CODE))
            )
        )

    getWaveByUrl: (url, user, callback) =>
        ###
        открывает волну.
        @param url: string
        @param user: UserModel
        @param callback: function
        ###
        WaveProcessor.getWaveByUrl(url, (err, wave) ->
            return callback(err) if err
            err = wave.checkPermission(user, ACTIONS.ACTION_READ)
            callback(err, if err then null else wave)
        )


    markWaveAsSocialSharing: (url, user, callback) ->
        ###
        Выставляет параметр sharedToSocial у волны url в true
        @param url: String url волны
        @param user: UserModel
        @param callback: function
        ###
        @getWaveByUrl(url, user, (err, wave) ->
            return callback(err, null) if err
            WaveProcessor.setSocialSharing(wave, true, callback)
        )

    getWaveWithBlipsByUrl: (url, user, referalEmailHash, callback) ->
        ###
        Загружает волну и все блипы.
        @param url: string
        @param user: UserModel
        @param referalEmailHash: string
        @param callback: function
        ###
        tasks = [
            async.apply(@getWaveByUrlEx, url, user, referalEmailHash)
            (wave, callback) ->
                result =
                    wave: wave
                    blips: []
                    errors: {}
                BlipProcessor.getBlipsByWaveId(wave.id, (err, blips) ->
                    return callback(err, null) if err
                    for blip in blips
                        blip.setWave(wave)
                        err = blip.checkPermission(user, ACTIONS.ACTION_READ)
                        if err
                            result.errors[blip.id] = err
                        else
                            result.blips.push(blip)
                    callback(null, result)
                )
        ]
        async.waterfall(tasks, callback)

    getClientWaveWithBlipsByUrl: (url, user, referalEmailHash, callback) ->
        ###
        Загружает волну и все блипы. Возвращает данные в формате, которого требует клиент.
        @param url: string
        @param user: UserModel
        @param referalEmailHash: string
        @param callback: function
        ###
        @getWaveWithBlipsByUrl(url, user, referalEmailHash, (err, data) ->
            return callback(err, null) if err
            {wave, blips} = data
            data.wave = WaveOtConverter.toClient(wave)
            data.blips = (BlipOtConverter.toClient(blip, user) for blip in blips)
            callback(null, data)
        )

    subscribeWaveWithBlips: (subscriptionInfo, user, listenerId, listener, callback) ->
        waveInfo = subscriptionInfo.wave
        blipsInfo = subscriptionInfo.blips
        versions = _.extend({}, blipsInfo)
        tasks = [
            async.apply(WaveProcessor.getWaveByUrl, waveInfo.id)
            (wave, callback) =>
                err = wave.checkPermission(user, ACTIONS.ACTION_READ)
                return callback(err) if err
                waveId = wave.id
                versions[waveId] = waveInfo.version
                channelId = IdUtils.parseId(waveId).id
                return callback(null) if not WaveProcessor.subscribe(channelId, versions, listenerId, listener, wave.getUrl())
                BlipProcessor.getVersionByIds(_.keys(blipsInfo), (err, actualVersions) =>
                    return callback(err) if err
                    actualVersions[waveId] = wave.version
                    WaveProcessor.fillChannel(channelId, listenerId, versions, actualVersions)
                    callback(null)
                )
        ]
        async.waterfall(tasks, callback)

    unsubscribeWaveWithBlips: (url, user, listenerId, callback) ->
        WaveProcessor.getWaveByUrl(url, (err, wave) ->
            return callback(err) if err
            callback(null)
            waveId = IdUtils.parseId(wave.id).id
            WaveProcessor.unsubscribe(waveId, listenerId)
        )

    addParticipantsEx: (url, user, emails, role, needNotificate, callback) ->
        ###
        Добавляет в топик участников по списку emails, при необходимости создает и отправляет уведомления.
        @param url: string
        @param user: UserModel
        @param emails: array
        @param role: int
        @param callback: function
        ###
        return callback(null) if not emails.length
        @_addParticipantsExWithoutNotification(url, user, emails, role, (err, wave, participants, alreadyIn) =>
            return callback(err) if err
            callback(null, (participant.toObject(true) for participant in participants))
            return if alreadyIn or not needNotificate
            WaveNotificator.sendInvite(wave, user, participants, (err) =>
                @_logger.warn("Add to topic notification sending error: ", {err: err, userId: user.id}) if err
            )
        )

    _addParticipantsExWithoutNotification: (url, user, emails, role, callback) ->
        ###
        Добавляет в топик участников по списку emails.
        возвращает: топик, загруженный участников, и добавлен ли уже
        ###
        return callback(null) if not emails.length
        tasks = [
            async.apply(UserCouchProcessor.getOrCreateByEmails, emails, CREATION_REASON_ADD)
            (participants, callback) =>
                participants = _.values(participants)
                @addParticipants(url, user, participants, role, (err, wave) =>
                    alreadyIn = false
                    if err
                        return callback(err, null, null, null) if err.code != WAVE_PARTICIPANT_ALREADY_IN
                        alreadyIn = true
                    participantsToAdd = (participant for participant in participants when not user.isEqual(participant))
                    callback(null, wave, participantsToAdd, alreadyIn)
                    return if alreadyIn
                    # Не получится использовать сразу addEachOther(user, usersToAdd, callback), т.к. в объекте user есть не все поля, не получится выполнить user.toContact()
                    ContactsController.addEachOtherUsingId(user.id, participantsToAdd, (err) =>
                        @_logger.warn("Error while adding to contacts: ", {err: err, userId: user.id}) if err
                    )
                    return if not wave.isTeamTopic()
                    #Добавляемым в team-topic (команду) пользователям нужно дать бонус
                    action = (participant, url, callback) ->
                        [err, changed] = participant.setTeamBonus(url)
                        callback(err, changed, participant, false)
                    UserCouchProcessor.bulkSaveResolvingConflicts(participantsToAdd, action, url, (err) =>
                        @_logger.error("Error while adding team user", {err: err, userId: user.id}) if err
                    )
                )
        ]
        async.waterfall(tasks, callback)

    addParticipantEx: (url, user, email, role, needNotificate, callback) ->
        ###
        Алиас для @addParticipantsEx
        @param url: string
        @param user: UserModel
        @param email: string
        @param callback: function
        ###
        @addParticipantsEx(url, user, [email], role, needNotificate, (err, participants) ->
            return callback(err) if err
            callback(null, if participants.length then participants[0] else participants)
        )

    addParticipants: (url, user, participants, role, callback) ->
        ###
        Добавляет участников в волну.
        @param url: string
        @param user: UserModel
        @param participants: array
        @param callback: function
        ###
        WaveProcessor.addParticipants(url, user, participants, role, callback)

    addParticipant: (url, user, participant, role, callback) ->
        ###
        Алиас для @addParticipants.
        @param url: string
        @param user: UserModel
        @param participant: UserModel
        @param callback: function
        ###
        @addParticipants(url, user, [participant], role, (err, participants) ->
            return callback(err) if err
            callback(null, if participants.length then participants[0] else participants)
        )

    deleteParticipants: (url, user, ids, callback) ->
        ###
        Удаляет участника из волны.
        @param waveId: string
        @param user: UserModel
        @participant: string | User
        @param callback: function
        ###
        WaveProcessor.deleteParticipants(url, user, ids, (err, wave) ->
            callback(err, wave)
            return if err or not wave.isTeamTopic()
            #Пори удалении из team-topica-а (команды) нужно отобрать бонус
            UserCouchProcessor.getByIds(ids, (err, participants) =>
                return @_logger.error("Error while deleting team user", {err: err, userId: user.id}) if err
                action = (participant, url, callback) ->
                    [err, changed] = participant.unsetTeamBonus(url)
                    callback(err, changed, participant, false)
                UserCouchProcessor.bulkSaveResolvingConflicts(participants, action, url, (err) =>
                    @_logger.error("Error while deleting team user", {err: err, userId: user.id}) if err
                )
            )
        )

    setSharedState: (url, user, sharedState, defaultRole, callback) ->
        ###
        Устанавливает публичность волны и генерит опу опопвещая всех об этом
        ###
        WaveProcessor.setSharedState(url, user, sharedState, defaultRole, callback)

    setWaveFollowState: (url, user, state, callback) ->
        ###
        Проставляет тэг follow/unfollow волне для данного пользователя.
        @param url: string
        @param user: UserModel
        @param state: bool
        @param callback: function
        ###
        tasks = [
            async.apply(WaveProcessor.getWaveByUrl, url)
            (wave, callback) ->
                WaveProcessor.setWaveFollowState(wave, user, state, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err)
        )

    updateReaderForAllBlips: (url, user, callback) ->
        ###
        Прочитывает все непрочтенные блипы в топике.
        @param url: string
        @param user: UserModel
        @param callback: function
        ###
        tasks = [
            async.apply(WaveProcessor.getWaveByUrl, url)
            (wave, callback) ->
                err = wave.checkPermission(user, ACTIONS.ACTION_READ)
                callback(err, wave)
            (wave, callback) ->
                BlipProcessor.getBlipsByWaveId(wave.id, callback)
            (blips, callback) ->
                action = (blip, readerId, callback) ->
                    needSave = blip.markAsRead(readerId)
                    callback(null, needSave, blip, false)
                CouchBlipProcessor.bulkSaveResolvingConflicts(blips, action, user.id, callback)
        ]
        async.waterfall(tasks, callback)

    changeParticipantsBlockingState: (url, user, participantIds, state, callback) ->
        WaveProcessor.changeParticipantsBlockingState(url, user, participantIds, state, callback)

    changeParticipantsRole: (url, user, participantIds, role, callback) ->
        WaveProcessor.changeParticipantsRole(url, user, participantIds, role, callback)

    getWaveByGDriveId: (gDriveDocId, callback) ->
        ###
        открывает волну.
        @param gDriveId: string
        @param callback: function
        ###
        WaveProcessor.getWaveByGDriveId(gDriveDocId, (err, wave) ->
            return callback(err) if err
            callback(null, wave)
        )

    addWaveGDrivePermission: (wave, user, gDrivePermissionId, callback) ->
        WaveProcessor.addWaveGDrivePermission(wave, user, gDrivePermissionId, callback)

exports.WaveController = new WaveController()
