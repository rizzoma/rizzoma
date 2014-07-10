Model = require('../common/model').Model

class WaveImportData extends Model
    ###
    Source
    Импортируемая волна
    ###
    constructor: (@id=null, @userId=null, @sourceData=null, @lastUpdateTimestamp=null, @lastImportingTimestamp=null, @importedWaveId=null, @importedWaveUrl=null, @_rev=undefined, @participants=[], blipIds=null) ->
        ###
        @param id: string — waveId из google wave
        @param userId: string — id чела попросившего заимпортить волну
        @param sourceData: string — исходный код импортируемой волны
        @param lastUpdateTimestamp: timstamp — время последнего запроса на импорт волны
        @param lastImportingTimestamp: timstamp — время последнего импорта волны в odessa
        @param importedWaveId: string — соответствующий WaveId из odessa
        ###
        super('WaveImportData')
        
module.exports.WaveImportData = WaveImportData
