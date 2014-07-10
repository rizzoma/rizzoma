async = require('async')
_ = require('underscore')
DateUtils = require('../utils/date_utils').DateUtils
CouchImportProcessor = require('./couch_processor').CouchImportProcessor
ImportSourceParser = require('./source_parser').ImportSourceParser
CouchWaveProcessor = require('../wave/couch_processor').CouchWaveProcessor
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
WaveGenerator = require('../wave/generator').WaveGenerator

SOURCES_LIMIT = 50

class WaveImporter
    
    _parseWave: (waveId, source, blipIds, callback) ->
        ###
        парсит одну волну
        ###
        ImportSourceParser.parse(waveId, source, blipIds, callback)
        
    _saveWaveBlips: (blips, callback) ->
        CouchBlipProcessor.bulkSave(blips, callback)
        
    _removeBlips: (blips, callback) ->
        tasks = []
        for blip in blips
            tasks.push(do(blip) ->
                return async.apply(CouchBlipProcessor.remove, blip)
            )
        async.parallel(tasks, callback)

    _removeWaveBlips: (waveId, callback) =>
        CouchBlipProcessor.getByWaveId(waveId, (err, blips) =>
            return callback(err) if err
            @_removeBlips(blips, callback)
        )
        
    _removeWave: (waveId, callback) =>
        CouchWaveProcessor.getById(waveId, (err, wave) ->
            return callback(null, true) if err and err.message == 'not_found'
            return callback(err, null) if err
            CouchWaveProcessor.remove(wave, callback)
        )

    _clearWavePreviousImport: (waveId, callback) ->
        tasks = [
            async.apply(@_removeWaveBlips, waveId)
            async.apply(@_removeWave, waveId)
        ]
        async.parallel(tasks, callback)
        
    _importWave: (model, callback) =>
        console.log("Importing wave '#{model.id}'")
        tasks = []
        tasks.push((callback) =>
            return callback(null) if not model.importedWaveId
            @_clearWavePreviousImport(model.importedWaveId, (err, res) ->
                callback(err)
            )
        )
        tasks.push((callback) ->
            return callback(null, model.importedWaveId) if model.importedWaveId
            WaveGenerator.getNext(callback)
        )
        tasks.push((waveId, callback) ->
            sourceObj = ImportSourceParser.sourceToObject(model.sourceData)
            sourceData = sourceObj[0].data
            blipsData = sourceData.blips
            ImportSourceParser.generateBlipIds(waveId, blipsData, (err, blipIds) ->
                return callback(err, null) if err
                callback(null, waveId, blipIds)
            )
        )
        tasks.push((waveId, blipIds, callback) ->
            model.importedWaveId = waveId
            model.blipIds = blipIds
            CouchImportProcessor.save(model, (err, rev)->
                return callback(err, null) if err
                model._rev = rev
                callback(null, waveId, blipIds)
            )
        )
        tasks.push((waveId, blipIds, callback) =>
            @_parseWave(waveId, model.sourceData, blipIds, callback)
        )
        tasks.push((wave, blips, callback) =>
            @_saveWaveBlips(blips, (err) ->
                callback(err, wave)
            )
        )
        tasks.push((wave, callback) =>
            wave.urls = [model.importedWaveUrl] if model.importedWaveUrl
            CouchWaveProcessor.save(wave, (err, res) ->
                callback(err, wave)
            )
        )
        tasks.push((wave, callback) ->
            model.lastImportingTimestamp = DateUtils.getCurrentTimestamp()
            model.importedWaveUrl = wave.getUrl() if not model.importedWaveUrl
            CouchImportProcessor.save(model, callback)
        )
        async.waterfall(tasks, callback)
        
    _importWaves: (sources, callback) ->
        tasks = []
        for model in sources
            tasks.push(do(model) =>
                return (callback) =>
                    @_importWave(model, (err) ->
                        console.error(err) if err
                        process.nextTick(() ->
                            callback(null)
                        )
                    )
            )
        async.series(tasks, callback)
    
    run: (callback) ->
        tasks = [
            async.apply(CouchImportProcessor.getNotImported, SOURCES_LIMIT)
            (sources, callback) =>
                # shuffle sources to randomly skip waves that can't be imported (node.js errors)
                sources = _.shuffle(sources)
                @_importWaves(sources, callback)
        ]
        async.waterfall(tasks, (err) ->
            console.error(err) if err
            console.log('finished')
            callback(err)
        )

module.exports.Importer = new WaveImporter()
