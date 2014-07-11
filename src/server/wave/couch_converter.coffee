CouchConverter = require('../common/db/couch_converter').CouchConverter
WaveModel = require('./models').WaveModel
ParticipantModel = require('./models').ParticipantModel

class WaveCouchConverter extends CouchConverter
    constructor: () ->
        super(WaveModel)
        fields =
            rootBlipId: 'rootBlipId'
            containerBlipId: 'containerBlipId'
            contentTimestamp: 'contentTimestamp'
            sharedState: 'sharedState'
            urls: 'urls'
            sharedToSocial: 'sharedToSocial'
            sharedToSocialTime: 'sharedToSocialTime'
            defaultRole: 'defaultRole'
            topicType: 'topicType'
            options: '_options'
            balance: '_balance'
            gDriveId: 'gDriveId'
            gDrivePermissions: 'gDrivePermissions'
        @_extendFields(fields)

    toModel: (doc) ->
        model = super(doc)
        for participant in doc.participants
            participantModel = new ParticipantModel(participant.id, participant.role, participant.ptags, participant.blockingState, participant.actionLog)
            model.participants.push(participantModel)
        return model

    toCouch: (model) ->
        doc = super(model)
        doc.sharedState = model.getSharedState()
        doc.participants = (participant.toObject() for participant in model.participants)
        return doc

module.exports.WaveCouchConverter = new WaveCouchConverter()
