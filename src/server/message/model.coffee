PluginModel = require('../blip/plugin_model').PluginModel
DateUtils = require('../utils/date_utils').DateUtils
IdUtils = require('../utils/id_utils').IdUtils
NotificationUtils = require('../notification/utils').Utils
RECIPIENT_NODE = 'RECIPIENT' 
RECIPIENT_ID_ATTR = '__ID'
Conf = require('../conf').Conf
{PLUGIN_CHANGING_STATES_NOT_MY, PLUGIN_CHANGING_STATES_CHANGE, PLUGIN_CHANGING_STATES_NO_CHANGE} = require('../blip/constants')

class MessageModel extends PluginModel
    ###
    Класс, представляющий базовую модель блипа.
    ###
    constructor: (blip) ->
        ###
        @param _blip: BlipModel
        ###
        super(blip)

    getName: () ->
        ###
        Возвращает имя плагина.
        ###
        return 'message'

    getSenderId: () ->
        ###
        Возвращает id отправителя сообщения.
        @returns: string
        ###
        return @_blip.getAuthorId()
        
    getRecipientIds: () ->
        ###
        Возвращает id адресатов.
        @returns: array
        ###
        return (message.recipientId for message in @getList())

    generateNotificationRandoms: () ->
        ###
        генерит рэндомы для тех кого оповещаем
        Используется в email_reply_fetcher
        ###
        randoms = {}
        for message in @getList()
            randoms[message.recipientId] = NotificationUtils.generateNotificationRandom()
        return randoms

    getNotifications: (rootBlip, users, randoms) ->
        ###
        Возвращает контекст для заполнения шаблона сообщения.
        @param sender: UserModel
        @param rootBlip: BlipModel
        @returns: object
        ###
        notifications = []
        sender = users[@getSenderId()]
        return notifications if not sender
        title = rootBlip.getTitle()
        text = @_blip.getText(null, null, "\n")
        waveId = @_blip.getWave().getUrl()
        replyEmail = Conf.get('replyEmail').split('@')
        for message in @getList()
            id = message.recipientId
            recipient = users[id]
            continue if not recipient
            timezone = recipient.timezone or 0
            replyTo = "#{replyEmail[0]}+#{waveId}/#{@_blip.id}/#{randoms[id]}@#{replyEmail[1]}"
            context =
                title: title
                sender: sender
                text: text
                waveId: waveId
                blipId: @_blip.id
                blipTime: new Date(@_blip.contentTimestamp * 1000 + timezone * 3600000)
                timezone: if timezone >= 0 then "GMT+#{timezone}" else "GMT#{timezone}"
                replyTo: replyTo
                from: sender
            notifications.push({user: recipient, context: context})
        return notifications

    generatePluginDataOp: (user) ->
        ###
        Возвращает операцию для установки/обновления данных плагина.
        @param user: UserModel
        @returns: array
        ###
        op =
            p: @_getPluginPath()
            oi:
                lastSent: DateUtils.getCurrentTimestamp()
                lastSenderId: user.id if user
        pluginData = @_getPluginData()
        op.od = pluginData if pluginData
        return op

    genereateRecipientAddOp: (position, recipientId) ->
        ###
        Возвращает операцию вставки получателя в блип.
        @param position: int - позиция для встаки
        @param recipientId: string
        @returns: object
        ###
        params = {__TYPE: 'RECIPIENT', __ID: recipientId, RANDOM: Math.random()}
        return {p: position, ti: ' ', params}

    getLastSentTimestamp: () ->
        return @_getPluginData()?.lastSent

    @getSearchIndexHeader: () ->
        ###
        Возвращает индексируемые поля для заголовка индекса.
        @returns: array
        ###
        return [
            {elementName: 'attr', name: 'message_sender_id', type: 'int'}
            {elementName: 'attr', name: 'message_recipient_ids', type: 'multi'}
        ]

    getSearchIndex: () ->
        ###
        Возвращает индексируемые поля для индекса.
        @returns: array
        ###
        senderField = {name: 'message_sender_id', value: ''}
        recipientField = {name: 'message_recipient_ids', value: ''}
        recipientIds = (IdUtils.getOriginalId(message.recipientId) for message in @getList())
        if recipientIds.length
            senderField.value = IdUtils.getOriginalId(@getSenderId())
            recipientField.value = recipientIds.join(' ')
        return [senderField, recipientField]

    checkOpPermission: (op, user) ->
        if op.params and op.params.__TYPE == RECIPIENT_NODE and not op.params[RECIPIENT_ID_ATTR]
            console.debug("Bugcheck. Mention op without RECIPIENT_ID_ATTR", op, user.id)
            return false
        return op.params and op.params.__TYPE == RECIPIENT_NODE and user.isEqual(op.params[RECIPIENT_ID_ATTR]) and op.td

    getList: () ->
        messges = []
        pluginData = @_getPluginData()
        lastSent = pluginData?.lastSent
        lastSenderId = pluginData?.lastSenderId
        @_blip.iterateBlocks((type, block, position) ->
            params = block.params
            return if type != RECIPIENT_NODE or not params
            recipientId = params[RECIPIENT_ID_ATTR]
            return if not recipientId
            messges.push({recipientId, lastSent, lastSenderId, position})
        )
        return messges

    getChangingState: (ops) ->
        ###
        @param ops: arrya
        @returns: int
        @see: PluginModel
        ###
        state = 0
        for op in ops
            state <<= 2
            if op.p[0] == 'pluginData' and op.p[1] == @getName() #отправка меншена
                state |= PLUGIN_CHANGING_STATES_NO_CHANGE
                continue
            if not @_getByPosition(op.p) #мимо
                state |= PLUGIN_CHANGING_STATES_NOT_MY
                continue
            if op.td #удаление
                state |= PLUGIN_CHANGING_STATES_NO_CHANGE
                continue
            state |= PLUGIN_CHANGING_STATES_CHANGE
        return state

module.exports.MessageModel = MessageModel
