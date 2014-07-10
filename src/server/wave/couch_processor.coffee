_ = require('underscore')
CouchProcessor = require('../common/db/couch_processor').CouchProcessor
WaveCouchConverter = require('./couch_converter').WaveCouchConverter
WaveOtConverter = require('./ot_converter').WaveOtConverter
OtTransformer = require('../ot/utils').OtTransformer
ParticipantModel = require('./models').ParticipantModel

class CouchWaveProcessor extends CouchProcessor
    ###
    Класс, представляющий процессор волны в БД.
    ###
    constructor: (args...) ->
        super(args...)
        @converter = WaveCouchConverter
        @_cache = @_conf.getCache('wave')

    getById: (waveId, callback, needCatchup) ->
        onWaveGot = (err, wave) =>
            @_catchUp(err, wave, callback, needCatchup)
        super(waveId, onWaveGot, needCatchup)

    getByUrl: (url, callback, needCatchup) ->
        ###
        Получает волну по ее url.
        @param url: string
        @param callback: function
        ###
        viewParams = {key: ['wave', url]}
        onWaveGot = (err, wave) =>
            @_catchUp(err, wave, callback, needCatchup)
        @getOne('waves_by_url_2/get', viewParams, onWaveGot, needCatchup)

    _catchUp: (err, wave, callback, needCatchup) ->
        return callback(err, wave) if err or not needCatchup
        OtTransformer.applyFutureOps(WaveOtConverter.toOt(wave), (err, changeSet) ->
            return callback(err, null) if err
            participants = changeSet.participants or []
            for p, i in participants
                participants[i] = new ParticipantModel(p.id, p.role, p.ptags, p.blockingState, p.actionLog)
            callback(null, _.extend(wave, changeSet))
        )

    getByUrls: (urls, callback) =>
        ###
        Получает волну по ее url.
        @param url: string
        @param callback: function
        ###
        viewParams = {keys: (['wave', url] for url in urls)}
        @viewWithIncludeDocs('waves_by_url_2/get', viewParams, callback)

    getByGDriveId: (gDriveId, callback, needCatchup) =>
        ###
        Получает волну по ее id документа в Google Drive.
        @param gDriveId: string
        @param callback: function
        ###
        viewParams = {key: ['gDrive', gDriveId]}
        onWaveGot = (err, wave) =>
            @_catchUp(err, wave, callback, needCatchup)
        @getOne('waves_by_url_2/get', viewParams, onWaveGot, needCatchup)

module.exports.CouchWaveProcessor = new CouchWaveProcessor()