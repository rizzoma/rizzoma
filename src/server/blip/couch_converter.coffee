CouchConverter = require('../common/db/couch_converter').CouchConverter
BlipModel = require('./models').BlipModel

class BlipCouchConverter extends CouchConverter
    constructor: () ->
        super(BlipModel)
        fields =
            waveId: 'waveId'
            content: 'content'
            readers: 'readers'
            removed: 'removed'
            contentTimestamp: 'contentTimestamp'
            isRootBlip: 'isRootBlip'
            isContainer: 'isContainer'
            contributors: 'contributors'
            isFoldedByDefault: 'isFoldedByDefault'
            pluginData: 'pluginData'
            contentVersion: 'contentVersion'
            needNotificate: 'needNotificate'
            notificationRecipients: 'notificationRecipients'
        @_extendFields(fields)

module.exports.BlipCouchConverter = new BlipCouchConverter()
