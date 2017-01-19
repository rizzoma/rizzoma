_ = require('underscore')
async = require('async')
BlipModel = require('./models').BlipModel
BlipError = require('./exceptions').BlipError
BlipGenerator = require('./generator').BlipGenerator
CouchBlipProcessor = require('./couch_processor').CouchBlipProcessor
DateUtils = require('../utils/date_utils').DateUtils
BlipCouchConverter = require('./couch_converter').BlipCouchConverter
UserCouchConverter = require('../user/couch_converter').UserCouchConverter
OtProcessorFrontend = require('../ot/processor_frontend').OtProcessorFrontend
AmqpFrontendHelper = require('../ot/amqp_frontend_helper').AmqpFrontendHelper
OtTransformer = require('../ot/utils').OtTransformer

BLIP_DOCUMENT_DOES_NOT_EXISTS = require('./exceptions').BLIP_DOCUMENT_DOES_NOT_EXISTS
INVALID_ENQUIRY_BLIP_ID = require('./exceptions').INVALID_ENQUIRY_BLIP_ID

INLINE_INSERTATION = require('./constants').INLINE_INSERTATION
INLINE_DELETION = require('./constants').INLINE_DELETION

class BlipProcessor
    constructor: () ->

    createBlip: (waveId, author, contributors=[], content, isRootBlip=no, isContainer=no, isFoldedByDefault=no, removed=yes, pluginData={}, needNotificate=yes, callback) =>
        ###
        Создает документ блипа и инициализирует его первоначальной структурой
        @param waveId: string
        @param author: UserModel
        @param contributors: array
        @param content: array or string
        @param isRootBlip: bool
        @param isContainer: bool
        @param isFoldedByDefault: bool
        @param removed: bool
        @param callback: function
        ###
        formattedContent = [{t: ' ', params: {__TYPE: 'LINE', RANDOM: Math.random()}}]
        formattedContent.push({t: content, params: {__TYPE: 'TEXT'}})  if _.isString(content) and content.length
        formattedContent = content if _.isArray(content) and content.length
        tasks = [
            async.apply(BlipGenerator.getNext, waveId)
            (id, callback) =>
                blip = new BlipModel()
                blip.id = id
                blip.waveId = waveId
                @_initContributors(blip, author, contributors)
                blip.readers[author.id] = blip.contentVersion
                blip.content = formattedContent
                blip.isRootBlip = isRootBlip
                blip.needNotificate = not isRootBlip and not isContainer and needNotificate
                blip.isContainer = isContainer
                blip.isFoldedByDefault = isFoldedByDefault
                blip.removed = removed
                blip.pluginData = pluginData
                CouchBlipProcessor.save(blip, (err) ->
                    callback(err, if err then null else id)
                )
        ]
        async.waterfall(tasks, callback)

    createRootBlip: (waveId, user, title, callback) ->
        ###
        Создает корневой блипп.
        @param waveId: string - в какой волне
        @param user: UserModel
        @param title: string
        @param callback: function
        ###
        @createBlip(waveId, user, null, title, yes, no, no, no, null, no, callback)

    _getContainerBlipContent: (rootBlipId) ->
        return [
            {t: ' ', params: {__TYPE: 'LINE'}}
            {t: ' ', params: {__TYPE: 'BLIP', __ID: rootBlipId, RANDOM: Math.random()}}
        ]

    createContainerBlip: (waveId, user, rootBlipId, callback) ->
        ###
        Создает блипп-контейнер.
        @param waveId: string - в какой волне
        @param user: UserModel
        @param rootBlipId: string - id корневого блипа для вставки в контейнер
        @param callback: function
        ###
        content = @_getContainerBlipContent(rootBlipId)
        @createBlip(waveId, user, null, content, no, yes, no, no, null, no, callback)

    getContainerModel: (id, waveId, rootBlipId, user) ->
        blip = new BlipModel(id)
        blip.content = @_getContainerBlipContent(rootBlipId)
        blip.waveId = waveId
        @_initContributors(blip, user, [])
        blip.readers[user.id] = blip.contentVersion
        blip.isRootBlip = no
        blip.isContainer = yes
        return blip

    _initContributors: (blip, author, contributors) ->
        ###
        Инициализирует редакторов блипа.
        Проверяет, есть ли автор в списке редакторов, если нет - добавляет.
        редактора.
        @param blip: BlipModel
        @param author: UserModel
        @param contributors: array
        ###
        id = author.id
        blip.contributors = ({id: contributor.id} for contributor in contributors)
        blip.contributors.push({id}) if not blip.hasContributor(author)

    getBlip: (blipId, callback, needCatchup, loadWave=true) =>
        ###
        Получает снэпшот блипа, в коллбэк вернет модель либо ошибку.
        @param blipId: string
        @param callback: function
        ###
        onBlipGot = (err, blip) ->
            return callback(err) if err and err.message != 'not_found'
            return callback(new BlipError("Requested blip #{blipId} not found", BLIP_DOCUMENT_DOES_NOT_EXISTS)) if err
            callback(null, blip)
        CouchBlipProcessor.getById(blipId, onBlipGot, needCatchup, loadWave)

    getBlipsByWaveId: (waveId, callback) ->
        ###
        Получает все блипы по указанному waveId
        @param waveId: string
        @param callback: function
        ###
        CouchBlipProcessor.getByWaveIds(waveId, callback, true)

    getVersionByIds: (ids, callback) ->
        CouchBlipProcessor.getVersionByIds(ids, callback)

    updateBlipReader: (blip, reader, callback) ->
        updateReaders = (blip, readerId, callback) ->
            needSave = blip.markAsRead(readerId)
            callback(null, needSave, blip, false)
        CouchBlipProcessor.saveResolvingConflicts(blip, updateReaders, reader.id, callback)

    subscribe: (waveId, blipId, listenerId) ->
        OtProcessorFrontend.subscribeDoc(waveId, blipId, listenerId)

    fillDoc: (waveId, listenerId, blipId, version, actualVersion) ->
        OtProcessorFrontend.fillDoc(waveId, listenerId, blipId, version, actualVersion)

    unsubscribe: (waveId, blipId, listenerId) ->
        OtProcessorFrontend.unsubscribeDoc(waveId, blipId, listenerId)

    getRestrictedOps: (ops) ->
        ###
        Проверяет разрешены ли операции
        @param ops: array
        @returns array
        ###
        acceptedOps = ['content', 'isFoldedByDefault']
        return _.difference(OtTransformer.getOpsParam(ops), acceptedOps)

    _docToModel: (callback) ->
        return (err, doc) -> callback(err, if err then null else BlipCouchConverter.toModel(doc))

    _getId: (blip) -> (blip.getOriginalId() % 16).toString(16)

    postOp: (blip, contributor, ops, version, random, listenerId, onOpApplied, callback) ->
        ###
        Применяет операцию без проставления флага removed блипам
        ###
        args = {ops, version, random, listenerId}
        args.blipId = blip.id
        args.contributor = UserCouchConverter.toCouch(contributor) if contributor
        args.documentCallback = @_docToModel(callback)
        args.opResponseCallback = onOpApplied
        AmqpFrontendHelper.callMethod('postOp', @_getId(blip), args)

    createAnswerBlip: (parent, enquiryBlipId, author, content, callback) ->
        ###
        Создает блип-ответ (на блип enquiryBlipId) и вставляет его внутрь другого блипа (parent).
        @param parent: BlipModel - родитель, в него будет вставлен созданный блип
        @param enquiryBlipId: string - id блипа на который отвечаем
        @param author: UserModel - автор создаваемого блипа
        @param content: string - содержимое создаваемого блипа
        @param callback: function
        ###
        tasks = [
            async.apply(@createBlip, parent.waveId, author, null, content, no, no, no, yes, null, yes)
            (blipId, callback) =>
                ops = parent.getAnswerInsertionOp(blipId, enquiryBlipId)
                return callback(new BlipError("Blip #{enquiryBlipId} not found in parent blip #{parent.id}", INVALID_ENQUIRY_BLIP_ID)) if not ops
                [ordinarOps, inlineOps] = parent.splitOps(ops)
                @postOp(parent, author, ops, parent.version, null, null, null, (err, parent) ->
                    callback(err, parent, blipId, inlineOps)
                )
            (parent, blipId, inlineOps, callback) =>
                @getChildBlips(parent, [blipId], (err, childBlips) ->
                    callback(err, childBlips, inlineOps)
                )
            (childBlips, inlineOps, callback) =>
                @processInlineBlipOperation(childBlips, inlineOps, callback)
        ]
        async.waterfall(tasks, callback)

    processInlineBlipOperation: (childBlips, ops, callback) =>
        now = DateUtils.getCurrentTimestamp()
        branches = @_getBranchesForInlineBlipOperation(childBlips, ops)
        action = (blip, branches, callback) ->
            operationType = branches[blip.id]
            if not operationType
                console.error("Bugcheck. Not found remove flag for blip #{blip.id} while inserting or deleting")
                return callback(null, false, blip, false)
            blip.contentTimestamp = now
            blip.removed = operationType != INLINE_INSERTATION
            callback(null, true, blip, true)
        CouchBlipProcessor.bulkSaveResolvingConflicts(_.values(childBlips), action, branches, callback)

    _getBranchesForInlineBlipOperation: (childBlips, ops) ->
        branches = {}
        getChildIds = (id) ->
            childBlip = childBlips[id]
            if not childBlip
                console.error("Bugcheck. Not found child blip #{id}")
                return []
            return childBlip.getChildIds()
        for id, operationType of ops
            branchChildIds = CouchBlipProcessor.getChildTreeIds(id, getChildIds)
            branches[branchChildId] = operationType for branchChildId in branchChildIds
        return branches

    addContributorBlip: (blip, contributor, callback) =>
        ###
        Добавляет редактора в блип и шлет операци.
        @param blip: BlipModel
        @param version: int
        @param contributor: UserModel
        @param callback: function
        ###
        args = {blipId: blip.id}
        args.contributor = UserCouchConverter.toCouch(contributor) if contributor
        args.documentCallback = @_docToModel(callback)
        AmqpFrontendHelper.callMethod('addContributorBlip', @_getId(blip), args)

    getChildBlips: (blip, ids, callback) ->
        CouchBlipProcessor.getWithChildsByIdAsDict(ids, blip.waveId, callback)

    getChidBlipsByWaveId: (waveId, ids, callback) ->
        CouchBlipProcessor.getWithChildsByIdAsDict(ids, waveId, callback)

    _getOpsParam: (blip, ops) ->
        iterator = (op, fieldName) ->
            return fieldName if fieldName != 'content'
            return 'inline' if blip.isInlineProcessingOp(op)
            return fieldName
        return OtTransformer.getOpsParam(ops, iterator)

module.exports.BlipProcessor =  new BlipProcessor()
module.exports.BlipProcessorClass = BlipProcessor
