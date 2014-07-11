_ = require('underscore')
WaveProcessor = require('./processor').WaveProcessorClass
AmqpBackendHelper = require('../ot/amqp_backend_helper').AmqpBackendHelper
OtProcessorBackend = require('../ot/processor_backend').OtProcessorBackend
CouchWaveProcessor = require('./couch_processor').CouchWaveProcessor
OperationModel = require('../ot/model').OperationModel
IdUtils = require('../utils/id_utils').IdUtils
WaveOtConverter = require('./ot_converter').WaveOtConverter
WaveCouchConverter = require('./couch_converter').WaveCouchConverter
UserCouchConverter = require('../user/couch_converter').UserCouchConverter
ParticipantModel = require('./models').ParticipantModel

class WaveOtProcessorBackend extends OtProcessorBackend
    ###
    applyOp queue for wave: sequentially executes before action, applyOp, after action
    ###
    _processBeforeOperation: (waveUrl, op, callCount, callback) =>
        onWaveGot = (err, wave) ->
            return callback(err, null) if err
            channelId = IdUtils.parseId(wave.id).id
            callback(null, wave, WaveOtConverter.toOt(wave), channelId)
        @_documentProcessor.getWaveByUrl(waveUrl, onWaveGot, !!callCount)

    _processAfterOperation: (wave, changeSet, changes, op, oldOps, alreadyApplied, callback) ->
        channelId = IdUtils.parseId(wave.id).id
        return callback(null, channelId, @_modelToDoc(null, wave), op, oldOps, alreadyApplied) if not op or alreadyApplied
        action = (wave, changeSet, changes, callback) ->
            isChanged = wave.markAsChanged(changes)
            participants = changeSet.participants
            if participants
                for p, i in participants
                    participants[i] = new ParticipantModel(p.id, p.role, p.ptags, p.blockingState, p.actionLog)
            _.extend(wave, changeSet)
            callback(null, true, wave, isChanged)
        CouchWaveProcessor.saveResolvingConflicts(wave, action, changeSet, changes, (err) =>
            callback(err, channelId, @_modelToDoc(err, wave), op, oldOps, alreadyApplied)
        )

    _modelToDoc: (err, model) ->
        if err then null else WaveCouchConverter.toCouch(model)

class WaveProcessorBackend extends WaveProcessor
    constructor: () ->
        @_otProcessor = new WaveOtProcessorBackend(@)
        AmqpBackendHelper.addBackend(@)

    setSharedState: (args, callback) =>
        ###
        Устанавливает публичность/приватность волны
        ###
        {waveUrl, sharedState, defaultRole} = args
        user = if args.user then UserCouchConverter.toModel(args.user) else null
        getOp = do(user, sharedState, defaultRole) =>
            return (wave, callback) =>
                wave.getSetSharedStateOp(user, sharedState, defaultRole, (err, op) =>
                    callback(err, if err then null else @_getOperation(wave, op, user))
                )
        @_otProcessor.applyOp(waveUrl, getOp, callback)

    addParticipants: (args, callback) =>
        ###
        Добавляет участника в волну.
        @param waveId: string
        @param user: UserModel
        @param participant: string | User
        @param callback: function
        ###
        {waveUrl, role} = args
        user = if args.user then UserCouchConverter.toModel(args.user) else null
        participants = if args.participants then (UserCouchConverter.toModel(doc) for doc in args.participants) else []
        getOp = do(user, participants, role) =>
            return (wave, callback) =>
                wave.getAddParticipantsOp(user, participants, role, (err, op) =>
                    callback(err, if err then null else @_getOperation(wave, op, user))
                )
        @_otProcessor.applyOp(waveUrl, getOp, callback)

    deleteParticipants: (args, callback) =>
        ###
        Удаляет участника из волны.
        @param waveId: string
        @param user: UserModel
        @participant: string | User
        @param callback: function
        ###
        {waveUrl, ids} = args
        user = if args.user then UserCouchConverter.toModel(args.user) else null
        getOp = do(user, ids) =>
            return (wave, callback) =>
                wave.getDeleteParticipantsOp(user, ids, (err, op) =>
                    callback(err, if err then null else @_getOperation(wave, op, user))
                )
        @_otProcessor.applyOp(waveUrl, getOp, callback)

    changeParticipantsBlockingState: (args, callback) =>
        {waveUrl, participantIds, state} = args
        user = if args.user then UserCouchConverter.toModel(args.user) else null
        getOp = do(user, participantIds, state) =>
            return (wave, callback) =>
                wave.getChangeParticipantsBlockingStateOp(user, participantIds, state, (err, op) =>
                    callback(err, if err then null else @_getOperation(wave, op, user))
                )
        @_otProcessor.applyOp(waveUrl, getOp, callback)

    changeParticipantsRole: (args, callback) =>
        {waveUrl, participantIds, role} = args
        user = if args.user then UserCouchConverter.toModel(args.user) else null
        getOp = do(user, participantIds, role) =>
            return (wave, callback) =>
                wave.getChangeParticipantsRoleOp(user, participantIds, role, (err, op) =>
                    callback(err, if err then null else @_getOperation(wave, op, user))
                )
        @_otProcessor.applyOp(waveUrl, getOp, callback)

    processWaveGetting: (args, callback) =>
        {waveUrl} = args
        user = if args.user then UserCouchConverter.toModel(args.user) else null
        getOp = do(user) =>
            return (wave, callback) =>
                wave.getProcessWaveGettingOp(user, (err, op) =>
                    callback(err, if err then null else @_getOperation(wave, op, null))
                )
        @_otProcessor.applyOp(waveUrl, getOp, callback)

    _getOperation: (wave, op, user) ->
        return if not op
        id = IdUtils.parseId(wave.id).id
        userId = user?.id
        op = [op] if not _.isArray(op)
        return if not op.length
        return new OperationModel(id, wave.id, wave.version, op, userId)


module.exports = new WaveProcessorBackend()
