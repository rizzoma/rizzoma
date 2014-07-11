MessageController = require('./controller').MessageController

class MessageAutosender
    ###
    Вспомогательный класс для автоотправки меншенов.
    @see: blip/plugin_autosender
    ###
    constructor: () ->

    getName: () ->
        return 'message'

    getSendersAndRecipientsIdsForOneItem: (blip) ->
        ids = []
        senderId = blip.message.getSenderId()
        recipientIds = blip.message.getRecipientIds()
        senderIndex = recipientIds.indexOf(senderId)
        recipientIds.splice(senderIndex, 1) if senderIndex >= 0
        return [ids, recipientIds] if not recipientIds.length
        ids = recipientIds.concat([senderId])
        return [ids, recipientIds]

    getNotifications: (blip, rootBlip, users, randoms) ->
        return blip.message.getNotifications(rootBlip, users, randoms)

    updateSentTimestamp: (blip, callback) ->
        MessageController.updateSentTimestamp(blip, null, callback)

module.exports = new MessageAutosender()
