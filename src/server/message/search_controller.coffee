async = require('async')
SearchController = require('../search/controller').SearchController
CouchBlipProcessor = require('../blip/couch_processor').CouchBlipProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
IdUtils = require('../utils/id_utils').IdUtils

class MessageSearchController extends SearchController
    ###
    Процессор поисковой выдачи при поиске по сообщения.
    ###
    constructor: () ->
        super()
        @_idField = 'blip_id'
        @_changedField = 'changed'
        @_ptagField = 'ptags'

    executeQuery: (user, queryString, ptagNames, recipient, senderId, lastSearchDate, callback) ->
        return if @_returnIfAnonymous(user, callback)
        query = @_getQuery()
            .select(['blip_id', 'changed', 'content_timestamp', 'wave_url', 'ptags'])
            .addPtagsFilter(user, ptagNames)
            .addQueryString(queryString)
            .orderBy('content_timestamp')
            .defaultLimit()
        query.addAndFilter("message_sender_id = #{IdUtils.getOriginalId(senderId)}") if senderId
        if recipient
            recipientSearchIds = (IdUtils.getOriginalId(id) for id in recipient.getAllIds())
            query.addAndFilter("message_recipient_ids in (#{recipientSearchIds})")
        super(query, lastSearchDate, recipient, callback)

    _getItem: (result, changed) ->
        return {
            blipId: result[@_idField]
            waveId: result.wave_url
        }

    _getChangedItems: (ids, recipient, callback) ->
        return callback(null, {}) if not ids.length
        tasks = [
            async.apply(CouchBlipProcessor.getByIdsAsDict, ids)
            (blips, callback) ->
                senderIds = []
                for own id, blip of blips
                    senderIds.push(blip.message.getSenderId())
                callback(null, blips, senderIds)
            (blips, senderIds, callback) ->
                return callback(null, blips, {}) if not senderIds.length
                onUsersLoad = (err, senders) ->
                    callback(err, blips, senders)
                UserCouchProcessor.getByIdsAsDict(senderIds, onUsersLoad)
            (blips, senders, callback) =>
                @_compileItems(blips, senders, recipient, callback)
        ]
        async.waterfall(tasks, callback)

    _compileItems: (blips, senders, recipient, callback) ->
        ###
        Собирает выдачу для изменившихся результатов поиска.
        @param blips: object - блипы-сообщения
        @param senders: object - отправители
        @param recipient: object - получатели
        ###
        items = {}
        for own id, blip of blips
            sender = senders[blip.message.getSenderId()]
            if not sender?
                console.warn("Got search result for mention #{id} without sender #{blip.message.getSenderId()}")
                continue
            items[id] =
                blipId: id
                title: blip.getTitle()
                snippet: blip.getSnippet()
                lastSent: Math.max(blip.message.getLastSentTimestamp() or 0, blip.contentTimestamp)
                senderName: sender.name
                senderEmail: sender.email
                senderAvatar: sender.avatar
                isRead: blip.getReadState(recipient)
        callback(null, items)

module.exports.MessageSearchController = new MessageSearchController()
