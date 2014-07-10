CouchProcessor = require('../common/db/couch_processor').CouchProcessor
StoreItemCouchConverter = require('./couch_converter').StoreItemCouchConverter
StoreError = require('./exceptions').StoreError

class StoreItemCouchProcessor extends CouchProcessor

    constructor: () ->
        super()
        @converter = StoreItemCouchConverter

    getById: (id, callback, args...) ->
        onItemGot = (err, item) ->
            return callback(err, item) if not err
            return callback(new StoreError("Invalid item id: #{id}")) if err.message == 'not_found'
            callback(err)
        super(id, onItemGot, args...)

    getItemsByCategory: (state = null, callback) ->
        startkey = [state or @MINUS_INF, @MINUS_INF, @MINUS_INF]
        endkey = [state or @PLUS_INF, @PLUS_INF, @PLUS_INF]
        @viewWithIncludeDocs('store_item_by_category_2/get', {startkey, endkey}, callback)

module.exports.StoreItemCouchProcessor = new StoreItemCouchProcessor()
