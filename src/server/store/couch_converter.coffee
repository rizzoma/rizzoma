CouchConverter = require('../common/db/couch_converter').CouchConverter
storeItemFactory = require('./model').storeItemFactory

class StoreItemCouchConverter extends CouchConverter

    constructor: (args...) ->
        super((doc) ->
            return storeItemFactory(doc.category)
        )
        fields =
            category: '_category'
            title: '_title'
            icon: '_icon'
            description: '_description'
            topicUrl: '_topicUrl'
            weight: '_weight'
            state: '_state'
            itemProperties: '_itemProperties'
        @_extendFields(fields)

module.exports.StoreItemCouchConverter = new StoreItemCouchConverter()
