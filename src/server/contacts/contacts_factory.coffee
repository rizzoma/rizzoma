_ = require('underscore')
async = require('async')

Conf = require('../conf').Conf
NotImplementedError = require('../../share/exceptions').NotImplementedError
{GoogleContactsFetcher, FacebookContactsFetcher} = require('./contacts_fetcher')
DateUtils = require('../utils/date_utils').DateUtils

UPDATE_THRESHOLD = Conf.get('contacts').updateThreshold

class ContactsFactory
    ###
    User contacts factory base class
    ###
    constructor: (@_sourceName, @_contactFetcher) ->
        @_conf = Conf.getContactsConfForSource(@_sourceName)
        @_logger = Conf.getLogger('contacts')

    getAccessToken: (req, res) ->
        @_contactFetcher.getAccessToken(req, res)

    onAuthCodeGot: (req, res, callback) ->
        @_contactFetcher.onAuthCodeGot(req, res, callback)

    autoUpdateContacts: (contacts, callback) ->
        sourceData = contacts.sources[@_sourceName]
        return callback(null, false) if not sourceData
        accessToken = sourceData.accessToken
        updateDate = sourceData.updateDate
        if not updateDate or not accessToken or DateUtils.getCurrentTimestamp() - updateDate < UPDATE_THRESHOLD
            return callback(null, false)
        locale = updateDate.locale
        @updateContacts(accessToken, contacts, locale, callback)

    updateContacts: (accessToken, contacts, locale, callback) =>
        ###
        Update existing or create new contacts list from source.
        @param accessToken: string
        @param contacts: ContactListModel
        @param locale: string
        @param callback: function(err, updated: bool)
        ###
        updateDate = contacts.sources?[@_sourceName]?.updateDate
        onSourceContactsGot = (err, sourceContacts) =>
            if err #проблемы с http-клиентом, сетью, гуглом или протух токен
                @_logger.warn("Error while contacts fetching: #{err}")
                contacts.removeAccessTocken(@_sourceName)
                return callback(null, true) #нужно сохранить удаленный токен и отдать те контакты, которые есть
            @_updateFromSourceContacts(accessToken, contacts, sourceContacts, (err, updated) =>
                return callback(err) if err
                contacts.updateSourceData(@_sourceName, accessToken, locale) #если все действительно обновилось поменяем дату обновления и токен
                callback(null, updated)
            )
        if updateDate
            @_contactFetcher.fetchContactsFromDate(accessToken, updateDate, locale, onSourceContactsGot)
        else
            @_contactFetcher.fetchAllContacts(accessToken, locale, onSourceContactsGot)

    _updateFromSourceContacts: (accessToken, contacts, sourceContacts, callback) ->
        ###
        Parse data for contacts source, update model.
        @param accessToken: string
        @param contacts: ContactListModel - model for updating
        @param sourceContacts: object - raw data from contacts provider.
        @param callback: function
        ###
        throw new NotImplementedError()

SOURCE_NAME_GOOGLE = require('../../share/contacts/constants').SOURCE_NAME_GOOGLE

class GoogleContactsFactory extends ContactsFactory
    ###
    Contacts fabric for Google.
    User pics (avatars) URLs can't be used directly in HTML because URLs should contain accessToken,
    we have to fetch avatars and serve requests to them ourselves.
    Directory structure: AVATAR_PATH->[contactsId -> [SHA1(contactEmail)...], ...]
    ###
    constructor: () ->
        @_internalAvatarsUrl = Conf.get('contacts').internalAvatarsUrl
        super(SOURCE_NAME_GOOGLE, GoogleContactsFetcher)

    _updateFromSourceContacts: (accessToken, contacts, sourceContacts, callback) ->
        @_contactFetcher.getUserContactsAvatarsPath(contacts.id, (err, avatarsPath) =>
            @_logger.error("Can not get avatars path for #{contacts.id}", { err }) if err
            if sourceContacts.error or not sourceContacts.feed
                @_logger.error("Can not get source contacts data feed (Google)", { sourceContacts })
                return callback(new Error('Can not get source contacts'))
            entry = sourceContacts.feed.entry
            return callback(null, accessToken != contacts.getSourceData(@_sourceName)?.accessToken) if not entry
            [toDelete, toFetchAvatar] = @_updateFromSourceContactFast(contacts, entry, avatarsPath)
            @_contactFetcher.removeContactsAvatar(avatarsPath, toDelete)
            onAvatarLoad = (email, fileName) =>
                [contact, index] = contacts.getContact(email)
                contact.setAvatar(@_getInternalAvatarUrl(contacts.id, fileName)) if contact
            @_contactFetcher.fetchAvatars(accessToken, toFetchAvatar, avatarsPath, onAvatarLoad, () ->
                callback(null, true)
            )
        )

    _updateFromSourceContactFast: (contacts, entry, avatarsPath) ->
        ###
        Update model properties which don't require I/O calls.
        @param contacts: ContactListModel
        @param entry: array
        @param avatarPath: string
        @returns: [array - кто был удален, array - аватары]
        ###
        toDelete = []
        toFetchAvatar = []
        for sourceContact in entry
            email = @_getPrimaryEmail(sourceContact)
            continue if not email
            if @_isDeleted(sourceContact)
                toDelete.push(email) if contacts.removeContact(email)
                continue
            contact = contacts.getOrCreateContact(email, @_sourceName)
            continue if not contact
            contact.setName(@_getName(sourceContact))
            continue if not avatarsPath
            avatarUrl = @_getAvatarUrl(sourceContact)
            toFetchAvatar.push({email, avatarUrl}) if avatarUrl
        return [toDelete, toFetchAvatar]

    _getPrimaryEmail: (sourceContact) ->
        ###
        Retrieve email.
        @param sourceContact: object
        @returns: string
        ###
        emails = sourceContact['gd$email']
        return null if not emails
        for email in emails
            primaryEmail = if email.primary then email.address else null
            return null if /^activity\+.+@rizzoma.com$/.test(primaryEmail) #убираем наше мыло (ответы из почты на блипы)
            return primaryEmail
        return null

    _isDeleted: (sourceContact) ->
        ###
        Check if contact is deleted from al groups.
        @param sourceContact: object
        @returns: bool
        ###
        groupMembershipInfo = sourceContact['gContact$groupMembershipInfo']
        return false if not groupMembershipInfo
        return _.all(groupMembershipInfo, (group) -> return group.deleted == 'true')

    _getName: (sourceContact) ->
        ###
        Retrieve contact name.
        @param sourceContact: object
        @returns: string
        ###
        fullName = sourceContact['gd$name']?['gd$fullName']?['$t']
        return fullName if fullName
        givenName = sourceContact['gd$givenName']?['$t']
        familyName = sourceContact['gd$familyName']?['$t']
        fullName = if givenName then "#{givenName} " else ''
        fullName += if familyName then familyName else ''
        return fullName if fullName.length
        return null

    _getAvatarUrl: (sourceContact) ->
        ###
        Retrieve avatar URL
        @param sourceContact: object
        @returns: string
        ###
        links = sourceContact['link']
        return null if not links
        for link in links
            return link.href if link.type == 'image/*'
        return null

    _getInternalAvatarUrl: (id, fileName) ->
        return "#{@_internalAvatarsUrl}#{id}/#{fileName}?r=#{Math.random()}"


