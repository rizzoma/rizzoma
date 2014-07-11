OperationCouchProcessor = require('./operation_couch_processor').OperationCouchProcessor
OtError = require('./exceptions').OtError
FText = require('../../share/formatted_text')

DOC_TYPE = require('./constants').DOC_TYPE
SHARE_TYPE = require('share/src/types')[DOC_TYPE]

class OtTransformer
    ###
    Класс, инкапсулирующий работу с ShareJS.
    ###
    constructor: () ->

    transformOp: (op, oldOps) ->
        ###
        Трансформирует операцю относительно прежних операций.
        ###
        err = @_checkOpSequence(oldOps)
        return err if err
        for oldOp in oldOps
            try
                op.op = SHARE_TYPE.transform(op.op, oldOp.op, 'left')
            catch err
                return new OtError(err.message)
            op.version++
        return op

    transformDoc: (doc, ops) ->
        ###
        Применяет операции к документу.
        ###
        for op in ops
            try
                doc = SHARE_TYPE.apply(doc, op.op)
            catch err
                return new OtError(err.message)
            return new OtError('Doc version mismatch after transform') if doc.version != op.version
            doc.version = op.version + 1
        return doc

    _checkOpSequence: (ops) ->
        return if not ops.length
        version = ops[0].version
        for op in ops
            curentOpVersion = op.version
            return new OtError('Invalid ops sequence') if curentOpVersion - version > 1
            version = curentOpVersion
        return

    applyFutureOps: (doc, callback) ->
        ###
        Применяет к документу операции версия которых больше версии документа.
        @param doc: Model
        @param callback: function
        ###
        OperationCouchProcessor.getByDocId(doc.id, doc.version, null, (err, ops) =>
            return callback(err, null) if err
            return callback(null, doc) if not ops.length
            err = doc = @transformDoc(doc, ops)
            return callback(err, null) if err instanceof OtError
            callback(null, doc, true)
        )

    getOpsParam: (ops, iterator) ->
        ###
        Map-функция над операцией, по умолчанию возвращает список полей документа, к которым применяется операция.
        @param ops: array
        @param iterator: function(op, fieldName) - функция, применяющаяся к каждой операции,
            результат которой будет сохранен в результирующий массив значений. По умолчанию возвращает 2-ой параметр,
            т.е. название поля документа.
        @returns: array
        ###
        if not iterator
            iterator = (op, fieldName) ->
                return fieldName
        getFieldName = (op) ->
            return op.p[0] if not FText.isFormattedTextOperation(op)
            return 'content'
        return (iterator(op, getFieldName(op)) for op in ops)

module.exports =
    OtTransformer: new OtTransformer()
