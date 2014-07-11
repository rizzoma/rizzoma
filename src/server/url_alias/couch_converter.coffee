CouchConverter = require('../common/db/couch_converter').CouchConverter

UrlAliasModel = require('./model').UrlAliasModel

class UrlAliasModelCouchConverter extends CouchConverter
    constructor: () ->
        super(UrlAliasModel)
        fields =
            internalUrl: '_internalUrl'
            owner: '_owner'
        @_extendFields(fields)

module.exports.UrlAliasModelCouchConverter = new UrlAliasModelCouchConverter()
