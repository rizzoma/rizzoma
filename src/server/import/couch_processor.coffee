Conf = require('../conf').Conf
CouchProcessor = require('../common/db/couch_processor').CouchProcessor
WaveImportDataCouchConverter = require('./couch_converter').WaveImportDataCouchConverter

class CouchImportProcessor extends CouchProcessor
    ###
    Класс, представляющий процессор блипа в БД.
    ###
    constructor: () ->
        super()
        @_db = Conf.getDb('import')
        @converter = WaveImportDataCouchConverter

    getNotImported: (limit, callback) =>
        params =
            limit: limit
        @viewWithIncludeDocs('import/not_imported', params, callback)
        
    getByParticipantEmail: (email, limit, callback) ->
        params =
            limit: limit
            startkey: [email, @PLUS_INF]
            endkey: [email, @MINUS_INF]
            descending: true
        @viewWithIncludeDocs('import/by_participant_email', params, callback)

    getImportedByTimestamp: (from, callback) ->
        to=@PLUS_INF
        params =
            startkey: from
            endkey: to
        @viewWithIncludeDocs('imported/imported_by_timestamp', params, callback)

    getImportedByDate: (callback) =>
        params =
            startkey: @PLUS_INF
            endkey: @MINUS_INF
            group: true
            group_level: 3
            descending: true
        @view('stat_import/imported_by_date', params, callback)
    
module.exports.CouchImportProcessor = new CouchImportProcessor()
