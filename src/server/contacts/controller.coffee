_ = require('underscore')
async = require('async')

Conf = require('../conf').Conf
ContactsCouchProcessor = require('../contacts/couch_processor').ContactsCouchProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
ContactsFactory = require('./contacts_factory').ContactsFactory
DateUtils = require('../utils/date_utils').DateUtils

CONTACTS_RETURNING_TIMEOUT = 7000
SUPPORT_EMAIL = require('../conf').Conf.get('supportEmail')

class ContactsController
    ###
    User contacts controller.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('contacts')

    getContacts: (user, callback) ->
        ###
        Return user contacts data.
        Called by client code via API.
        @param user: UserModel
        @param callback: function
        ###
        contactsId = user.getContactsId()
        @_getContacts(contactsId, (err, contacts) =>
            callback(err, if err then null else contacts.contacts)
            @_autoUpdateContacts(contacts)
        )

    _autoUpdateContacts: (contacts) ->
        sources = contacts.getSources()
        tasks = []
        for sourceName, sourceData of sources
            contactsFactory = ContactsFactory(sourceName)
            return if not contactsFactory
            tasks.push(do(contactsFactory, contacts) ->
                return (callback) =>
                    contactsFactory.autoUpdateContacts(contacts, callback)
            )
        async.parallel(tasks, (err, updated) =>
            @_saveContacts(contacts, _.any(updated), () ->)
        )

    getAccessToken: (sourceName, req, res) ->
        contactsFactory = ContactsFactory(sourceName)
        contactsFactory.getAccessToken(req, res)

    onAuthCodeGot: (sourceName, req, res, callback) ->
        contactsFactory = ContactsFactory(sourceName)
        contactsFactory.onAuthCodeGot(req, res, callback)

    addContacts: (user, usersToAdd, callback) ->
        ###
        Add usersToAdd to user contacts model.
        @param user: UserModel
        @param usersToAdd: array [UserModel, ...]
        @param callback: function
        ###
        tasks = [
            async.apply(ContactsCouchProcessor.getById, user.getContactsId())
            (contacts, callback) ->
                updated = contacts.addContacts((userToAdd.toContact() for userToAdd in usersToAdd))
                return callback(null) if not updated
                ContactsCouchProcessor.save(contacts, callback)
        ]
        async.waterfall(tasks, callback)

    mergeContacts: (user, usersToMerge, callback) ->
        id = user.getContactsId()
        return callback() if not id
        ids = (userToMerge.getContactsId() for userToMerge in usersToMerge when userToMerge.id)
        ids.push(id)
        tasks = [
            async.apply(ContactsCouchProcessor.getByIdsAsDict, ids)
            (allContacts, callback) ->
                userContacts = allContacts[id]
                return callback(null, null, false) if not userContacts
                delete allContacts[id]
                updated = false
                for contacts in _.values(allContacts)
                    updated = userContacts.addContacts(contacts.contacts) or updated
                callback(null, userContacts, updated)
            (userContacts, updated, callback) ->
                return callback() if not updated
                ContactsCouchProcessor.save(userContacts, callback)
        ]
        async.waterfall(tasks, callback)

    addEachOther: (user, usersToAdd, callback) ->
        ###
        Add user info to contacts of usersToAdd and usersToAdd info to the user contacts.
        Used when user invites usersToAdd to some topic so both parties have exchanged their contacts.
        @param user: UserModel
        @param usersToAdd: array [UserModel, ...]
        @param callback: function
        ###
        userContactsId = user.getContactsId()
        uniqueUsersToAdd = []
        ids = [userContactsId]
        for userToAdd in usersToAdd
            continue if user.isEqual(userToAdd)
            uniqueUsersToAdd.push(userToAdd)
            ids.push(userToAdd.getContactsId())
        tasks = [
            async.apply(ContactsCouchProcessor.getByIdsAsDict, ids)
            (allContacts, callback) ->
                userContacts = allContacts[userContactsId]
                delete allContacts[userContactsId]
                toSave = (contacts for own id, contacts of allContacts when contacts.addContact(user.toContact()))
                return callback(null, toSave) if not userContacts
                if userContacts.addContacts((userToAdd.toContact() for userToAdd in uniqueUsersToAdd))
                    toSave.push(userContacts)
                callback(null, toSave)
            (toSave, callback) ->
                return callback() if not toSave.length
                ContactsCouchProcessor.bulkSave(toSave, callback)
        ]
        async.waterfall(tasks, callback)

    addEachOtherUsingId: (userId, usersToAdd, callback) ->
        UserCouchProcessor.getById(userId, (err, user) =>
            return callback(err) if err
            @addEachOther(user, usersToAdd, callback)
        )

    updateContacts: (sourceName, accessToken, user, locale, callback) ->
        ###
        Update contacts from the source.
        @param sourceName: string ('google', 'facebook')
        @params accessToken: string
        @param user: UserModel
        @param locale: string
        @param callback: function
        ###
        contactsId = user.getContactsId()
        tasks = [
            async.apply(@_getContacts, contactsId)
            (contacts, callback) =>
                @_updateContactsByAccessToken(sourceName, accessToken, contacts, locale, (err) ->
                    callback(err, contacts)
                )
        ]
        async.waterfall(tasks, (err, contacts) ->
            callback(err, if err then null else contacts.contacts)
        )

    _updateContactsByAccessToken: (sourceName, accessToken, contacts, locale, callback) ->
        ###
        Update contacts using factory.
        Returns response not later than CONTACTS_RETURNING_TIMEOUT (for example, Google contacts factory retrieves
        avatars sequentially, it's better to return response soon with only some avatars and fetch remaining in background).
        All fabrics should work with contacts model by link.
        @param sourceName; string
        @param accessToken: string
        @param contacts: ContactListModel
        @param waitForUpdate: bool - ждать ли обновление контактов в течении CONTACTS_RETURNING_TIMEOUT или отдать сразу, что есть и бновляться в фоне
        @param locale: string
        @param callback: function(err)
        ###
        contactsFactory = ContactsFactory(sourceName)
        return callback(null) if not contactsFactory
        contactsReturned = false
        contactsReturningTimer = null
        tasks = [
            (nextTask) ->
                contactsFactory.updateContacts(accessToken, contacts, locale, nextTask)
                onTimeout = () ->
                    contactsReturned = true
                    callback(null)
                contactsReturningTimer = setTimeout(onTimeout, CONTACTS_RETURNING_TIMEOUT)
            (updated, callback) =>
                @_saveContacts(contacts, updated, callback)
        ]
        async.waterfall(tasks, (err) ->
            return if contactsReturned
            clearTimeout(contactsReturningTimer)
            callback(err)
        )

    _getContacts: (id, callback) =>
        ContactsCouchProcessor.getById(id, (err, contacts) ->
            return callback(err) if err
            contacts.getOrCreateContact(SUPPORT_EMAIL) #добавляем в контакты саппорта
            callback(null, contacts)
        )

    _saveContacts: (contacts, updated, callback) ->
        return callback(null) if not updated
        ContactsCouchProcessor.save(contacts, (err) =>
            @_logger.error("Error while saving contacts: #{err}") if err
            callback(null)
        )


module.exports.ContactsController = new ContactsController()
