DocumentOtConverter = require('../common/ot/converter').DocumentOtConverter

class BlipOtConverter extends DocumentOtConverter
    ###
    Ot-конвертор модели блипа.
    ###
    constructor: () ->
        super()
        @_snapshotFields =
            content: 'content'
            isRootBlip: 'isRootBlip'
            isContainer: 'isContainer'
            contributors: 'contributors'
            isFoldedByDefault: 'isFoldedByDefault'
            pluginData: 'pluginData'

    toClient: (model, user) ->
        doc = super(model)
        doc.docId = model.id
        doc.meta.waveId = model.getWave().getUrl()
        return doc if user.isAnonymous()
        doc.meta.isRead = model.getReadState(user)
        doc.meta.title = model.getTitle() if model.isRootBlip
        return doc

module.exports.BlipOtConverter = new BlipOtConverter()
