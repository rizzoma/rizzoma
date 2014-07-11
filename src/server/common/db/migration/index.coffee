Ptag = require('../../../ptag').Ptag
fixAvatarProtocol = require('../../../user/utils').UserUtils.fixAvatarProtocol
DateUtils = require('../../../utils/date_utils').DateUtils

ALL_PTAG_ID = Ptag.ALL_PTAG_ID
FOLLOW_PTAG_ID = Ptag.FOLLOW_PTAG_ID

NON_BLOCKED = require('../../../wave/constants').NON_BLOCKED
TOPIC_TYPE_TEAM = require('../../../wave/constants').TOPIC_TYPE_TEAM


_ = require('underscore')

class Migration
    ###
    Класс, представляющий утилиту миграции версий.
    Последовательно применяет к элементу функции миграции, 
    определенные в массиве @_migrationFunctions.
    ###
    constructor: () ->
        ###
        В этот массив добавляем функции миграции.
            @param doc: object
            @returns: object
        ###
        @_migrationFunctions = [
            (doc) ->
                return doc if doc.type != 'User'
                doc.type = 'user' 
                return doc
            (doc) ->
                return doc if doc.type != 'Auth'
                doc.type = 'auth' 
                doc.authType ||= doc.auth_type
                doc.authId ||= doc.auth_id
                doc.userId ||= doc.user_id
                return doc
            (doc) ->
                return doc if doc.type != 'operation'
                doc.docId ||= doc.docName
                return doc
            (doc) ->
                return doc if doc.type != 'wave'
                participants = doc.participants
                return doc if not participants.length
                for participant in participants
                    continue if participant.ptags
                    participant.ptags = [ALL_PTAG_ID, FOLLOW_PTAG_ID]
                return doc
            (doc) ->
                ###
                user: notificationState -> notification
                ###
                return doc if doc.type != 'user'
                return doc if doc.notification and not doc.notificationState
                doc.notification = {id: null, state: doc.notificationState}
                delete doc.notificationState
                return doc
            (doc) ->
                return doc if doc.type != 'wave'
                switch doc.sharedState
                    when 'public' then doc.sharedState = 1
                    when 'link_public' then doc.sharedState = 2
                    when 'private' then doc.sharedState = 3
                return doc
            (doc)  ->
                ###
                Для перехода на https. Меняю ссылкку юзерпиков.
                @see: user/source_auth_user
                ###
                return doc if doc.type != 'user'
                avatar = doc.avatar
                return doc if not avatar
                doc.avatar = fixAvatarProtocol(avatar)
                return doc
            (doc) ->
                ###
                Для перехода на https. Меняю ссылкку юзерпиков в контактах.
                @see: user/contacts/couch_converter
                ###
                return doc if doc.type != 'userContacts'
                contacts = doc.contacts
                return doc if not contacts
                for contact in contacts
                    contact.avatar = fixAvatarProtocol(contact.avatar)
                return doc
            (doc) ->
                return doc if doc.type != 'wave'
                participants = doc.participants
                return doc if not participants.length
                isCreatorNotAppointed = true
                for participant in participants
                    if participant.role == 'moderator'
                        participant.role = if isCreatorNotAppointed then 1 else 2
                        isCreatorNotAppointed = false
                    participant.role = 4 if participant.role == 'reader'
                    participant.role = 65536 if not participant.role
                    participant.blockingState = NON_BLOCKED
                return doc
            (doc) ->
                return doc if doc.type != 'wave'
                sharedState = doc.sharedState
                return doc if not sharedState
                doc.defaultRole = 2 if sharedState == 3
                doc.defaultRole = 3 if sharedState == 2
                doc.defaultRole = 3 if sharedState == 1
                return doc
            (doc) ->
                return doc if doc.type != 'wave'
                sharedState = doc.sharedState
                return doc if not sharedState
                doc.defaultRole = 2 if sharedState == 2
                return doc
            (doc) ->
                return doc if doc.type != 'blip'
                return doc if not doc.content
                doc.pluginData = {} if not doc.pluginData
                for block in doc.content
                    continue if not block.params
                    if block.params.__TYPE == 'RECIPIENT'
                        doc.pluginData['message'] = {lastSent: DateUtils.getCurrentTimestamp()}
                        break
                return doc
            (doc) ->
                return doc if doc.type != 'userContacts'
                return doc if doc.sources
                doc.sources = {'google': {accessToken: doc.accessToken, updateDate: doc.updateTime}}
                delete doc.accessToken
                delete doc.updateTime
                contacts = doc.contacts
                return doc if not contacts
                for contact in contacts
                    contact.source = 'google' if not contact.source
                return doc
            (doc) ->
                return doc if doc.type != 'user'
                doc.alternativeIds = [] if not doc.alternativeIds
                if not doc.normalizedEmails
                    doc.normalizedEmails = [doc.normalizedEmail]
                    delete doc.normalizedEmail
                if not doc.emails
                    doc.emails = {}
                    doc.emails[doc.email] = true
                return doc
            (doc) ->
                return doc if doc.type not in ['auth', 'user']
                if doc.avatar?
                    if doc.avatar.indexOf('googleusercontent') != -1 and doc.avatar.indexOf('s65-c-k/') == -1
                        doc.avatar = doc.avatar.replace(/(.*googleusercontent.*)(photo\.jpg)/, '$1s65-c-k/$2')
                    else if fbParams = doc.avatar.match(/^https:\/\/graph.facebook.com\/([^\/]+)\/picture/)
                        doc.avatar = "https://graph.facebook.com/#{fbParams[1]}/picture?width=65&height=65"
                return doc
            (doc) ->
                return doc if not doc.type or doc.type.toLowerCase() != 'auth'
                return doc if not doc.aleternativeEmails
                doc.alternativeEmails = doc.aleternativeEmails
                delete doc.aleternativeEmails
                return doc
            (doc)  ->
                return doc if doc.type != 'user'
                return doc if _.isObject(doc.installedStoreItems)
                doc.installedStoreItems = {}
                return doc
            (doc)  ->
                return doc if doc.type != 'user'
                doc.installedStoreItems = {} if _.isArray(doc.installedStoreItems)
                return doc
            (doc) ->
                return doc if doc.type != 'wave'
                return doc if doc.topicType != TOPIC_TYPE_TEAM
                balance = doc.balance
                return doc if not balance
                now  = DateUtils.getCurrentDate()
                if balance.lastWriteOffDate >= now and balance.value == 0
                    balance.isTrial = yes
                return doc
            (doc) ->
                ###
                Fix for excessive contributors content (bug while copying blips)
                ###
                return doc if doc.type != 'blip'
                contributors = doc.contributors
                return if not contributors
                doc.contributors = ({id: contributor.id} for contributor in contributors when contributor.id)
                return doc
        ]

    _setFormat: (doc) ->
        ###
        Инкрементирует формат документа.
        @param doc: object - документ из БД
        ###
        doc.format = @getActualFormat()

    getActualFormat: () ->
        ###
        Возвращает номер версии актуального формата.
        @returns: int - 
        ###
        return @_migrationFunctions.length

    migrateFormat: (doc) ->
        ###
        Накатывает недостающие патчи на документ
        в завичимости от версии формата докмента.
        @param doc: object - документ из БД
        @returns: object
        ###
        currentFormat = doc.format or 0
        for patch in @_migrationFunctions[currentFormat..]
            doc = patch(doc)
        @_setFormat(doc)
        return doc

module.exports.Migration = new Migration()
