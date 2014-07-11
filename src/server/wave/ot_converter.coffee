DocumentOtConverter = require('../common/ot/converter').DocumentOtConverter

class WaveOtConverter extends DocumentOtConverter
    ###
    Ot-конвертор модели волны.
    ###
    constructor: () ->
        super()
        @_snapshotFields =
            rootBlipId: 'rootBlipId'
            containerBlipId: 'containerBlipId'
            sharedState: 'sharedState'

    toOt: (model) ->
        doc = super(model)
        doc.participants = (participant.toObject() for participant in model.participants)
        return doc

    toClient: (model) ->
        doc = super(model)
        doc.docId = model.getUrl()
        doc.socialSharingUrl = model.getSocialSharingUrl()
        doc.snapshot.defaultRole = model.getDefaultRole()
        doc.snapshot.participants = (participant.toObject() for participant in model.participants)
        doc.snapshot.gDriveId = model.getGDriveId()
        return doc

module.exports.WaveOtConverter = new WaveOtConverter()