CouchProcessor = require('../common/db/couch_processor').CouchProcessor
WaveCouchConverter = require('../wave/couch_converter').WaveCouchConverter

class TeamCouchProcessor extends CouchProcessor
    constructor: () ->
        super()
        @converter = WaveCouchConverter

    getByTopicTypeAndUserId: (topicType, userId, callback) =>
        params = if userId then {key: [topicType, userId]} else {startkey: [topicType, @MINUS_INF], endkey:[topicType, @PLUS_INF]}
        @viewWithIncludeDocs('wave_by_topic_type_and_user_id/get', params, callback)

    getByTopicTypeAndUserIds: (topicType, userIds, callback) =>
        keys = ([topicType, id] for id in userIds)
        @viewWithIncludeDocs('wave_by_topic_type_and_user_id/get', {keys}, callback)

module.exports.TeamCouchProcessor = new TeamCouchProcessor()
