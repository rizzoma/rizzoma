CouchProcessor = require('../common/db/couch_processor').CouchProcessor
TipListCouchConverter = require('./couch_converter').TipListCouchConverter
TipListModel = require('./model').TipListModel

TIP_LIST_ID = require('./constants').TIP_LIST_ID

class TipListCouchProcessor extends CouchProcessor
    ###
    Класс-процессор списка подсказок.
    ###
    constructor: () ->
        super()
        @converter = TipListCouchConverter
        @_cache = @_conf.getCache('tipList')

    getTipList: (callback) ->
        @getById(TIP_LIST_ID, (err, tipList) ->
            return callback(null, new TipListModel()) if err and err.message == 'not_found'
            callback(err, tipList)
        )

module.exports.TipListCouchProcessor = new TipListCouchProcessor()
