_ = require('underscore')
async = require('async')
BlipError = require('./exceptions').BlipError
BlipProcessor = require('./processor').BlipProcessor
WaveProcessor = require('../wave/processor').WaveProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
DriveController = require('../gdrive/controller')
Conf = require('../conf').Conf
IdUtils = require('../utils/id_utils').IdUtils

BLIP_OP_DENIED = require('./exceptions').BLIP_OP_DENIED
WAVE_PARTICIPANT_ALREADY_IN = require('../wave/exceptions').WAVE_PARTICIPANT_ALREADY_IN

ACTIONS = require('../wave/constants').ACTIONS
ROLE_NO_ROLE = require('../wave/constants').ROLE_NO_ROLE

class BlipController
    constructor: () ->
        @_logger = Conf.getLogger('blip-controller')

    createBlip: (url, author, content, callback) ->
        ###
        Создает блип.
        @param url: string
        @param author: UserModel - инициатор создания блипа.
        @param contributorsIds: array - список id редакторов блипа.
        @param content: array
        @param isFoldedByDefault: bool
        @param callback: function
        ###
        tasks = [
            async.apply(WaveProcessor.getWaveByUrl, url)
            (wave, callback) ->
                err = wave.checkPermission(author, ACTIONS.ACTION_COMMENT)
                callback(err, wave)
            (wave, callback) ->
                BlipProcessor.createBlip(wave.id, author, null, content, null, null, null, null, null, yes, callback)
        ]
        async.waterfall(tasks, callback)

    createCopiedBlip: (url, author, contributors, content, isFoldedByDefault, sourceBlipId, callback) ->
        ###
        Создает блип, получившийся в результате копирования.
        Заполняет блип данными оригинала и делает дополнительную проверку редакторов.
        @param url: string
        @param author: UserModel - инициатор создания блипа.
        @param contributors: array - список id редакторов блипа.
        @param content: array
        @param isFoldedByDefault: bool
        @param sourceBlipId: string - id блипа-источника.
        @param callback: function
        ###
        tasks = [
            async.apply(WaveProcessor.getWaveByUrl, url)
            (wave, callback) ->
                err = wave.checkPermission(author, ACTIONS.ACTION_COMMENT)
                callback(err, wave)
            (wave, callback) =>
                BlipProcessor.getBlip(sourceBlipId, (err, blip) =>
                    return callback(err) if err
                    err = blip.checkPermission(author, ACTIONS.ACTION_ADD_TO_TOPIC)
                    contributors = [] if err
                    callback(null, wave, blip.pluginData, @_getUniqContributorsIds(contributors))
                )
            (wave, pluginData, contributorsIds, callback) =>
                return callback(null, wave, pluginData, []) if not contributorsIds.length
                UserCouchProcessor.getByIds(contributorsIds, (err, contributors) ->
                    callback(err, wave, pluginData, contributors)
                )
            (wave, pluginData, contributors, callback) =>
                return callback(null, wave, pluginData, []) if not contributors.length
                WaveProcessor.addParticipants(wave.getUrl(), author, contributors, ROLE_NO_ROLE, (err, updatedWave) =>
                    @_logger.warn("Errro while creation copied blip: #{err}") if err and err.code != WAVE_PARTICIPANT_ALREADY_IN
                    callback(null, updatedWave or wave, pluginData, contributors)
                )
            (wave, pluginData, contributors, callback) ->
                BlipProcessor.createBlip(wave.id, author, contributors, content, null, null, isFoldedByDefault, null, pluginData, no, callback)
        ]
        async.waterfall(tasks, callback)

    _getUniqContributorsIds: (contributors) ->
        ids = []
        for contributor in contributors when contributor.id not in ids
            ids.push(contributor.id)
        return ids

    getBlip: (blipId, user, callback) =>
        ###
        Получает снэпшот блипа, в коллбэк вернет модель либо ошибку.
        @param blipId: string
        @param callback: function
        ###
        BlipProcessor.getBlip(blipId, (err, blip) =>
            return callback(err, null) if err
            err = blip.checkPermission(user, ACTIONS.ACTION_READ)
            return callback(err, null) if err
            callback(null, blip)
        )

    subscribeBlip: (blipId, user, version, listenerId, callback) ->
        ###
        Подписывает на изменение блипа.
        @param blipId: string
        @param version: number
        @param listenerId: string
        @param callId: string
        @param listener: function
        ###
        waveId = IdUtils.parseId(blipId).extensions
        BlipProcessor.subscribe(waveId, blipId, listenerId)
        BlipProcessor.getBlip(blipId, (err, blip) ->
            err = blip.checkPermission(user, ACTIONS.ACTION_READ) if not err
            if err
                BlipProcessor.unsubscribe(waveId, blipId, listenerId)
                return callback(err)
            BlipProcessor.fillDoc(waveId, listenerId, blipId, version, blip.version)
            callback(null)
        )

    updateBlipReader: (blipId, reader, callback) ->
        BlipProcessor.getBlip(blipId, (err, blip) =>
            return callback(err, null) if err
            err = blip.checkPermission(reader, ACTIONS.ACTION_READ)
            return callback(err, null) if err
            BlipProcessor.updateBlipReader(blip, reader, callback)
        )

    unsubscribeBlip: (blipId, user, listenerId, callback) ->
        ###
        Отписывает клиента от блипа.
        @param blipId: string
        @param listenerId: string
        @param callId: string
        @param callback: function
        ###
        BlipProcessor.getBlip(blipId, (err, blip) =>
            return callback(err, null) if err
            err = blip.checkPermission(user, ACTIONS.ACTION_READ)
            return callback(err) if err
            callback(null)
            waveId = IdUtils.parseId(blipId).extensions
            BlipProcessor.unsubscribe(waveId, blipId, listenerId)
        )

    postOp: (blipId, contributor, version, ops, random, listenerId, callback) ->
        tasks = [
            async.apply(BlipProcessor.getBlip, blipId)
            (blip, callback) ->
                [ordinarOps, inlineOps] = blip.splitOps(ops)
                return callback(null, blip, ordinarOps, inlineOps, {}) if _.isEmpty(inlineOps)
                BlipProcessor.getChildBlips(blip, _.keys(inlineOps), (err, childBlips) ->
                    callback(err, blip, ordinarOps, inlineOps, childBlips)
                )
            (blip, ordinarOps, inlineOps, childBlips, nextTask) ->
                [err, actions] = blip.checkOpPermission(ordinarOps, inlineOps, contributor, childBlips)
                return nextTask(err) if err
                BlipProcessor.postOp(blip, contributor, ops, version, random, listenerId, callback, (err, updatedBlip) ->
                    updatedBlip.setWave(blip.getWave()) if not err
                    nextTask(err, updatedBlip, actions, inlineOps, childBlips)
                )
            (blip, actions, inlineOps, childBlips, callback) =>
                @_processBlipAccess(blip, contributor, actions, inlineOps, childBlips, (err, blip) ->
                    callback(err, blip, actions)
                )
            (blip, actions, callback) ->
                WaveProcessor.processBlipAccess(blip.getWave(), contributor, actions, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err) if err
        )

    _processBlipAccess: (blip, contributor, actions, inlineOps, childBlips, callback) ->
        tasks = [
            (callback) ->
                return callback(null) if _.isEmpty(inlineOps)
                BlipProcessor.processInlineBlipOperation(childBlips, inlineOps, callback)
            (callback) ->
                for action in actions when action == ACTIONS.ACTION_WRITE
                    return BlipProcessor.addContributorBlip(blip, contributor, callback)
                callback(null)
            (callback) ->
                DriveController.updateWave(blip, contributor)
                callback(null)
        ]
        async.parallel(tasks, (err) ->
            callback(err, blip)
        )

module.exports.BlipController = new BlipController()
