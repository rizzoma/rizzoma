_ = require('underscore')
mysql = require('mysql')
Ptag = require('../ptag').Ptag

Conf = require('../conf').Conf
SEARCH_RESULTS_LIMIT = 100

class Query
    constructor: () ->
        @_select = []
        @_conf = Conf.getSearchIndexerConf() || {}
        @_confIndexes = @_conf.indexes || []
        indexPrefix = @_conf.indexPrefix
        prefix = if indexPrefix then "#{indexPrefix}_" else ""
        @_indexes = ("#{prefix}#{i}_index" for conf, i in @_confIndexes)
        @_orFilters = []
        @_andFilters = []
        @_groupBy = null
        @_orderBy = []
        @_limit = null
        @_comments = []

    select: (attributes=[]) ->
        @_select = @_select.concat(attributes)
        return @

    setIndexes: (indexes=[]) ->
        @_indexes = indexes if indexes.length

    addOrFilter: (filter) ->
        @_addFilter(filter, @_orFilters)

    addAndFilter: (filter) ->
        @_addFilter(filter, @_andFilters)

    _addFilter: (filter, filterList) ->
        filterList.push(filter) if filter
        return @

    addQueryString: (queryString) ->
        return @ if not queryString
        [regularTokens, gtags] = @_parseQueryString(@_escape(queryString))
        return @ if not regularTokens.length and not gtags.length
        @_addQueryStringFilter(regularTokens, gtags)
        return @

    addPtagsFilter: (users, ptagNames) ->
        users = [users] if not _.isArray(users)
        ptagNames = [ptagNames] if not _.isArray(ptagNames)
        ptagIds = []
        for ptagName in ptagNames
            for user in users
                ptagIdsForUser = Ptag.getSearchPtagIdsByName(user, ptagName)
                ptagIds = ptagIds.concat(ptagIdsForUser) if ptagIdsForUser
        if ptagIds.length
            @addAndFilter("ptags in (#{_.uniq(ptagIds).join(',')})")
            @addComment("userIds=#{(u.id for u in users).join(',')}")
        return @

    addComment: (comment) ->
        @_comments.push(comment) if comment
        return @

    groupBy: (attribute) ->
        @_groupBy = attribute if attribute
        return @

    orderBy: (attributes=[]) ->
        @_orderBy = @_orderBy.concat(attributes)
        return @

    limit: (limit) ->
        @_limit = limit if limit
        return @

    defaultLimit: () ->
        @_limit = SEARCH_RESULTS_LIMIT
        return @

    toString: () ->
        query = "select #{if @_select.length then @_select.join(',') else '*'}"
        query += " from #{@_indexes.join(',')}"
        @_andFilters.push(@_orFilters.join(' or ')) if @_orFilters.length
        query += " where #{@_andFilters.join(' and ')}" if @_andFilters.length
        query += " group by #{@_groupBy}" if @_groupBy
        query += " order by #{(field += ' DESC' for field in @_orderBy).join(',')}" if @_orderBy.length
        query += " limit #{@_limit}" if @_limit
        query += " option comment=#{mysql.escape(@_comments.join(' '))}" if @_comments.length
        return query

    _escape: (queryString) ->
        ###
        Эскейпит строку запроса.
        @param queryString: string
        @returns: string
        ###
        regExp = new RegExp("([=\\(\\)|\\-!@~&/\\^\\$№%+*?,'\\.\\:;\\\\])", 'g')
        queryString =  queryString.replace(regExp, '\\$1')
        queryString = queryString.trim()
        return queryString

    _parseQueryString: (queryString) ->
        return [[], []] if not queryString.length
        queryString += '"' if queryString.match(/\"/g)?.length % 2 #нечетное кол-во кавычек, закроем
        tokens = queryString.split(' ')
        gtagSymbol = '#'
        gtags = []
        regularTokens = []
        for token in tokens
            if token.indexOf(gtagSymbol) == 0
                token = token.replace(gtagSymbol, '')
                gtags.push(token) if token.length #просто решетка, без тега - выкинем ее
                continue
            regularTokens.push(token)
        return [regularTokens, gtags]

    _addQueryStringFilter: (regularTokens, gtags) ->
        return if not gtags.length and not regularTokens.length
        filters = []
        if regularTokens.length
            filters.push("@(title,content,gtags) #{regularTokens.join(' ')} ")
        if gtags.length
            filters.push("@gtags #{("=#{gtag}" for gtag in gtags).join(' ')}")
        filters = ("(#{filter})" for filter in filters) if filters.length > 1
        filter = filters.join(' & ')
        @addAndFilter("match(#{mysql.escape(filter)})")


module.exports.Query = Query
