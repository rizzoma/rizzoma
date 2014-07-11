async = require('async')
CouchProcessor = require('../common/db/couch_processor').CouchProcessor
AuthCouchConverter = require('./couch_converter').AuthCouchConverter

class AuthCouchProcessor extends CouchProcessor
    
    constructor: () ->
        super()
        @converter = AuthCouchConverter

    getByUserIds: (ids, callback) =>
        param =
            keys: ids
        @viewWithIncludeDocs('auth_by_user_id/get', param, callback)

    getByUserId: (userId, callback) =>
        @getByUserIds([userId], callback)
        
    getByUserIdAndSource: (userId, source, callback) ->
        @getByUserId userId, (error, authList) ->
            return callback(error) if error
            for auth in authList
                if auth.getSource() is source
                    return callback(null, auth)
            callback(null, null)

module.exports.AuthCouchProcessor = new AuthCouchProcessor()
