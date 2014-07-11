_ = require('underscore')
async = require('async')
WaveError = require('./exceptions').WaveError
WaveModel = require('./models').WaveModel
ParticipantModel = require('./models').ParticipantModel
WaveGenerator = require('./generator').WaveGenerator
CouchWaveProcessor = require('./couch_processor').CouchWaveProcessor
OtProcessorFrontend = require('../ot/processor_frontend').OtProcessorFrontend
AmqpFrontendHelper = require('../ot/amqp_frontend_helper').AmqpFrontendHelper
WaveCouchConverter = require('./couch_converter').WaveCouchConverter
UserCouchConverter = require('../user/couch_converter').UserCouchConverter

Ptag = require('../ptag').Ptag

WAVE_DOCUMENT_DOES_NOT_EXISTS = require('./exceptions').WAVE_DOCUMENT_DOES_NOT_EXISTS
WAVE_NO_ANOTHER_MODERATOR = require('./exceptions').WAVE_NO_ANOTHER_MODERATOR

ROLE_TOPIC_CREATOR = require('./constants').ROLE_TOPIC_CREATOR
ROLE_EDITOR = require('./constants').ROLE_EDITOR

ACTION_ADD_TO_TOPIC = require('./constants').ACTION_ADD_TO_TOPIC

NON_BLOCKED = require('./constants').NON_BLOCKED

ALL_PTAG_ID = Ptag.ALL_PTAG_ID
FOLLOW_PTAG_ID = Ptag.FOLLOW_PTAG_ID

