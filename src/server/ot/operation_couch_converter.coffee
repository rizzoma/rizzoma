OperationModel = require('./model').OperationModel
CouchConverter = require('../common/db/couch_converter').CouchConverter

class OperationCouchConverter extends CouchConverter
    ###
    Конвертор моделей операции для БД.
    ###
    constructor: () ->
        super(OperationModel)
        fields =
            docId: 'docId'
            op: 'op'
            user: 'user'
            timestamp: 'timestamp'
            random: '_random'
        @_extendFields(fields)

    toCouch: (model) ->
        doc = super(model)
        # Workaround for cradle conflict resolving (new doc with id and without rev is automatically
        # resolved by cradle if the document with the same id already exists. This is not good for operations).
        doc._rev = '0-0' if not doc._rev
        return doc

module.exports.OperationCouchConverter = new OperationCouchConverter()
