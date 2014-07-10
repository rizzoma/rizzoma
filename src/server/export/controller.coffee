ACTIONS = require('../wave/constants').ACTIONS

async = require('async')

BlipProcessor = require('../blip/processor').BlipProcessor
FileProcessor = require('../file/processor').FileProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
WaveExportMarkupBuilder = require('./wave').WaveExportMarkupBuilder
WaveProcessor = require('../wave/processor').WaveProcessor

class ExportController

    _getUserIds: (wave) ->
        ids = []
        for participant in wave.participants
            ids.push(participant.id)
        return ids

    _getFileIds: (blips) ->
        ids = []
        for blip in blips
            ids = ids.concat(blip.getFileIds())
        return ids

    getWaveExportMarkup: (wave, params, callback) ->
        funcs = [
            (callback) =>
                ids = @_getUserIds(wave)
                UserCouchProcessor.getByIds(ids, (error, users) ->
                    callback(error, users)
                )
            (users, callback) ->
                BlipProcessor.getBlipsByWaveId(wave.id, (error, blips) ->
                    callback(error, users, blips)
                )
            (users, blips, callback) =>
                ids = @_getFileIds(blips)
                FileProcessor.getFilesInfo(ids, (error, files) ->
                    callback(error, users, blips, files)
                )
        ]
        async.waterfall(funcs, (error, users, blips, files) ->
            return callback(error) if error
            builder = new WaveExportMarkupBuilder(wave, users, blips, files, params)
            markup = builder.build()
            callback(error, markup)
        )

controller = new ExportController()
exports.ExportController = controller
exports.loadMarkup = (user, waveUrl, callback) ->
    funcs = [
        (callback) ->
            WaveProcessor.getWaveByUrl(waveUrl, (error, wave) ->
                return callback(error) if error
                error = wave.checkPermission(user, ACTIONS.ACTION_READ)
                callback(error, wave, user)
            )
        (wave, user, callback) ->
            error = wave.checkPermission(user, ACTIONS.ACTION_FULL_PROFILE_ACCESS)
            params = {needFullUserInfo: not error}
            controller.getWaveExportMarkup(wave, params, callback)
    ]
    async.waterfall(funcs, callback)
