_ = require('underscore')
async = require('async')
WAVE_SHARED_STATE_PUBLIC = require('../wave/constants').WAVE_SHARED_STATE_PUBLIC
CouchWaveProcessor = require('../wave/couch_processor').CouchWaveProcessor
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
Conf = require('../conf').Conf
DbError = require('../common/db/exceptions').DbError
DateUtils = require('../utils/date_utils').DateUtils
Anonymous = require('../user/anonymous')
WaveCouchConverter = require('../wave/couch_converter').WaveCouchConverter
BlipCouchConverter = require('../blip/couch_converter').BlipCouchConverter

class CouchSearchProcessor
    ###
    Класс, представляющий процессор для поиска.
    ###
    constructor: () ->
        @_db = Conf.getDb('main')
        @_mergingDocId = 'last_merging_timestamp' #документ для запоминания времени последнего слияния индексов.

    _saveDoc: (id, rev, timestamp, callback) ->
        ###
        Вспомогательный метод. Сохраняет документ.
        @param id: string
        @param rev: string
        @timestamp: number
        @param callback: function
        ###
        content =
            contentTimestamp: timestamp
        onSave = (err, res) ->
            if err
                callback(err, res)
                return
            callback(err, timestamp)
        if rev
            @_db.save(id, rev, content, onSave)
        else
            @_db.save(id, content, onSave)

    _getOrCreateDoc: (id, defaultValue, callback) ->
        ###
        Вспомогательный метод. Возвращает документ или создает с заданным значением.
        @param id: string
        @param defaultValue: ?
        @param callback: function
        ###
        @_db.get(id, (err, doc) =>
            if err
                if err.error = 'not_found'
                    @_saveDoc(id, null, defaultValue, callback)
                    return
                callback(new DbError(err), null)
                return
            callback(null, doc.contentTimestamp)
        )

    _updateOrCreateDoc: (id, value, callback) ->
        ###
        Вспомогательный метод. Обновляет или создает документ с указанным значением.
        @param id: string
        @param value: ?
        @param callback: function
        ###
        @_db.get(id, (err, doc) =>
            if err
                if err.error == 'not_found'
                    @_saveDoc(id, null, value, callback)
                    return
                callback(new DbError(err), null)
            @_saveDoc(id, doc._rev, value, callback)
        )

    getLastMergingTimestamp: (callback) ->
        ###
        Возвращает время последнего слияния индексов.
        @param callback: function
        ###
        @_getOrCreateDoc(@_mergingDocId, DateUtils.getCurrentTimestamp(), callback)

    setLastMergingTimestamp: (timestamp, callback) ->
        ###
        Устанавливает время последнего слияния индексов.
        @param timestamp: number
        @param callback: function
        ###
        @_updateOrCreateDoc(@_mergingDocId, timestamp, callback)

    getBlipsByTimestamp: (timeFrom, docFrom, limit, callback) ->
        ###
        Возвращает массив моделей блипов, измененных в интервале с (from, docFrom)
        до конца. Возвращает не более limit записей.
        @param timeFrom: number
        @parma docFrom: string
        @param limit: number
        @param callback: function
        @return:
            nextTimeFrom: number
            nextDocFrom: string
            blips: [BlipModel]
        ###
        viewParams = {
            startkey: timeFrom
            limit: limit + 1
            include_docs: true
        }
        viewParams.startkey_docid = docFrom if docFrom
        @_db.view('search/docs_by_timestamp', viewParams, (err, res) =>
            return callback(new DbError(err), null) if err
            nextTimeFrom = null
            nextDocFrom = null
            if res.length > limit
                lastRes = res.pop()
                nextTimeFrom = lastRes.key
                nextDocFrom = lastRes.id
            try
                [blips, waves, blipsByWaveId] = @_getGroupedDocsStructures(res)
            catch e
                return callback(e)
            tasks = [
                (callback) =>
                    @_addBlipsByWaves(waves, blips, callback)
                (callback) =>
                    @_addWavesToBlips(blipsByWaveId, callback)
            ]
            async.parallel(tasks, (err) ->
                return callback(err) if err
                result =
                    nextTimeFrom: nextTimeFrom
                    nextDocFrom: nextDocFrom
                    blips: _.values(blips)
                callback(null, result)
            )
        )

    _getDocType: (doc) ->
        return doc.type

    _addBlipsByWaves: (waves, result, callback) ->
        ###
        Выбирает из базы и добвляет в result блипы из переданных волн.
        @param waves: object - список волн (WaveModel), ключ - id волны.
        @param result: object - результирующий список блипов, ключ id блипа.
        @param callback: function
        ###
        CouchBlipProcessor.getByWaveIds(_.keys(waves), (err, blips) =>
            return callback(err, null) if err
            for blip in blips
                blip.setWave(waves[blip.waveId])
                result[blip.id] = blip
            callback(null, true)
        )

    _addWavesToBlips: (blipsByWaveId, callback) ->
        ###
        Загружает волны из бд и проставляет их соответствующим блипам, загруженным ранее
        @params blipsByWaveId - object блипы по id волны, key - id волны, value - массив блипов (BlipModel)
        @param callback: function
        ###
        CouchWaveProcessor.getByIds(_.keys(blipsByWaveId), (err, waves) =>
            return callback(err, null) if err
            for wave in waves
                blips = blipsByWaveId[wave.id]
                for blip in blips
                    blip.setWave(wave)
            callback(null, true)
        )

    _getGroupedDocsStructures: (docs) ->
        ###
        Возвращает структуры из загруженных документов, удобные для дальнейшей догрузки данных.
        @param docs: array - список документов, полученных из БД.
        @returns: array - [blips, waves, blipsByWaveId].
        ###
        blips = {}
        waves = {}
        blipsByWaveId = {}
        for doc in docs
            continue if doc.error or not doc.doc
            doc = doc.doc
            if @_getDocType(doc) == 'wave'
                wave = WaveCouchConverter.toModel(doc)
                waves[wave.id] = wave
            else
                blip = BlipCouchConverter.toModel(doc)
                blipsByWaveId[blip.waveId] ||= []
                blipsByWaveId[blip.waveId].push(blip)
                blips[blip.id] = blip
        return [blips, waves, blipsByWaveId]

module.exports =
    CouchSearchProcessor: new CouchSearchProcessor()