class FacebookContactsFactory extends ContactsFactory
    ###
    Contacts fabric for Facebook.
    ###
    constructor: () ->
        super('facebook', FacebookContactsFetcher)

    _updateFromSourceContacts: (accessToken, contacts, sourceContacts, callback) ->
        sourceContacts = sourceContacts.data
        if not sourceContacts or not sourceContacts.length
            return callback(null, accessToken != contacts.getSourceData(@_sourceName)?.accessToken)
        for sourceContact in sourceContacts
            email = @_getEmail(sourceContact)
            continue if not email
            contact = contacts.getOrCreateContact(email, @_sourceName)
            continue if not contact
            contact.setExternalId(@_getExternalId(sourceContact))
            contact.setName(@_getName(sourceContact))
            contact.setAvatar(@_getAvatarUrl(sourceContact))
        callback(null, true)

    _getEmail: (sourceContact) ->
        username = sourceContact.username
        return if not username
        return "#{username}@facebook.com"

    _getExternalId: (sourceContact) ->
        return sourceContact.id

    _getName: (sourceContact) ->
        return sourceContact.name

    _getAvatarUrl: (sourceContact) ->
        username = sourceContact.username
        return if not username
        return "#{@_conf.apiUrl}/#{username}/picture"


UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
normalizeEmail = require('../user/utils').UserUtils.normalizeEmail

SOURCE_NAME_MANUALLY = require('../../share/contacts/constants').SOURCE_NAME_MANUALLY
LOCAL_UPDATE_THRESHOLD = 600

class LocalContactsFactory extends ContactsFactory
    ###
    Contacts fabric for "local" contacts: predefined support contacts and contacts added automatically
    when user invites someone to topic.
    ###

    constructor: () ->
        super('local', null)

    autoUpdateContacts: (contacts, callback) ->
        updateDate = contacts.sources?[@_sourceName]?.updateDate
        # minimum update frequency once per 10 minutes (client code fetches contacts twice: just after /topic/ page
        # loaded and 5 minutes later for additionally loaded/updated contacts or avatars)
        if updateDate and DateUtils.getCurrentTimestamp() - updateDate < LOCAL_UPDATE_THRESHOLD
            return callback(null, false)
        @updateContacts(contacts, callback)

    updateContacts: (contacts, callback) ->
        emails = (contact.email for contact in contacts.contacts when contact.source == SOURCE_NAME_MANUALLY)
        UserCouchProcessor.getByEmails(emails, (err, users) =>
            return callback(null, false) if err
            updated = false
            for email in emails
                contact = users[normalizeEmail(email)]?.toContact()
                [contactToUpdate, index] = contacts.getContact(email)
                if contactToUpdate and contact
                    updated |= contactToUpdate.setName(contact.name)
                    updated |= contactToUpdate.setAvatar(contact.avatar)
            contacts.updateSourceData(@_sourceName)
            callback(null, updated)
        )


contactsFactories =
    'google': new GoogleContactsFactory()
    'facebook': new FacebookContactsFactory()
    'local': new LocalContactsFactory()

module.exports.ContactsFactory = (sourceName) ->
    return contactsFactories[sourceName]
