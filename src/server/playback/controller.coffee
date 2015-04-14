_ = require('underscore')
async = require('async')
OtProcessorFrontend = require('../ot/processor_frontend').OtProcessorFrontend
OperationOtConverter = require('../ot/operation_ot_converter').OperationOtConverter
WaveProcessor = require('../wave/processor').WaveProcessor
WaveOtConverter = require('../wave/ot_converter').WaveOtConverter
BlipProcessor = require('../blip/processor').BlipProcessor
BlipOtConverter = require('../blip/ot_converter').BlipOtConverter


ACTIONS = require('../wave/constants').ACTIONS
MAX_OPS_COUNT = 1000
MAX_OPS_COUNT_PER_BLIP = 100

class PlaybackController

    getPlaybackData: (url, blipId, user, callback) ->
        tasks = [
            (callback) ->
                WaveProcessor.getWaveByUrl(url, (err, wave) ->
                    return callback(err) if err
                    err = wave.checkPermission(user, ACTIONS.ACTION_WRITE)
                    callback(err, wave)
                )
            (wave, callback) =>
                BlipProcessor.getChidBlipsByWaveId(wave.id, [blipId], (err, blips) =>
                    return callback(err) if err
                    containerBlip = BlipProcessor.getContainerModel('playback_container', wave.id, blipId, user)
                    @_attachContainerBlipToWave(containerBlip, wave, blipId)
                    blips[containerBlip.id] = containerBlip
                    callback(null, wave, blips, @_getOpRanges(blips, wave, containerBlip.id))
                )
            (wave, blips, opRanges, callback) =>
                OtProcessorFrontend.getOpRangeForMultipleDocs(opRanges, (err, ops) =>
                    callback(err, @_getPlaybackData(wave, blips, ops, user))
                )
        ]
        async.waterfall(tasks, callback)

    _attachContainerBlipToWave: (containerBlip, wave, rootBlipId) ->
        wave.containerBlipId = containerBlip.id
        wave.rootBlipId = rootBlipId

    _getOpRanges: (blips, wave, containerBlipId) ->
        opRanges = {}
        blipsAsList = _.values(blips)
        factor = (2*MAX_OPS_COUNT)/Math.pow(blipsAsList.length, 2)
        # | 0 is like Math.floor
        getOpsCount = (i) -> (factor * (blipsAsList.length-i) | 0) or 1
        for blip, i in _.sortBy(blipsAsList, (blip) -> -blip.contentTimestamp)
            #it shouldn't be in this method, but i wouldn't iterate blips again
            blip.setWave(wave)
            continue if blip.id == containerBlipId
            versionFrom = blip.version - getOpsCount(i)
            versionFrom = 0 if versionFrom < 0
            opRanges[blip.id] = [versionFrom, blip.version]
        return opRanges

    _getPlaybackData: (wave, blips, ops, user) ->
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
        return data

    getBlipForPlayback: (blipId, user, callback) ->
        tasks = [
            (callback) ->
                BlipProcessor.getBlip(blipId, (err, blip) ->
                    return callback(err) if err
                    err = blip.checkPermission(user, ACTIONS.ACTION_WRITE)
                    callback(err, blip)
                )
            (blip, callback) ->
                versionFrom = blip.version - MAX_OPS_COUNT_PER_BLIP
                versionFrom = 0 if versionFrom < 0
                OtProcessorFrontend.getOpRange(blip.id, versionFrom, blip.version, (err, ops) ->
                    blipInClientRepr = BlipOtConverter.toClient(blip, user)
                    blipInClientRepr.meta.ops = (OperationOtConverter.toClient(op) for op in ops)
                    callback(err, blipInClientRepr)
                )
        ]
        async.waterfall(tasks, callback)

    getPlaybackOps: (blipId, offset, user, callback) ->
        tasks = [
            (callback) ->
                BlipProcessor.getBlip(blipId, (err, blip) ->
                    return callback(err) if err
                    err = blip.checkPermission(user, ACTIONS.ACTION_WRITE)
                    callback(err, blip)
                )
            (blip, callback) ->
                versionTo = blip.version - offset
                versionFrom = versionTo - MAX_OPS_COUNT_PER_BLIP
                versionFrom = 0 if versionFrom < 0
                OtProcessorFrontend.getOpRange(blip.id, versionFrom, versionTo, (err, ops) ->
                    callback(err, (OperationOtConverter.toClient(op) for op in ops))
                )
        ]
        async.waterfall(tasks, callback)

module.exports.PlaybackController = new PlaybackController()
