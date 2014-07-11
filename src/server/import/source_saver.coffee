_ = require('underscore')
async = require('async')
CouchImportProcessor = require('./couch_processor').CouchImportProcessor
ex = require('./exceptions')
DateUtils = require('../utils/date_utils').DateUtils
WaveImportData = require('./models').WaveImportData
ImportSourceParser = require('./source_parser').ImportSourceParser
waveCts = require('../wave/constants')
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor

class SourceSaver
    constructor: () ->
    
    _getWaveId: (waveData) ->
        ###
        Возвращает id по которому будет сохранен снимок волны
        waveId+waveletId
        @param: waveData: Object
        @returns: string
        ###
        if not waveData[0] or not waveData[0].data or not waveData[0].data.waveletData
            return null
        waveletData = waveData[0].data.waveletData
        return waveletData.waveId + '_' + waveletData.waveletId
    
    _checkWaveData: (waveData, callback) =>
        waveId = @_getWaveId(waveData)
        if not waveId
            return callback(new ex.SourceParseImportError('Wrong wave source format'))
        
        CouchImportProcessor.getById(waveId, (err, dbWave) ->
            return callback(err) if err and err.message != 'not_found'
            return callback(null) if err
            if dbWave.lastImportingTimestamp and dbWave.importedWaveId
                err = new ex.WaveAlreadyImportedImportError('Wave already imported', { gWaveId: waveId, importedWaveId: dbWave.importedWaveUrl})
            else
                err = new ex.WaveImportingInProcessImportError('Wave importing in process', { gWaveId: waveId, importedWaveId: dbWave.importedWaveUrl})
            callback(err)
        )
    
    _addUserToParticipants: (user, waveDataObj, callback) ->
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                waveletData = waveDataObj[0].data.waveletData
                participantsData = ImportSourceParser.parseParticipantsEmailsAndRoles(waveletData)
                if _.isEmpty(participantsData.participantRoles) or not participantsData.participantRoles[user.email]
                    participantsData.participantRoles[user.email] = waveCts.WAVE_ROLE_MODERATOR
                    participantsData.partcipantEmails.push(user.email)
                    waveletData.participants = participantsData.partcipantEmails
                    waveletData.participantRoles = participantsData.participantRoles
                callback(null, waveDataObj)
        ]
        async.waterfall(tasks, callback)

    save: (user, waveData, callback) ->
        try
            waveDataObj = ImportSourceParser.sourceToObject(waveData)
        catch e
            console.error(e)
            return callback(new SourceParseError('Wrong wave source format'), null)
        waveId = @_getWaveId(waveDataObj)
        model = new WaveImportData(waveId)
        waveletData = waveDataObj[0].data.waveletData
        model.public = 'public@a.gwave.com' in waveletData.participants
        tasks = [
            async.apply(@_checkWaveData, waveDataObj)
            async.apply(@_addUserToParticipants, user, waveDataObj)
            (waveDataObj, callback) =>
                model.userId = user.id
                waveletData = waveDataObj[0].data.waveletData
                participantsData = ImportSourceParser.parseParticipantsEmailsAndRoles(waveletData)
                model.participants = participantsData.partcipantEmails
                try
                    model.sourceData = JSON.stringify(waveDataObj)
                catch err
                    console.error(e)
                    return callback(new SourceParseError('Wrong wave source format'))
                model.lastUpdateTimestamp = DateUtils.getCurrentTimestamp()
                CouchImportProcessor.save(model, callback)  
        ]
        async.waterfall(tasks, (err) ->
            callback(err, waveId)
        )

module.exports.SourceSaver = new SourceSaver()