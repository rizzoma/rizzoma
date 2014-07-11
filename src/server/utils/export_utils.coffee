async = require('async')
WaveProcessor = require('../wave/processor').WaveProcessor
BlipProcessor = require('../blip/processor').BlipProcessor

class ExportUtils
    constructor: () ->

    ExportTopicAsHTML: (waveUrl, callback) ->


    _getBlips: (waveUrl, callback) ->
        tasks = [
            async.apply(WaveProcessor.getWaveByUrl, waveUrl)
            (wave, callback) ->
                BlipProcessor.getBlipsyWaveIdAsDict(wave.id, callback)
        ]
        async.waterfall(callback)

    _rendreTopic: (blips) ->
        rootBlip = @_getRootBlip(blips)

    _renderBlip: (blip) ->
        blip.iterateBlock((type, block) ->

        )

    _getRootBlip: (blips) ->
        for id, blip of blips
            return blip if blip.isRootBlip
        return