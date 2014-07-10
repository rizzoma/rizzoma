StorageProcessor = require('../storage_processor').StorageProcessor

class LocalStorageProcessor extends StorageProcessor
    putFile: (path, storagePath, type, callback) ->
        callback('Local uploads are not implemented')

    deleteFile: (storagePath, callback) ->
        callback(null, 'Local deletes are not implemented')

    getLink: (storagePath, notProtected=false) ->
        return null

exports.LocalStorageProcessor = LocalStorageProcessor
