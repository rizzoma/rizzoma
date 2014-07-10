CouchConverter = require('../common/db/couch_converter').CouchConverter

TipListModel = require('./model').TipListModel

class TipListCouchConverter extends CouchConverter
    ###
    Класс-конвертор списка подсказок.
    ###
    constructor: () ->
        super(TipListModel)
        fields =
            tips: 'tips'
            lastModified: 'lastModified'
        @_extendFields(fields)

module.exports.TipListCouchConverter = new TipListCouchConverter()