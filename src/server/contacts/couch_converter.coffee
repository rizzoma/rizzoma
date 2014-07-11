ContactModel = require('./model').ContactModel
ContactListModel = require('./model').ContactListModel
CouchConverter = require('../common/db/couch_converter').CouchConverter
fixAvatarProtocol = require('../user/utils').UserUtils.fixAvatarProtocol

class ContactsCouchConverter extends CouchConverter
    ###
    Конвертор моделей пользователей для БД.
    ###
    constructor: () ->
        super(ContactListModel)
        fields =
            sources: 'sources'
        @_extendFields(fields)

    toModel: (doc) ->
        model = super(doc)
        model.contacts = (new ContactModel(contact.email, contact.source, contact.name, contact.avatar, contact.externalId) for contact in doc.contacts)
        return model

    toCouch: (model) ->
        doc = super(model)
        doc.contacts = []
        for contact in model.contacts
            contactDoc =
                externalId: contact.externalId
                email: contact.email
                source:contact.source
                name: contact.name
                avatar: fixAvatarProtocol(contact.avatar)
            doc.contacts.push(contactDoc)
        return doc

module.exports.ContactsCouchConverter = new ContactsCouchConverter()
