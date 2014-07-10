Model = require('../common/model').Model
UrlAliasUtils = require('./utils').UrlAliasUtils

class UrlAliasModel extends Model
    ###
    Хранит соответствие между внутренним url топика и внешним, заданным в произвольном формате.
    ###
    constructor: (rawId, @_internalUrl, @_owner='local') ->
        @id = UrlAliasUtils.getId(rawId, @_owner) if rawId

    getInternalUrl: () ->
        return @_internalUrl

    getOwner: () ->
        return @_owner

module.exports.UrlAliasModel = UrlAliasModel
