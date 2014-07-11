_ = require('underscore')
CouchProcessor = require('../common/db/couch_processor').CouchProcessor

class GTagCouchProcessor extends CouchProcessor
    ###
    Класс, представляющий процессор блипа в БД.
    ###
    constructor: () ->
        super()

    getByBlipIds: (blipIds, callback) ->
        viewParams =
            keys: blipIds
        @view("tags_by_blip_id/get", viewParams, (err, res) ->
            return callback(err, null) if err
            tags = {}
            for row in res
                tag = row.value
                tags[tag.toLowerCase()] = tag
            tags = _.values(tags)
            tags = tags.sort((tag1, tag2) ->
                tag1 = tag1.toLowerCase()
                tag2 = tag2.toLowerCase()
                return 0 if tag1 == tag2
                return if tag1 < tag2 then -1 else 1
            )
            callback(null, tags)
        )

module.exports.GTagCouchProcessor = new GTagCouchProcessor()