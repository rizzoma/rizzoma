async = require('async')
{IndexSourceGeneratorClass} = require('../index_source_generator')
{CouchBlipProcessor} = require('../../../blip/couch_processor')
{CouchWaveProcessor} = require('../../../wave/couch_processor')
{StateProcessor} = require('./state')
Conf = require('../../../conf').Conf

class FullIndexSourceGenerator extends IndexSourceGeneratorClass
    ###
    Класс, представляющий генератор исходных данных для полной переиндексации.
    ###
    constructor: () ->
        super()
        @_conf = Conf.getSearchIndexerConf() || {}
        @_packSize = @_conf.fullIndexingPackSize or 20000

    outDeltaIndexSource: (callback) ->
        indexFrom = StateProcessor.getState().startId
        process.stderr.write("Starting process from #{indexFrom}\n")
        tasks = [
            (callback) =>
                @_getBlips(indexFrom, @_packSize, callback)
            (blips, callback) =>
                blipsToIndex = []
                for blip in blips
                    wave = blip.getWave()
                    if not wave
                        process.stderr.write("Blip #{blip.id} has no wave!!!\n")
                    if wave and blip.id != wave.containerBlipId
                        blipsToIndex.push(blip)
                @_outputUniqueBlipsXML(blipsToIndex, (err) ->
                    return callback(err, null) if err
                    callback(null, blips)
                )
            (blips, callback) =>
                StateProcessor.saveState(blips)
                callback(null)
        ]
        async.waterfall(tasks, (err) ->
            if err
                process.stderr.write("Got error when generating delta index\n")
                process.stderr.write("#{require('util').inspect(err)}\n")
            process.stderr.write("Finished generation of delta index\n")
            callback?(null)
        )

    _getBlips: (indexFrom, limit, callback) ->
        ###
        @param timeFrom: number
        @param docFrom: string
        @param limit: number
        ###
        tasks = [
            (callback) ->
                # первый раз выбираем включая indexFrom id, остальные разы исключая indexFrom
                CouchBlipProcessor.getAllIds(indexFrom, "0_b_{", limit, indexFrom != "0_b_0", callback)
            (blipIds, callback) ->
                return callback(null, []) if not blipIds.length
                CouchBlipProcessor.getByIds(blipIds, callback)
            (blips, callback) ->
                waveIds = (blip.waveId for blip in blips)
                CouchWaveProcessor.getByIdsAsDict(waveIds, (err, waves) ->
                    return callback(err) if err
                    blip.setWave(waves[blip.waveId]) for blip in blips
                    callback(null, blips)
                )
        ]
        async.waterfall(tasks, callback)

module.exports.FullIndexSourceGenerator = new FullIndexSourceGenerator()
