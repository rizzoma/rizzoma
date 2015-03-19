_ = require('underscore')
OperationCouchProcessor = require('./operation_couch_processor').OperationCouchProcessor

class OpListener
    ###
    Класс представляющий подписчика канала.
    ###
    constructor: (@_send, versions, @_clientDocId=null) ->
        ###
        @param _send: function - функция, выполняющая отправку сообщения.
        @versions: object - начальный набор документов канала
            docId: version
        набор документов можно изменить вызовами addDoc и removeDoc
        ###
        @_docs = []
        @_sendLocks = {}
        @addDoc(docId) for own docId, version of versions

    _sendWrapper: (err, op, clientId) ->
        return op.callback(null, {docId: op.docId, v: op.version}) if op.callback
        @_send(err, op, clientId)

    fill: (versions, actualVersions) ->
        ###
        Действует так же, как addDoc, только для группы документов.
        Должен быть вызван сразу после инстанцирования класса, до вызова addDoc и т.п.
        Вынесен в метод, т.к. для получения actualVersions может понадобиться время в течении которого операции в
        канал не должны игнорироваться и будут захвачены в @_sendLocks
        @params versions: object
        @param actualVersions: object
        ###
        for own docId, version of versions
            actualVersion = actualVersions[docId]
            if _.isUndefined(actualVersion)
                @removeDoc(docId)
                delete @_sendLocks[docId]
                continue
            @_getArrestOpsAndUnlock(docId, versions[docId], actualVersion)

    addDoc: (docId) ->
        ###
        Загружает недостающие операции (диапазон (version, doc.version])
        и отправлет их. При этом документ будет заблокирован
        (все операции примененные к документу во время загрузки недостающих
        операций будут буферизованы и отправлены только после окончания
        загрузки и разблокировки документа).
        @param docId: string
        @param version: int
        ###
        return if @_docs.indexOf(docId) >= 0
        @_createSendLock(docId)
        @_docs.push(docId)

    _getArrestOpsAndUnlock: (docId, version, actualVersion) ->
        OperationCouchProcessor.getOpRange(docId, version, actualVersion, (err, ops) =>
            return if err
            # применим клиентский id чтобы внезапно на клиента не отдать сервверный
            # используется для топиков
            lockedOps = @_sendLocks[docId] or []
            @_sendLocks[docId] = ops.concat(lockedOps)
            @_getReady(docId)
        )

    removeDoc: (docId) ->
        ###
        Удаляет документ из канала.
        @param docId: string
        ###
        index = @_docs.indexOf(docId)
        return if index < 0
        @_docs.splice(index, 1)
        delete @_sendLocks[docId]

    send: (op) ->
        ###
        Отсылает операцию, либо буферизует ее, если документ заблокирован.
        ###
        docId = op.docId
        return if @_docs.indexOf(docId) < 0
        # применим клиентский id чтобы внезапно на клиента не отдать сервверный
        # используется для топиков
        lockedOps = @_sendLocks[docId]
        return lockedOps.push(op) if lockedOps
        @_sendWrapper(null, op, @_clientDocId)

    hasSendLock: (docId) ->
        return !!@_sendLocks[docId]

    _getReady: (docId) ->
        ###
        Снимает блокировку с документа и оправляет все буферизованные операции.
        @param docId: string
        ###
        lockedOps = @_sendLocks[docId] or []
        #Сортируем опрации и удаляем одинаковые. Теоритически все итак должно быть хорошо, но так спокойней.
        #Операции с полем callback - это ответы (отдаются не по каналу подписки, а в ответ на postOp)
        #Если клиент отстал и были загружены операции конфликтующие с ответами мы должны игнорировать такие операции в пользу ответов
        #Такое, например, может произойти, если операци клиента применилась, после чего он отконнектился (ответ не получил): после
        #реконнекта клиент повторит свою операцию. Мы должны здесь ее игнорировать и отдавать только ответ.
        opsByVersion = {}
        for op in _.sortBy(lockedOps, 'version')
            version = op.version
            continue if opsByVersion[version] and not op.callback
            opsByVersion[version] = op
        @_sendWrapper(null, op, @_clientDocId) for op in _.values(opsByVersion)
        delete @_sendLocks[docId]

    _createSendLock: (docId) ->
        ###
        Блокирует документ.
        @docId: string
        ###
        return if @_sendLocks[docId]
        @_sendLocks[docId] = []


