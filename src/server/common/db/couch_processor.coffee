_ = require('underscore')
async = require('async')
Conf = require('../../conf').Conf
DbError = require('./exceptions').DbError
HashedQueue = require('../../utils/queue').HashedQueue

class CouchProcessor
    ###
    Базовый класс для работы с БД (сохранить, загрузить, удалить).    
    ###
    constructor: (dbConfName='main') ->
        @MINUS_INF = null
        @PLUS_INF = {}
        @converter = null # должен инициализироваться в потомках
        @_conf = Conf
        @_db = Conf.getDb(dbConfName)
        @_cache = null
        @_initLogger()
        writeQueueWorker = (docId, doc, callback) =>
            @_addToCache(doc, (err) =>
                @_logger.warn("Error while adding to cache: #{err.message}") if err
                callback(null)
            )
        @_writeQueue = new HashedQueue(writeQueueWorker)

    _initLogger: () ->
        try
            @_logger = Conf.getLogger('db')
        catch e
            @_logger = console

    getByIdsAsDict: (ids, callback, ignoreCache) =>
        ###
        Возвращает модель по id.
        @param id: array
        @param callback: function
        @param fetchAsDict: bool - вернуть данные массивом или словарем с ключем id модели.
        ###
        onDocsGot = (err, docs) =>
            return callback(err, null) if err
            callback(null, @_convertDocsToModels(docs))
        @_getWithCache(ids, onDocsGot, ignoreCache)

    getByIds: (ids, callback, ignoreCache) =>
        ###
        Возвращает модели в виде массива.
        @param ids: array
        @param callback: function
        ###
        onModelsGot = (err, models) ->
            return callback(err) if err
            results = []
            for id in ids
                model = models[id]
                results.push(model) if model
            callback(null, results)
        @getByIdsAsDict(ids, onModelsGot, ignoreCache)

    getById: (id, callback, ignoreCache) =>
        ###
        Шорткат для @getByIds. Возвращает модели в виде массива.
        @param ids: string
        @param callback: function
        ###
        onModelGot = (err, models) ->
            return callback(err) if err
            return callback(new DbError('not_found'), null) if not models.length
            callback(null, models[0])
        @getByIds([id], onModelGot, ignoreCache)

    getAllIds: (startId, endId, limit, skipFirst=true, callback) ->
        ###
        Достает диапазон id с лимитом, не включая startId
        @param startId: string
        @param endId: string
        @param limit: int
        ###
        params =
            startkey: startId
            endkey: endId
        params.skip = 1 if skipFirst
        params.limit = limit if limit
        @_db.all(params, (err, range)->
            return callback(new DbError(err.error), null) if err
            ids = (r.id for r in range)
            callback(null, ids)
        )

    viewWithIncludeDocsAsDict: (viewName, viewParms, callback, ignoreCache) ->
        viewParms.include_docs = false
        tasks = [
            (callback) =>
                @view(viewName, viewParms, callback)
            (viewDocs, callback) =>
                ids = (doc.id for doc in viewDocs)
                return callback(null, {}) if not ids.length
                @_getWithCache(ids, callback, ignoreCache)
            (docs, callback) =>
                callback(null, @_convertDocsToModels(docs))
        ]
        async.waterfall(tasks, callback)

    viewWithIncludeDocs: (viewName, viewParms, callback, ignoreCache) ->
        onModelsGot = (err, models) ->
            callback(err, if err then null else _.values(models))
        @viewWithIncludeDocsAsDict(viewName, viewParms, onModelsGot, ignoreCache)

    getOne: (viewName, viewParams, callback, ignoreCache) ->
        ###
        Возращает результат, если view вернула ровно 1 документ.
        @param viewName: string
        @param viewParams: object
        @param callback: function
        @todo написать тесты
        ###
        onModelsGot = (err, models) =>
            return callback(err, null) if err
            count = models.length
            return callback(new DbError('not_found'), null) if not count
            @_logger.error("Wrong view '#{viewName}' result count: #{count}") if count > 1
            callback(null, models[0])
        @viewWithIncludeDocs(viewName, viewParams, onModelsGot, ignoreCache)

    view: (viewName, viewParms, callback) ->
        ###
        Обертка для view
        @param viewName: strung
        @param viewParams: object
        @param callback: function
        ###
        @_db.view(viewName, viewParms, (err, docs) ->
            return callback(new DbError(err.error), null) if err
            callback(null, docs)
        )

    saveResolvingConflicts: (args...) ->
        [model, action, actionArgs, callback] = @_parseArgs(args)
        @_bulkSaveResolvingConflicts([model], action, actionArgs, (err, revs) ->
            return callback(err, null) if err
            r = _.values(revs)[0]
            r = {rev: true} if not r
            callback(r.error, r.rev)
        )

    bulkSaveResolvingConflicts: (args...) ->
        ###
        Сохраняет в БД
        @param model: Model - модель которую мы загрузили из базы и ни в коем случае не меняем в других местах кроме action
        @param action: function - зименяет нужные поля модели перед сохранением
            @param Model
            @param args
            @param callback - нужно передать 4 аргумента:
                err - ошибка
                needSave - нужно ли сохранять
                model - измененная модель
                needIndexing - нужна ли переиндексация поиска
        @param args: array - аргументы для action
        @param callback: function
        ###
        [models, action, actionArgs, callback] = @_parseArgs(args)
        @_bulkSaveResolvingConflicts(models, action, actionArgs, callback)

    save: (model, callback, changed=false) ->
        ###
        Сохраняет модель.
        В callback будет передана ревизия сохраненного документа.
        @param model: Model
        @param callback: function
        @param changed: bool
        ###
        onSave = (err, res) ->
            return callback(err, null) if err
            r = _.values(res)[0]
            err = if r.error then new DbError(r.error) else null
            callback(err, r.rev)
        @bulkSave([model], onSave, changed)

    bulkSave: (models, callback, changed=false) ->
        ###
        Сохраняет массив моделей.
        Вернет в callback объект вида id: {rev: ..., прочая: херня, ...}
        @param models: array
        @param callback: function
        ###
        docs = (@converter.toCouch(model) for model in models)
        single = docs.length == 1
        toSave = if single then docs[0] else docs
        tasks = [
            (callback) =>
                @_db.save(toSave, callback)
            (results, callback) =>
                require('../../search/indexer').Indexer.makeIndexSource() if changed
                @_processSaveResults(results, docs, models, callback)
            (revs, toCache, callback) =>
                @_queueAddToCache(toCache, (err) ->
                    callback(err, if err then null else revs)
                )
        ]
        async.waterfall(tasks, (err, revs) =>
            return @_processSaveError(err, toSave, single, callback) if err
            callback(null, revs)
        )

    remove: (model, callback) =>
        ###
        Удаляет документ
        ###
        doc = @converter.toCouch(model)
        id = doc._id
        @_db.remove(id, doc._rev, (err) =>
            return callback(err) if err
            @_removeDocsFromCache([id], callback)
        )

    _processSaveError: (err, toSave, single, callback) ->
        return callback(new DbError(err.error), null) if not single
        revs = {}
        revs[toSave._id] = {id: toSave._id, error: err.error}
        return callback(null, revs) if err.error != 'conflict'
        @_removeDocsFromCache([toSave._id], () ->
            callback(null, revs)
        )

    _processSaveResults: (results, docs, models, callback) ->
        toCache = []
        [revs, toRemoveFromCache] = @_parseRevs(results, docs)
        for doc, i in docs
            id = doc._id
            rev = revs[id].rev
            continue if not rev
            doc._rev = rev
            models[i]._rev = rev
            toCache.push(doc) if id not in toRemoveFromCache
        if toRemoveFromCache.length
            return @_removeDocsFromCache(toRemoveFromCache, () ->
                callback(null, revs, toCache)
            )
        callback(null, revs, toCache)

    _parseRevs: (results, docs) ->
        revs = {}
        toRemoveFromCache = []
        if docs.length == 1
            results.id = docs[0]._id
            results = [results]
        for result in results
            id = result.id
            revs[id] = result
            error = result.error
            continue if not error
            toRemoveFromCache.push(id) if error == 'conflict'
        return [revs, toRemoveFromCache]

    _bulkSaveResolvingConflicts: (models, action, actionArgs, callback) ->
        ###
        Сохраняет в БД
        @param model: Model - модель которую мы загрузили из базы и ни в коем случае не меняем в других местах кроме action
        @param action: function - зименяет нужные поля модели перед сохранением
            @param Model
            @param args
            @param callback - нужно передать 4 аргумента:
                err - ошибка
                needSave - нужно ли сохранять
                model - измененная модель
                needIndexing - нужна ли переиндексация поиска
        @param args: array - аргументы для action
        @param callback: function
        ###
        return callback(null, {}) if not models.length
        tasks =[
            (callback) =>
                @_bulkSaveApplingAction(models, action, actionArgs, callback)
            (revs, callback) =>
                @_loadConflictedModels(revs, (errs, models) =>
                    revs = _.extend(revs, errs)
                    callback(null, models, revs)
                )
            (conflictedModels, revs, callback) =>
                return callback(null, revs) if not conflictedModels.length
                @_logger.debug("Save conflict, going to repeat",
                    {docCount: conflictedModels.length, ids: (model.id for model in conflictedModels)}
                )
                @_bulkSaveResolvingConflicts(conflictedModels, action, actionArgs, (err, childRevs) =>
                    if err
                        for model in conflictedModels
                            revs[model.id] = err
                        return callback(null, revs)
                    revs = _.extend(revs, childRevs)
                    callback(null, revs)
                )
        ]
        async.waterfall(tasks, callback)

    _bulkSaveApplingAction: (models, action, actionArgs, callback) ->
        ###
        Выполняет непосредственное сохранение в БД.
        @param model: Model - модель которую надо сохранить
        @param action: function - @see saveResolvingConflicts
        @param args: array - аргументы для action
        @param callback: function - collback(err)
        ###
        @_bulkApplyAction(models, action, actionArgs, (err, results) =>
            return callback(err, null) if err
            toSave = []
            changed = false
            for result in results when result.needSave
                toSave.push(result.model)
                changed = true if result.changed
            @bulkSave(toSave, callback, changed)
        )

    _bulkApplyAction: (models, action, actionArgs, callback) ->
        ###
        Применяет action ко всем моделям
        ###
        tasks = []
        for model in models
            task = do(action, model, actionArgs) ->
                return (callback) ->
                    action(model, actionArgs..., (err, needSave, model, changed) ->
                        callback(err, {needSave, model, changed})
                    )
            tasks.push(task)
        async.parallel(tasks, callback)

    _getConflictedIds: (revs) ->
        ###
        Возвращает id законфликченных документов из результатов сохранения
        @returns: array
        ###
        ids = []
        for own id, rev of revs
            error = rev.error
            if error and error == 'conflict'
                ids.push(id)
                continue
        return ids

    _loadConflictedModels: (revs, callback) ->
        ###
        Загружает законфликченые модели
        ###
        ids = @_getConflictedIds(revs)
        return callback({}, []) if not ids.length
        errs = {}
        @_db.get(ids, (err, docs) =>
            if err
                for id in ids
                    errs[id] = err
                return callback(errs, [])
            models = []
            for doc in docs
                error = doc.error
                if doc.doc and not error
                    model = @converter.toModel(doc.doc)
                    models.push(model) if model
                else
                    errs[doc.id] = error
            callback(errs, models)
        )

    _queueAddToCache: (docs, callback) ->
        tasks = []
        for doc in docs
            toCache = {}
            docId = doc._id
            toCache[docId] = doc
            tasks.push(do(toCache) =>
                return (callback) =>
                    @_writeQueue.push(docId, toCache, callback)
            )
        async.parallel(tasks, callback)

    _getWithCache: (ids, callback, ignoreCache) ->
        ids = _.compact(_.uniq(ids))
        tasks = [
            (callback) =>
                @_getFromCache(ids, callback, ignoreCache)
            (cachedDocs, callback) =>
                toLoad = []
                for id in ids
                    if not cachedDocs[id]
                        toLoad.push(id)
                        delete cachedDocs[id]
                return callback(null, cachedDocs, {}) if not toLoad.length
                @_get(toLoad, (err, docs) ->
                    callback(err, cachedDocs, docs)
                )
            (cachedDocs, docs, callback) =>
                return callback(null, cachedDocs, {}) if _.isEmpty(docs)
                @_addToCache(docs, (err) ->
                    callback(err, cachedDocs, docs)
                )
            (cachedDocs, docs, callback) ->
                callback(null, _.extend(cachedDocs, docs))
        ]
        async.waterfall(tasks, (err, docs) ->
            return callback(new DbError(err.error or err.message)) if err
            callback(null, docs)
        )

    _get: (ids, callback) ->
        return callback(null, {}) if not ids.length
        @_db.get(ids, (err, docs) =>
            if err
                @_logger.warn("Error while getting docs #{ids} from db:", err)
                return callback(null, {})
            docsById = {}
            for doc in docs when doc.doc and not doc.error
                docsById[doc.doc._id] = doc.doc
            callback(null, docsById)
        )

    _getFromCache: (ids, callback, ignoreCache=false) ->
        return callback(null, {}) if not ids.length
        return callback(null, {}) if not @_cache or ignoreCache
        @_cache.multipleGet(ids, callback)

    _addToCache: (docs, callback) ->
        return callback(null) if not @_cache
        @_cache.multipleSet(docs, callback)

    _removeDocsFromCache: (ids, callback) ->
        return callback(null) if not @_cache
        @_cache.multipleRemove(ids, callback)

    _convertDocsToModels: (docs) ->
        ###
        Итерируется по документам из БД и возвращает массив моделей.
        @param docs: array
        @returns: array
        ###
        models = {}
        for id, doc of docs
            model = @converter.toModel(doc)
            models[id] = model if model
        return models

    _parseArgs: (args) ->
        ###
        Разбирает аргументы @saveResolvingConflicts.
        @param args: array
        @return array
        ###
        model = args[0]
        action = args[1]
        actionArgs = args.slice(2, args.length - 1)
        callback = args.slice(-1)[0]
        return false if typeof(action) != 'function'
        return false if typeof(callback) != 'function'
        return [model, action, actionArgs, callback]

module.exports.CouchProcessor = CouchProcessor
