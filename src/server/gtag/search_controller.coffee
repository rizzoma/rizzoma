Conf = require('../conf').Conf
SearchController = require('../search/controller').SearchController
GTagCouchProcessor = require('./couch_processor').GTagCouchProcessor

TAGS_EXISTS_TAG = require('./model').TAGS_EXISTS_TAG
GTAG_SEARCH_LIMIT = 500

class GtagSearchController extends SearchController
    ###
    Процессор поисковой выдачи для тегов.
    ###
    constructor: () ->
        super()
        @_logger = Conf.getLogger("gtag")

    executeQuery: (user, callback) ->
        return if @_returnIfAnonymous(user, callback)
        query = @_getQuery()
            .select(['blip_id'])
            .addPtagsFilter(user, null)
            .addAndFilter("match('@gtags =#{TAGS_EXISTS_TAG}')")
            .limit(GTAG_SEARCH_LIMIT)
        @executeQueryWithoutPostprocessing(query, (err, results) =>
            return @_onSearchDone(results, callback) if not err
            @_logger.error(err)
            callback(null, [])
        )

    _onSearchDone: (results, callback) ->
        blipIds = (result.blip_id for result in results)
        return callback(null, []) if not blipIds.length
        GTagCouchProcessor.getByBlipIds(blipIds, (err, tags) =>
            return callback(null, tags) if not err
            @_logger.error(err)
            callback(null, [])
        )

module.exports.GtagSearchController = new GtagSearchController()