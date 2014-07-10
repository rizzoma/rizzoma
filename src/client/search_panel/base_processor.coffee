BaseRouter = require('../../share/base_router').BaseRouter
Request = require('../../share/communication').Request

class BaseSearchProcessor extends BaseRouter
    constructor: (@_rootRouter) ->
        super(@_rootRouter)
      
    search: (searchFunction, queryString, lastSearchDate, additionalParams = {}, callback) ->
        searchParams =
            queryString: queryString || ''
            lastSearchDate: lastSearchDate
        if typeof additionalParams is 'function'
            callback = additionalParams
        else
            for key, val of additionalParams
                searchParams[key] = val
        request = new Request(searchParams, callback)
        @_rootRouter.handle(searchFunction, request)

exports.BaseSearchProcessor = BaseSearchProcessor
