async = require('async')
OtProcessorFrontend = require('../ot/processor_frontend').OtProcessorFrontend
OperationOtConverter = require('../ot/operation_ot_converter').OperationOtConverter
WaveProcessor = require('./processor').WaveProcessor
BlipProcessor = require('../blip/processor').BlipProcessor


ACTIONS = require('./constants').ACTIONS


class PlaybackController
    getPlaybackData: (url, blipId, user, callback) ->
        tasks = [
            (callback) ->
                WaveProcessor.getWaveByUrl(url, (err, wave) ->
                    return callback(err) if err
                    err = wave.checkPermission(user, ACTIONS.ACTION_WRITE)
                    callback(err, wave)
                )
            (wave, callback) ->
                BlipProcessor.getChidBlipsByWaveId(wave.id, [blipId], (err, blips) ->
                    return callback(err) if err
                    containerBlip = BlipProcessor.getContainerModel('playback_container', wave.id, blipId, user)
                    wave.containerBlipId = containerBlip.id
                    wave.rootBlipId = blipId
                    blips[containerBlip.id] = containerBlip
                    opRanges = {}
                    for own id, blip of blips
                        blip.setWave(wave)
                        continue if id == containerBlip.id
                        versionFrom = blip.version - 100
                        versionFrom = 0 if versionFrom < 0
                        opRanges[id] = [versionFrom, blip.version+1]
                    callback(null, wave, blips, opRanges)
                )
            (wave, blips, opRanges, callback) =>
                OtProcessorFrontend.getOpRangeForMultipleDocs(opRanges, (err, ops) =>
                    data = {wave: WaveOtConverter.toClient(wave), blips: []}
                    currentBlip = null
                    for op in ops
                        id = op.docId
                        if not currentBlip or currentBlip.docId != id
                            data.blips.push(currentBlip) if currentBlip
                            currentBlip = blips[id]
                            if not currentBlip
                                @_logger.warn("Bugcheck. Got playback op for not existing blip: ", {blipId: id, opId: op.id})
                                continue
                            delete blips[id]
                            currentBlip = BlipOtConverter.toClient(currentBlip, user)
                            currentBlip.meta.ops = []
                        currentBlip.meta.ops.push(OperationOtConverter.toClient(op))
                    data.blips.push(currentBlip) if currentBlip
                    for own id, blip of blips
                        convertedBlip = BlipOtConverter.toClient(blip, user)
                        convertedBlip.meta.ops = []
                        data.blips.push(convertedBlip)
                    callback(err, data)
                )
        ]
        async.waterfall(tasks, callback)



    getBlipForPlayback: (blipId, user, callback) ->
        tasks = [
            async.apply(@getBlip, blipId, user)
            (blip, callback) ->
                versionFrom = blip.version - 100
                versionFrom = 0 if versionFrom < 0
                OtProcessorFrontend.getOpRange(blip.id, versionFrom, blip.version, (err, ops) ->
                    callback(err, blip, ops)
                )
        ]
        async.waterfall(tasks, callback)


module.exports.PlaybackController = PlaybackController
