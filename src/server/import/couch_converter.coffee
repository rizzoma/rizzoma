CouchConverter = require('../common/db/couch_converter').CouchConverter
WaveImportData = require('./models').WaveImportData

class WaveImportDataCouchConverter extends CouchConverter
    constructor: () ->
        super(WaveImportData)
        fields =
            userId: 'userId'
            participants: 'participants'
            sourceData: 'sourceData'
            lastUpdateTimestamp: 'lastUpdateTimestamp'
            lastImportingTimestamp: 'lastImportingTimestamp'
            importedWaveId: 'importedWaveId'
            importedWaveUrl: 'importedWaveUrl'
            blipIds: 'blipIds'
            public: 'public'
        @_extendFields(fields)
        

module.exports.WaveImportDataCouchConverter = new WaveImportDataCouchConverter()