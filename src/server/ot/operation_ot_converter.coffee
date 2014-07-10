OtConverter = require('../common/ot/converter').OtConverter
IdUtils = require('../utils/id_utils').IdUtils

class OperationOtConverter extends OtConverter
    ###
    Конвертор моделей операции для ShareJS
    ###
    constructor: () ->
        super()

    toClient: (model, clientDocId) ->
        doc = super(model)
        #Внимание! Это говнокод. Т.к. топики на клиенте по урлам, а бипы по id приходится изъебываться и подменять в зависимости от типа документа.
        doc.docId = if IdUtils.parseId(model.docId).type == 'b' then model.docId else clientDocId
        doc.op = model.op
        doc.meta.ts = model.timestamp
        doc.meta.user = model.user
        return doc

module.exports.OperationOtConverter = new OperationOtConverter()
