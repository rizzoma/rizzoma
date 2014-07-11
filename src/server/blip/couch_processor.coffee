_ = require('underscore')
async = require('async')
CouchProcessor = require('../common/db/couch_processor').CouchProcessor
OtTransformer = require('../ot/utils').OtTransformer
BlipCouchConverter = require('./couch_converter').BlipCouchConverter
BlipOtConverter = require('./ot_converter').BlipOtConverter
DateUtils = require('../utils/date_utils').DateUtils

class CouchBlipProcessor extends CouchProcessor
    ###
    Класс, представляющий процессор блипа в БД.
    ###
    constructor: () ->
        super()
        @converter = BlipCouchConverter
        @_cache = @_conf.getCache('blip')
        @FOREVER_REMOVED_BLIP_TIME = 15 * 24 * 60 * 60

    getByWaveIds: (waveIds, callback, ignoreRemovedBlips) =>
        ###
        Возвращает массив моделей блипов принадлежащих волне с переданным waveId
        @param waveId: string
        @param callback: function
        @param ignoreRemovedBlips: bool - включать ли удаленные блипы в результат запроса.
        ###
        viewParams = if _.isArray(waveIds) then {keys: waveIds} else {key: waveIds}
        viewName = if ignoreRemovedBlips then 'nonremoved_blips_by_wave_id/get' else 'blip/blips_by_wave_id'
        @viewWithIncludeDocs(viewName, viewParams, callback)

    getById: (blipId, callback, needCatchup, loadWave=true) =>
        onBlipGot = (err, blip) ->
            return callback(err, null) if err
            tasks = [
                (callback) ->
                    return callback(null, blip) if not needCatchup
                    OtTransformer.applyFutureOps(BlipOtConverter.toOt(blip), (err, changeSet) ->
                        return callback(err) if err
                        _.extend(blip, changeSet)
                        callback(null)
                    )
                (callback) ->
                    return callback(null) if not loadWave
                    require('../wave/couch_processor').CouchWaveProcessor.getById(blip.waveId, (err, wave) ->
                        return callback(err) if err
                        blip.setWave(wave)
                        callback(null)
                    )
            ]
            async.parallel(tasks, (err) ->
                callback(err, if err then null else blip)
            )
        super(blipId, onBlipGot, needCatchup)

    getVersionByIds: (ids, callback) ->
        viewParams =
            keys: ids
        @view('blip_version_by_id/get', viewParams, (err, results) ->
            versions = {}
            return callback(err, null) if err
            versions[result.key] = result.value for result in results
            callback(null, versions)
        )

    getByWaveId: (waveId, callback, ignoreRemovedBlips) ->
        @getByWaveIds(waveId, callback, ignoreRemovedBlips)

    getChildIdsByWaveId: (waveId, callback) =>
        ###
        Возвращает массив id детей блипа в нужной волне
        ###
        viewParams =
            startkey: [waveId, DateUtils.getCurrentTimestamp() - @FOREVER_REMOVED_BLIP_TIME]
            endkey: [waveId, @PLUS_INF]
        @view('blip_child_ids_by_wave_id_1/get', viewParams, (err, res) ->
            return callback(err, null) if err
            vertexes = {}
            vertexes[raw.id] = raw.value for raw in res
            callback(null, vertexes)
        )

    getWithChildsByIdAsDict: (blipIds, waveId, callback) ->
        ###
        Загружает блип и его поддерево блипов
        ###
        tasks = [
            async.apply(@getChildIdsByWaveId, waveId)
            (waveVertexes, callback) =>
                @getWithChildsByIdUsingWaveTreeAsDict(blipIds, waveVertexes, callback)
        ]
        async.waterfall(tasks, callback)

    getWithChildsByIdUsingWaveTree: (blipIds, waveVertexes, callback) ->
        ###
        загружает все блипы волны переданному дереву
        ###
        blipIds = @_getChildTreeIds(blipIds, waveVertexes)
        @getByIds(blipIds, callback)

    getWithChildsByIdUsingWaveTreeAsDict: (blipIds, waveVertexes, callback) ->
        ###
        загружает все блипы волны переданному дереву
        ###
        blipIds = @_getChildTreeIds(blipIds, waveVertexes)
        @getByIdsAsDict(blipIds, callback)

    getNonSentBlipsByTimestampAsDict: (from, to, callback) ->
        ###
        Все неотправленные мэншены по таймстэмпу {id: model}
        ###
        viewParms =
            startkey: from
            endkey: to
        @viewWithIncludeDocsAsDict("nonsent_blips_by_time/get", viewParms, callback)

    _getChildTreeIds: (blipIds, waveVertexes) ->
        ###
        @todo: получше название
        ###
        ids = []
        for blipId in blipIds
            ids.push(@getChildTreeIds(blipId, (id) -> waveVertexes[id]))
        return [].concat(ids...)

    getChildTreeIds: (blipId, getChildIds, treeIds=[]) ->
        treeIds.push(blipId) if not treeIds.length
        childIds = getChildIds(blipId) or []
        for childId in childIds
            treeIds.push(childId)
            @getChildTreeIds(childId, getChildIds, treeIds)
        return treeIds

    getByNeedNotificateAsDict: (from, to, callback) ->
        ###
        Достает блипы о которых нужно уведомить
        ###
        viewParms =
            startkey: from
            endkey: to
        @viewWithIncludeDocsAsDict("blip_by_need_notificate/get", viewParms, callback)

    getByAnswerIds: (childIds, callback) ->
        ###
        Достает блипы ответами на которые являются переданные id блипов
        ###
        tasks = [
            (callback) =>
                @view("blip_parent_id_by_id/get",{keys: childIds}, callback)
            (res, callback) =>
                ids = (row.value for row in res)
                @getByIdsAsDict(ids, (err, blips) ->
                    callback(err, null) if err
                    callback(null,res, blips)
                )
            (res, blips, callback) ->
                blipsByChildsIds = {}
                for row in res
                    blipsByChildsIds[row.key] = blips[row.value]
                callback(null, blipsByChildsIds)
        ]
        async.waterfall(tasks, callback)

    getByChildIds: (childIds, callback) ->
        ###
        Достает блипы родителей блипов
        ###
        tasks = [
            (callback) =>
                @view("blip_real_parent_id_by_id/get",{keys: childIds}, callback)
            (res, callback) =>
                ids = (row.value for row in res)
                @getByIdsAsDict(ids, (err, blips) ->
                    callback(err, null) if err
                    callback(null,res, blips)
                )
            (res, blips, callback) ->
                blipsByChildsIds = {}
                for row in res
                    blipsByChildsIds[row.key] = blips[row.value]
                callback(null, blipsByChildsIds)
        ]
        async.waterfall(tasks, callback)

module.exports =
    CouchBlipProcessor: new CouchBlipProcessor()
    CouchBlipProcessorClass: CouchBlipProcessor