class WaveProcessor
    constructor: () ->

    createWave: (id, user, rootBlipId, containerBlipId, options, callback) ->
        ###
        Создает волну
        @param id: string
        @param user: UserModel
        @param rootBlipId: string
        @param containerBlipId: string
        @param options.participants: array
        @param callback: function
        ###
        tasks = [
            (callback) ->
                return callback(null, id) if id
                WaveGenerator.getNext(callback)
            (id, callback) =>
                @_saveCreatedWave(id, user, rootBlipId, containerBlipId, options, callback)
        ]
        async.waterfall(tasks, callback)

    _saveCreatedWave: (id, user, rootBlipId, containerBlipId, options, callback) ->
        options = _.defaults(options, { participants: [] })
        wave = new WaveModel()
        wave.id = id
        wave.rootBlipId = rootBlipId
        wave.containerBlipId = containerBlipId
        creator = new ParticipantModel(user.id, ROLE_TOPIC_CREATOR, [ALL_PTAG_ID, FOLLOW_PTAG_ID], NON_BLOCKED)
        creator.addAction(user, ACTION_ADD_TO_TOPIC)
        wave.participants.push(creator)
        for participant in options.participants
            continue if  user.isEqual(participant.id) #по идее итак должно быть без дублей, но на всякий
            participant.role = ROLE_EDITOR if participant.role == ROLE_TOPIC_CREATOR
            participant.flushActions()
            participant.addAction(user, ACTION_ADD_TO_TOPIC)
            wave.participants.push(participant)
        if options.gDriveId
            wave.gDriveId = options.gDriveId
            wave.gDrivePermissions = options.gDrivePermissions
        CouchWaveProcessor.save(wave, (err) ->
            callback(err, if err then null else wave.getUrl())
        )

    setWaveFollowState: (wave, user, state, callback) ->
        ###
        Проставляет тэг follow/unfollow волне для данного пользователя.
        Удаляет один тэг, если есть и ставит второй.
        Если пользователя нет - добавляет его с провами поумолчанию.
        @param wave: WaveModel
        @param userId: string
        @param state: bool
        @param callback: function
        ###
        tasks = [
            (callback) =>
                return callback(null, wave) if wave.hasParticipant(user, true)
                @addParticipants(wave.getUrl(), user, [user], null, callback)
            (wave, callback) ->
                action = (wave, user, state, callback) ->
                    needSave = needIndex = wave.setParticipantFollowState(user, state)
                    callback(null, needSave, wave, needIndex)
                CouchWaveProcessor.saveResolvingConflicts(wave, action, user, state, callback)
        ]
        async.waterfall(tasks, callback)

    getWave: (waveId, callback, needCatchup) =>
        ###
        Получает снэпшот волны, в коллбэк вернет модель либо ошибку.
        @param waveId: string
        @param callback: function
        ###
        onWaveGot = (err, wave) =>
            @_onWaveGot(err, wave, callback)
        CouchWaveProcessor.getById(waveId, onWaveGot, needCatchup)

    getWaveByUrl: (url, callback, needCatchup) =>
        onWaveGot = (err, wave) =>
            @_onWaveGot(err, wave, callback)
        CouchWaveProcessor.getByUrl(url, onWaveGot, needCatchup)

    getWaveByGDriveId: (gDriveDocId, callback, needCatchup) =>
        onWaveGot = (err, wave) =>
            @_onWaveGot(err, wave, callback)
        CouchWaveProcessor.getByGDriveId(gDriveDocId, onWaveGot, needCatchup)

    _docToModel: (callback) ->
        return (err, doc) -> callback(err, if err then null else WaveCouchConverter.toModel(doc))

    _getId: (url) -> url[0]

    setSharedState: (waveUrl, user, sharedState, defaultRole, callback) ->
        ###
        Устанавливает публичность/приватность волны
        ###
        args = {waveUrl, sharedState, defaultRole}
        args.user = UserCouchConverter.toCouch(user) if user
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('setSharedState', @_getId(waveUrl), args)

    addParticipants: (waveUrl, user, participants, role, callback) =>
        ###
        Добавляет участника в волну.
        @param waveId: string
        @param user: UserModel
        @param participant: string | User
        @param callback: function
        ###
        args = {waveUrl, role}
        args.user = UserCouchConverter.toCouch(user) if user
        if participants
            args.participants = (UserCouchConverter.toCouch(model) for model in participants)
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('addParticipants', @_getId(waveUrl), args)

    deleteParticipants: (waveUrl, user, ids, callback) =>
        ###
        Удаляет участника из волны.
        @param waveId: string
        @param user: UserModel
        @participant: string | User
        @param callback: function
        ###
        args = {waveUrl, ids}
        args.user = UserCouchConverter.toCouch(user)
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('deleteParticipants', @_getId(waveUrl), args)

    setSocialSharing: (wave, isSharing, callback) ->
        action = (wave, args, callback) ->
            wave.sharedToSocial = isSharing
            if isSharing
                wave.sharedToSocialTime = new Date().getTime()
            callback(null, true, wave, false)
        CouchWaveProcessor.saveResolvingConflicts(wave, action, null, callback)

    subscribe: (waveId, versions, listenerId, listener, clientDocId) ->
        return OtProcessorFrontend.subscribeChannel(waveId, versions, listenerId, listener, clientDocId)

    fillChannel: (waveId, listenerId, versions, actualVersions) ->
        OtProcessorFrontend.fillChannel(waveId, listenerId, versions, actualVersions)

    unsubscribe: (waveId, listenerId) ->
        OtProcessorFrontend.unsubscribeFromChannel(waveId, listenerId)

    changeParticipantsBlockingState: (waveUrl, user, participantIds, state, callback) ->
        args = {waveUrl, participantIds, state}
        args.user = UserCouchConverter.toCouch(user) if user
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('changeParticipantsBlockingState', @_getId(waveUrl), args)

    changeParticipantsRole: (waveUrl, user, participantIds, role, callback) ->
        args = {waveUrl, participantIds, role}
        args.user = UserCouchConverter.toCouch(user) if user
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('changeParticipantsRole', @_getId(waveUrl), args)

    processWaveGetting: (waveUrl, user, callback) =>
        args = {waveUrl}
        args.user = UserCouchConverter.toCouch(user) if user
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('processWaveGetting', @_getId(waveUrl), args)

    processBlipAccess: (wave, user, action, callback) ->
        return callback(null) if not wave.isBlipAccessAddsParticipant(user, action)
        @addParticipants(wave.getUrl(), user, [user], null, (err) ->
            callback(err)
        )

    _onWaveGot: (err, wave, callback) ->
        if err and err.message == 'not_found'
            err = new WaveError('Requested topic not found', WAVE_DOCUMENT_DOES_NOT_EXISTS)
        callback(err, if err then null else wave)

    addWaveGDrivePermission: (wave, user, gDrivePermissionId, callback) ->
        permissions = wave.gDrivePermissions[user.id]
        if permissions and permissions.indexOf(gDrivePermissionId) != -1
            return callback(null)
        action = (wave, args, callback) ->
            permissions = wave.gDrivePermissions[user.id] || []
            if permissions.indexOf(gDrivePermissionId) == -1
                permissions.push(gDrivePermissionId)
            wave.gDrivePermissions[user.id] = permissions
            callback(null, true, wave, false)
        CouchWaveProcessor.saveResolvingConflicts(wave, action, null, callback)

module.exports =
    WaveProcessor: new WaveProcessor()
    WaveProcessorClass: WaveProcessor
