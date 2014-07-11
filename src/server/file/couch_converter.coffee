CouchConverter = require('../common/db/couch_converter').CouchConverter
FileModel = require('./model').FileModel

class FileCouchConverter extends CouchConverter
    constructor: () ->
        super(FileModel)
        fields =
            userId: 'userId'
            name: 'name'
            size: 'size'
            mimeType: 'mimeType'
            removed: 'removed'
            uploaded: 'uploaded'
            linkNotFound: 'linkNotFound'
            path: 'path'
            thumbnail: 'thumbnail'
            status: 'status'
        @_extendFields(fields)


module.exports.FileCouchConverter = new FileCouchConverter()