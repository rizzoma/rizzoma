_ = require('underscore')
async = require('async')
Conf = require('../conf').Conf
OtError = require('./exceptions').OtError
OP_ALREADY_APPLIED = require('./exceptions').OP_ALREADY_APPLIED
DateUtils = require('../utils/date_utils').DateUtils
OperationCouchProcessor = require('./operation_couch_processor').OperationCouchProcessor
OtTransformer = require('./utils').OtTransformer

OP_ALREADY_APPLIED = require('./exceptions').OP_ALREADY_APPLIED
MAX_OP_AGE = 100
APPLY_RETRY_COUNT = 4

logger = Conf.getLogger('ot')

class OtProcessorBackend
    constructor: (@_documentProcessor) ->

    _applyOp: (doc, op, sendOldOps, channelId, callback) ->
        ###
        Применяет операцию к документу.
        Tip: use QueueOtProcessor.applyOp to apply operations sequentially.
        @param doc: Model
        @param op: OpModel
        @param sendOldOps: bool
        @param channelId: string
        @param callback: function
        ###
        return callback(new OtError('Op at future version'), null, null) if op.version > doc.version
        versionDelta = doc.version - op.version
        return callback(new OtError('Op too old'), null, null) if versionDelta > MAX_OP_AGE
        op.timestamp = DateUtils.getCurrentTimestamp()
        OperationCouchProcessor.getOpRange(doc.id, op.version, doc.version, (err, oldOps) =>
            return callback(err, null, null, []) if err
            return callback(new OtError('Ops count mismatch'), null, null, []) if oldOps.length != versionDelta
            #This operation already applyd, but client doesn't notified yet (course network problems, server fall or similar fuck up)
            if _.find(oldOps, (oldOp) -> oldOp.getRandom() == op.getRandom())
                err = new OtError("Op already applyed: #{op.id}", OP_ALREADY_APPLIED)
                return callback(err, null, op, [])
            err = op = OtTransformer.transformOp(op, oldOps)
            return callback(err, null, null, []) if err instanceof OtError
            err = doc = OtTransformer.transformDoc(doc, [op])
            return callback(err, null, null, []) if err instanceof OtError
            OperationCouchProcessor.save(op, (err) ->
                callback(err, doc, op, if versionDelta and sendOldOps then oldOps else [])
            )
        )

    _processBeforeOperation: (docId, op, callCount, callback) ->
        ###
        Retrieves document by id, executed before operation applied.
        @returns callback(err, doc, docClone, channelId)
        ###
        throw new Error('Method _processBeforeOperation is not implemented')

    _processAfterOperation: (doc, changeSet, changedFields, appliedOp, onOpApplied, oldOps, callback) ->
        ###
        Processes results of applied operation: saves modified document, etc.
        Executed after operation applied.
        @returns callback(err, doc)
        ###
        throw new Error('Method _processAfterOperation is not implemented')

    applyOp: (docId, op, callback, callCount=0) =>
        ###
        Add operation to the queue.
        @param docId: string
        @param op: OperationModel|function - operation or function that will be called with op(doc, callback) and should return callback(err, op)
        @param onOpApplied: function
        @param callback: function
        ###
        tasks = [
            async.apply(@_processBeforeOperation, docId, op, callCount)
            (doc, docClone, channelId, callback) ->
                if typeof(op) == 'function'
                    return op(doc, (err, op) ->
                        callback(err, doc, docClone, op, channelId)
                    )
                callback(null, doc, docClone, op, channelId)
            (doc, docClone, opToApply, channelId, callback) =>
                return callback(null, doc, docClone, null, null, [], false) if not opToApply
                @_applyOp(docClone, opToApply, !!callCount, channelId, (err, docClone, appliedOp, oldOps) ->
                    if err and err.code == OP_ALREADY_APPLIED
                        return callback(null, doc, changeSet, changedFields, appliedOp, oldOps, true)
                    return callback(err) if err
                    changedFields = OtTransformer.getOpsParam(appliedOp.op)
                    changeSet = {version: docClone.version}
                    for field in changedFields
                        changeSet[field] = docClone[field]
                    callback(err, doc, changeSet, changedFields, appliedOp, oldOps, false)
                )
            (doc, changeSet, changedFields, appliedOp, oldOps, alreadyApplied, callback) =>
                @_processAfterOperation(doc, changeSet, changedFields, appliedOp, oldOps, alreadyApplied, callback)
        ]
        async.waterfall(tasks, (err, channelId, doc, appliedOp, oldOps, alreadyApplied) =>
            return callback(new OtError('Save op retry count are exceeded')) if ++callCount > APPLY_RETRY_COUNT
            if err and (err.message == 'conflict' or err.message == 'Op at future version')
                logger.warn("Trying to fix ot error '#{err.message}', #{docId}", {docId, op, callCount})
                return @applyOp(docId, op, callback, callCount)
            callback(err, channelId, doc, appliedOp, oldOps, alreadyApplied)
        )

module.exports.OtProcessorBackend = OtProcessorBackend