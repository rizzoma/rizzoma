CouchProcessor = require('../common/db/couch_processor').CouchProcessor
FileCouchConverter = require('./couch_converter').FileCouchConverter

class FileCouchProcessor extends CouchProcessor

    constructor: () ->
        super()
        @converter = FileCouchConverter

    getFileSizeByUserId: (id, callback) ->
        @getFileSizeByUserIds([id], callback)

    getFileSizeByUserIds: (ids, callback) ->
        ###
        Вернет суммарный размер загруженных пользователями файлов для каждого из них.
        ###
        params =
            keys: ids
            group: true
        @view 'file_size_by_user_id/file_size_by_user_id', params, callback

    getFilesForCompare: (callback) ->
        @view 'files_for_compare/files_for_compare', {}, callback

    updateNotFoundFlag: (file, flag, callback) ->
        action = (file, callback) ->
            file.linkNotFound = flag
            callback(null, yes, file, no)
        @_applyFileChanges(file, action, callback)

    setFileAsRemoved: (file, callback) ->
        action = (file, callback) ->
            file.removed = yes
            callback(null, yes, file, no)
        @_applyFileChanges(file, action, callback)

    _applyFileChanges: (file, action, callback) ->
        @saveResolvingConflicts(file, action, callback)


module.exports.FileCouchProcessor = new FileCouchProcessor()
