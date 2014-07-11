BaseError = require('../../share/exceptions').BaseError
ExternalError =  require('../common/exceptions').ExternalError

class SearchError extends BaseError
    ###
    Ошибка при работе с поиском.
    ###

SPHINX_TIMEOUT_ERROR = 'sphinx_timeout_error'

class SphinxTimeoutError extends BaseError
    ###
    Ошибка таймаута сфинкса
    ###

QUERY_SYNTAX_ERROR = 'query_syntax_error'
class SearchQueryError extends BaseError
    ###
    Ошибка в запросе к сфинксу (ошибка синтаксиса)
    ###
    constructor: (message, code=QUERY_SYNTAX_ERROR) ->
        super(message, code)
        @name = 'SearchQueryError'

SEARCH_TIMEOUT_ERROR = "search_timeout_error"

class SearchTimeoutError extends ExternalError
    ###
    Ошибка таймаута поиска отправляется на клиента
    ###
    constructor: (message, code=SEARCH_TIMEOUT_ERROR) ->
        super(message, code)
        @name = 'SearchTimeoutError'

SEARCH_TEMPORARY_NOT_AVAILABLE_ERROR = "search_temporary_not_available_error"

class SearchTemporaryNotAvailableError extends ExternalError
    ###
    Ошибка таймаута поиска отправляется на клиента
    ###
    constructor: (message, code=SEARCH_TEMPORARY_NOT_AVAILABLE_ERROR) ->
        super(message, code)
        @name = 'SearchTemporaryNotAvailableError'

class SphinxFatalError extends BaseError
    ###
    ###


module.exports =
    SearchError: SearchError
    SphinxTimeoutError: SphinxTimeoutError
    SPHINX_TIMEOUT_ERROR: SPHINX_TIMEOUT_ERROR
    SearchTimeoutError: SearchTimeoutError
    SEARCH_TIMEOUT_ERROR: SEARCH_TIMEOUT_ERROR
    SearchTemporaryNotAvailableError: SearchTemporaryNotAvailableError
    SEARCH_TEMPORARY_NOT_AVAILABLE_ERROR: SEARCH_TEMPORARY_NOT_AVAILABLE_ERROR
    SearchQueryError: SearchQueryError
    QUERY_SYNTAX_ERROR: QUERY_SYNTAX_ERROR
    SphinxFatalError: SphinxFatalError