class OtProcessorFrontend
    constructor: () ->
        ###
        Хранит подписки.
        Структура:
        channelId: - id канала
            listenerId: - id подписчика
                OpListener - экземпляр OpListener
        ###
        @_subscriptions = {}

    subscribeChannel: (channelId, versions, listenerId, listener, clientDocId) ->
        ###
        Подписывает слушателя на канал.
        @param channelId: string - id документа
        @param versions: object - словарь вида
            id документа: версия в которой на него подписались.
        @param listenerId: string - уникальный id слушателя
        @param listener: function - вызывается при изменениях в документах канала.
        ###
        @_subscriptions[channelId] ||= {}
        if @_subscriptions[channelId][listenerId]
            console.error("Subscription already exists channelId: #{channelId}, listenerId: #{listenerId}")
            return
        @_subscriptions[channelId][listenerId] = new OpListener(listener, versions, clientDocId)
        return true

    fillChannel: (channelId, listenerId, versions, actualVersions) ->
        listener = @_subscriptions[channelId]?[listenerId]
        return if not listener
        listener.fill(versions, actualVersions)

    unsubscribeFromChannel: (channelId, listenerId) ->
        ###
        Отписывает пользователя от канала.
        @param channelId: string
        @param listenerId: string
        ###
        listeners = @_subscriptions[channelId]
        return if not listeners
        delete listeners[listenerId]
        delete @_subscriptions[channelId] if _.isEmpty(listeners)

    unsubscribeFromAllChannels: (listenerIdPart) ->
        ###
        Отписывает слушателя от всех каналов.
        Нужна на случай дисконнектов и других факапов со слушателем.
        @param listenereIdPart: string
        ###
        for own channelId of @_subscriptions
            @_unsubscribeFromChannelByListenerIdPart(channelId, listenerIdPart)

    _unsubscribeFromChannelByListenerIdPart: (channelId, listenerIdPart) ->
        ###
        Отписывает пользователя от канала по неточному listenerId.
        Небольшой костыль (listenerId - конкатенация 2х ключей,
        в случае дисконнекта у нас есть только один).
        @param channelId: string
        @param listenereIdPart: string
        ###
        listeners = @_subscriptions[channelId]
        return if not listeners
        toDelete = []
        for own listenerId, listener of listeners
            if listenerId.indexOf(listenerIdPart) == 0
                toDelete.push(listenerId)
        for listenerId in toDelete
            @unsubscribeFromChannel(channelId, listenerId)

    subscribeDoc: (channelId, docId, listenerId) ->
        ###
        Подписывает слушателя на кокумент, добавляя его в канал.
        Теперь при изменениях в документе docId будет вызван listener
        соответствующий channelId и listenerId.
        @param channelId: string
        @param: docId: string
        @param: listenerId: string
        ###
        listener = @_subscriptions[channelId]?[listenerId]
        return if not listener
        listener.addDoc(docId)

    fillDoc: (channelId, listenerId, docId, version, actualVersion) ->
        listener = @_subscriptions[channelId]?[listenerId]
        return if not listener
        versions = {}
        actualVersions = {}
        versions[docId] = version
        actualVersions[docId] = actualVersion
        listener.fill(versions, actualVersions)

    unsubscribeDoc: (channelId, docId, listenerId) ->
        ###
        Отписывает слушателя от документа канала.
        @param channelId: string
        @param docId: string
        @param lisetenerId: string
        ###
        listener = @_subscriptions[channelId]?[listenerId]
        return if not listener
        listener.removeDoc(docId)

    sendOpsToSelf: (channelId, listenerId, ops) ->
        ###
        Шлёт операции в канал (подписку) только одного пользователя.
        Используется для отправки операций отставшему клиенту (когда клиент прислал операцию для старой версии
        документа ему отправляются сначала недостающие операции, потом ответ на его ot-операцию).
        @see WaveModule.postOpToBlip module method
        ###
        listener = @_subscriptions[channelId]?[listenerId]
        return if not listener
        ops = [ops] if not _.isArray(ops)
        listener.send(op) for op in ops

    onOpReceive: (channelId, op) ->
        listeners = @_subscriptions[channelId]
        return if not listeners
        for own listenerId, listener of listeners when op.callback or listenerId != op.listenerId
            if op.callback
                listener.send(op) if listenerId == op.listenerId
            else
                listener.send(op) if listenerId != op.listenerId

    getOpRange: (docId, start, end, callback) ->
        OperationCouchProcessor.getOpRange(docId, start, end, callback)

    getOpRangeForMultipleDocs: (ranges, callback) ->
        OperationCouchProcessor.getOpRangeForMultipleDocs(ranges, callback)

module.exports.OtProcessorFrontend = new OtProcessorFrontend()
