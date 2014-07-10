_= require('underscore')
NotImplementedError = require('../../share/exceptions').NotImplementedError
SearchProcessor = require('./processor').SearchProcessor
Query = require('../common/query').Query

class SearchController
    ###
    Класс-процессор поисковой выдачи.
    ###
    constructor: () ->
        @_idField = null
        @_changedField = null
        @_ptagField = null

    _getQuery: () ->
        return new Query()

    executeQueryWithoutPostprocessing: (query, callback) ->
        SearchProcessor.executeQuery(query, callback)

    executeQuery: (query, lastSearchDate, args..., callback) ->
        @executeQueryWithoutPostprocessing(query, (err, results) =>
            return callback(err) if err
            @_onSearchDone(results, lastSearchDate, args..., callback)
        )

    _returnIfAnonymous: (user, callback) ->
        if user.isAnonymous()
            callback(null, {searchResults: []})
            return true
        return

    _onSearchDone: (results, lastSearchDate, args..., callback) ->
        ###
        Получает данные для поисковой выдачи.
        @param results: array - ответ поисковика
        @param lastSearchDate: int - дата последнего писка
        @param args: ... - произвольные аргументы, нужные для получения выдачи.
        @param callback: function
        ###
        lastSearchDate = +lastSearchDate
        maxLastChangeDate = 0
        changedItemsIds = []
        items = []
        indexes = {}
        for result, index in results
            id = result[@_idField]
            lastChangeDate = result[@_changedField]
            maxLastChangeDate = lastChangeDate if maxLastChangeDate <= lastChangeDate
            changed = lastChangeDate > lastSearchDate
            #mva возврачается строкой разделенных через запятую значений
            result[@_ptagField] = result[@_ptagField].split(',') if @_ptagField and _.isString(result[@_ptagField])
            item = @_getItem(result, changed, args...)
            items.push(item)
            continue if not changed
            #убираем из выдачи топики в которых никого нет
            continue if @_ptagField and (not result[@_ptagField] or not result[@_ptagField].length)
            indexes[id] = index
            changedItemsIds.push(id)
        @_getChangedItems(changedItemsIds, args..., (err, changedItems) =>
            return callback(err, null) if err
            items = @_extendItems(items, indexes, changedItems)
            callback(null, {searchResults: items, lastSearchDate: maxLastChangeDate})
        )

    _extendItems: (items, indexes, changedItems) ->
        ###
        Добавляет к первичновый выдачи данные изменившихся элементов.
        @param index: array - первичная выдача
        @param indexes: object - словарь индексов изменившихся элементов в выдаче
        @param changedItems: object - словарь изменившихся элементов выдачи.
        ###
        for own id, changedItem of changedItems
            index = indexes[id]
            item = items[index]
            _.extend(item, changedItem)
            item.changed = true
        return items

    _getItem: (result, changed, args...) ->
        ###
        Возвращает выдачу первоначальную выдачу для результата поиска.
        @param result: object
        @param changed: bool - изменился ли результат с момента предидущего поиска.
        ###
        throw new NotImplementedError()

    _getChangedItems: (ids, args..., callback) ->
        ###
        Получает данные для изменившихся результатов поиска.
        @param ids: array - список документов, которые изменились с момента предидущего поиска
        @param args: ... - аргументы, переданные в process с 3 параметра
        ###
        throw new NotImplementedError()

module.exports.SearchController = SearchController
