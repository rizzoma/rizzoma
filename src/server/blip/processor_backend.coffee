_ = require('underscore')
BlipProcessor = require('./processor').BlipProcessorClass
AmqpBackendHelper = require('../ot/amqp_backend_helper').AmqpBackendHelper
OtProcessorBackend = require('../ot/processor_backend').OtProcessorBackend
BlipCouchConverter = require('./couch_converter').BlipCouchConverter
BlipOtConverter = require('./ot_converter').BlipOtConverter
IdUtils = require('../utils/id_utils').IdUtils
CouchBlipProcessor = require('./couch_processor').CouchBlipProcessor
UserCouchConverter = require('../user/couch_converter').UserCouchConverter
OperationModel = require('../ot/model').OperationModel

class BlipOtProcessorBackend extends OtProcessorBackend

    _processBeforeOperation: (blipId, op, callCount, callback) =>
        onBlipGot = (err, blip) ->
            return callback(err, null) if err
            channelId = IdUtils.parseId(blip.id).extensions
            callback(null, blip, BlipOtConverter.toOt(blip), channelId)
        @_documentProcessor.getBlip(blipId, onBlipGot, !!callCount)

    _processAfterOperation: (blip, changeSet, changes, op, oldOps, alreadyApplied, callback) =>
        channelId = IdUtils.parseId(blip.id).extensions
        return callback(null, channelId, @_modelToDoc(null, blip), op, oldOps, alreadyApplied) if not op or alreadyApplied
        action = (blip, changeSet, changes, callback) ->
            blip.version = changeSet.version if changeSet.version
            isChanged = blip.markAsChanged(changes, op.op, op.user)
            _.extend(blip, changeSet)
            callback(null, true, blip, isChanged)
        changes = @_documentProcessor._getOpsParam(blip, op.op)
        CouchBlipProcessor.saveResolvingConflicts(blip, action, changeSet, changes, (err) =>
            callback(err, channelId, @_modelToDoc(null, blip), op, oldOps, alreadyApplied)
        )

    _modelToDoc: (err, model) ->
        if err then null else BlipCouchConverter.toCouch(model)


class BlipProcessorBackend extends BlipProcessor
    constructor: () ->
        @_otProcessor = new BlipOtProcessorBackend(@)
        AmqpBackendHelper.addBackend(@)

    postOp: (args, callback) =>
        ###
        Применяет операцию без проставления флага removed блипам
        ###
        {blipId, ops, version, random, listenerId} = args
        contributor = if args.contributor then UserCouchConverter.toModel(args.contributor) else null
        operation = @_getOperation(blipId, contributor, ops, version, random, listenerId)
        @_otProcessor.applyOp(blipId, operation, callback)

    addContributorBlip: (args, callback) =>
        ###
        Добавляет редактора в блип и шлет операци.
        @param blip: BlipModel
        @param version: int
        @param contributor: UserModel
        @param callback: function
        ###
        {blipId} = args
        contributor = if args.contributor then UserCouchConverter.toModel(args.contributor) else null
        getOp = do(contributor) =>
            return (blip, callback) =>
                id = contributor.id
                return callback(null) if blip.hasContributor(contributor)
                op = {p: ['contributors', blip.contributors.length]}
                op.li = {id: id}
                callback(null, @_getOperation(blip.id, contributor, op, blip.version))
        @_otProcessor.applyOp(blipId, getOp, callback)

    _getOperation: (blipId, user, op, version, random, listenerId) ->
        idParts = [IdUtils.parseId(blipId).extensions, IdUtils.parseId(blipId).id]
        op = [op] if not _.isArray(op)
        operation = new OperationModel(idParts, blipId, version, op, user?.id)
        operation.listenerId = listenerId if listenerId
        operation.setRandom(random)
        return operation


module.exports =  new BlipProcessorBackend()