CouchProcessor = require('../common/db/couch_processor').CouchProcessor
OperationCouchConverter = require('./operation_couch_converter').OperationCouchConverter
delimiter = require('../conf').Conf.getGeneratorConf()['delimiter']
IdUtils = require('../utils/id_utils').IdUtils
OPERATION_TYPE = require('./constants').OPERATION_TYPE

class OperationCouchProcessor extends CouchProcessor
    ###
    Процессор операций.
    ###
    constructor: () ->
        super('operations')
        @converter = OperationCouchConverter
        @_cache = @_conf.getCache('op')

    getByDocId: (docId, start, end=@PLUS_INF, callback) ->
        return callback(null, []) if start == end
        viewParams =
            startkey: [docId, start]
            endkey: [docId, end]
        @viewWithIncludeDocs('ot_1/ot_operations', viewParams, callback)

    getOpRange: (docId, start, end, callback) ->
        ###
        Возвращает массив моделей операции по имени документа
        к которому эти операции были применены.
        @param docId: string
        @param start: int
        @param end: int
        @param callback: function
        ###
        return callback(null, []) if start == end
        ids = (@_getOpId(docId, version) for version in [start...end])
        @getByIds(ids, callback)

    save: (model, callback) ->
        model.setId()
        super(model, callback)

    _getOpId: (docId, version) ->
        ###
        Получает из id документа и версии id операции
        @param docId: string
        @param version: int
        ###
        parsedId = IdUtils.parseId(docId)
        parts = [parsedId.prefix, OPERATION_TYPE]
        parts.push(parsedId.extensions) if parsedId.extensions
        parts.push(parsedId.id)
        parts.push(version)
        return parts.join(delimiter)

module.exports.OperationCouchProcessor = new OperationCouchProcessor()
