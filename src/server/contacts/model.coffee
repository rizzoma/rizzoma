Model = require('../common/model').Model
normalizeEmail = require('../user/utils').UserUtils.normalizeEmail
DateUtils = require('../utils/date_utils').DateUtils

SOURCE_NAME_MANUALLY = require('../../share/contacts/constants').SOURCE_NAME_MANUALLY

class ContactModel extends Model
    ###
    Модель одного контакта в списке.
    ###
    constructor: (@email, @source=SOURCE_NAME_MANUALLY, @name, @avatar, @externalId) ->
        super('contact')

    setExternalId: (value) ->
        return @_setProperty('externalId', value)

    setName: (value) ->
        return @_setProperty('name', value)

    setAvatar: (value) ->
        return @_setProperty('avatar', value)

    isEqualEmail: (email) ->
        return normalizeEmail(email) == normalizeEmail(@email)

    _setProperty: (name, value) ->
        return if not value
        return if @[name] == value
        @[name] = value
        return true


class ContactListModel extends Model
    ###
    Модель контактов пользователя.
    ###
    constructor: (@id=null, @contacts=[], @sources={}) ->
        super('userContacts')

    getSources: () ->
        ###
        Возвращает список всех источников контактов.
        @returns: object
        ###
        @_initSourceData('local') #немножко костыль. Добавляем внутренний источник (иначе он никогда не добавится, т.к. не пердполагается вызов обновления для него вручную)
        return @sources

    updateSourceData: (sourceName, accessToken, locale) ->
        ###
        Обновляет данные источника контактов (токен и время обновления контактов).
        @param sourceName: string
        @param accessToken: string
        ###
        @_initSourceData(sourceName)
        source = @sources[sourceName]
        source.accessToken = accessToken if accessToken
        source.locale = locale if locale
        source.updateDate = DateUtils.getCurrentTimestamp()

    getSourceData: (sourceName) ->
        return @sources[sourceName]

    _initSourceData: (sourceName) ->
        ###
        Инициализирует данные источника контактов.
        @param sourceName: string
        ###
        @sources[sourceName] ||= {}

    removeAccessTocken: (sourceName) ->
        ###
        Удаляет accessToken для источника (вызывается, когда токен больше не действителен).
        @param: sourceName: string
        ###
        source = @sources[sourceName]
        return if not source
        source.accessToken = null

    getContact: (email) ->
        ###
        Возвращает контакт по его email'у
        @param email: string
        @returns: object
        ###
        for contact, index in @contacts
            return [contact, index] if contact.isEqualEmail(email)
        return [null, null]

    getOrCreateContact: (email, sourceName=SOURCE_NAME_MANUALLY) ->
        ###
        Возвращает контакт, если его нет - создает.
        Возвращаются контакы только принадлежащие указанному источнику, за исключением добавленных вручную -
        в этом случае контакт "захватывается" источником, что бы переложить обновление с нас на источник (кейс: добавил
        вручную, позже добавил в друзья на фб - будем получать данные с фб).
        @param email; string
        @params sourceName: string
        @returns: object ot null
        ###
        [contact, index] = @getContact(email)
        if not contact
            contact = new ContactModel(email, sourceName)
            @_addContact(contact)
            return contact
        contact.source = sourceName if contact.source == SOURCE_NAME_MANUALLY
        return if contact.source == sourceName then contact else null

    addContacts: (contactsToAdd) ->
        ###
        Добавляет контакты.
        @param contactsToAdd: array
        @param sourceName: string
        ###
        isNewAdded = false
        for contactToAdd in contactsToAdd
            email = contactToAdd.email
            continue if not email
            [contact, index] = @getContact(email)
            continue if contact
            isNewAdded = true
            @_addContact(contactToAdd)
        return isNewAdded

    addContact: (contact) ->
        ###
        Добавляет одни контакт.
        @param contact: object
        @param sourceName: string
        ###
        @addContacts([contact])

    _addContact: (contact) ->
        @contacts.push(contact)

    removeContact: (email) ->
        ###
        Удаляет контакт.
        @param email: string
        @returns: bool
        ###
        [contact, index] = @getContact(email)
        return if not contact
        return !!@contacts.splice(index, 1)

module.exports =
    ContactListModel: ContactListModel
    ContactModel: ContactModel
