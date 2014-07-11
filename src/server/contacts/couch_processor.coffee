CouchProcessor = require('../common/db/couch_processor').CouchProcessor
ContactsCouchConverter = require('./couch_converter').ContactsCouchConverter
ContactListModel = require('./model').ContactListModel

class ContactsCouchProcessor extends CouchProcessor
    ###
    Класс, представляющий couch processor для модели контактов пользователя.
    ###
    constructor: () ->
        super()
        @converter = ContactsCouchConverter

    getById: (id, callback) =>
        super(id, (err, contacts) ->
            return callback(null, new ContactListModel(id)) if err and err.message == 'not_found'
            callback(err, contacts)
        )

    getByIdsAsDict: (ids, callback) ->
        super(ids, (err, contacts) ->
            return callback(err) if err
            contacts[id] = new ContactListModel(id) for id in ids when not contacts[id]
            callback(null, contacts)
        )

module.exports.ContactsCouchProcessor = new ContactsCouchProcessor()
