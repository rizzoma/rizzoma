async = require('async')
Conf = require('../conf').Conf
ExternalError = require('../common/exceptions').ExternalError
SearchError = require('./exceptions').SearchError
SearchQueryError = require('./exceptions').SearchQueryError
SphinxSearch = require('./transport').SphinxSearch
AmqpSearch = require('./transport').AmqpSearch

class SearchProcessor
    ###
    Выполняет поиск, в зависимости от настроек:
    - посылает запрос Сфинксу
    - отправляет запрос по AMQP для обработки его специальными процессами (APP_ROLE=searcher)
    ###
    constructor: () ->
        @_searcher = null
        @_conf = Conf.getSearchConf()
        @_searchType = @_conf.searchType || 'local'
        @_searcher = @_getSearchInstance(@_searchType)

    _getSearchInstance: (searchType) ->
        switch searchType
            when "local" then return new SphinxSearch()
            when "amqp" then return new AmqpSearch()
            else throw new Error("Unknown searchType #{searchType}")

    executeQuery: (query, callback) ->
        @_searcher.executeQuery(query.toString(), (err, results) ->
            if err and err not instanceof ExternalError and err not instanceof SearchQueryError
                err = new SearchError(err)
            callback(err, results)
        )


module.exports.SearchProcessor = new SearchProcessor()