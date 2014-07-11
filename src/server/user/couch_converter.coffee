UserModel = require('./model').UserModel
UserNotification = require('./notification').UserNotification
CouchConverter = require('../common/db/couch_converter').CouchConverter

class UserCouchConverter extends CouchConverter
    ###
    Конвертор моделей пользователей для БД.
    ###
    constructor: (args...) ->
        super(UserModel)
        fields =
            email: 'email'
            name: 'name'
            avatar: 'avatar'
            lastActivity: 'lastActivity'
            lastVisit: 'lastVisit'
            firstVisit: 'firstVisit'
            firstVisitNotificationSent: 'firstVisitNotificationSent'
            creationDate: 'creationDate'
            creationReason: 'creationReason'
            creationReferer: 'creationReferer'
            creationChannel: 'creationChannel'
            creationLanding: 'creationLanding'
            lastDigestSent: 'lastDigestSent'
            timezone: 'timezone'
            uploadSizeLimit: '_uploadSizeLimit'
            blockingState: 'blockingState'
            alternativeIds: '_alternativeIds'
            normalizedEmails: 'normalizedEmails'
            mergedWith: '_mergedWith'
            mergeDate: '_mergeDate'
            mergingValidationData: 'mergingValidationData'
            skypeId: 'skypeId'
            clientPreferences: 'clientPreferences'
            externalIds: '_externalIds'
            installedStoreItems: '_installedStoreItems'
            permissions: '_permissions'
            bonuses: '_bonuses'
            monthTeamTopicTax: '_monthTeamTopicTax'
            cardInfo: '_cardInfo'
            paymentLog: '_paymentLog'
            trialStartDate: '_trialStartDate'
            gDrive: 'gDrive'
        @_extendFields(fields)

    _getName: () ->
        return 'couchConverter'

    toCouch: (model) ->
        doc = super(model)
        doc.notification = model.notification
        return doc

    toModel: (doc) ->
        model = super(doc)
        model.notification = new UserNotification(doc.notification.id, doc.notification.state)
        model.notification.setSettings(doc.notification._settings)
        return model

module.exports.UserCouchConverter = new UserCouchConverter()
