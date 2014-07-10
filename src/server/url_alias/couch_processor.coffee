CouchProcessor = require('../common/db/couch_processor').CouchProcessor
UrlAliasModelCouchConverter = require('./couch_converter').UrlAliasModelCouchConverter
UrlAliasUtils = require('./utils').UrlAliasUtils

class UrlAliasCouchProcessor extends CouchProcessor
    constructor: () ->
        super()
        @converter = UrlAliasModelCouchConverter
        @_cache = @_conf.getCache('urlAlias')

module.exports.UrlAliasCouchProcessor = new UrlAliasCouchProcessor()
