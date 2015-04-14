TYPES = sharejs.types
DOC_TYPE = TYPES['volna']

MicroEvent = require '../utils/microevent'
Document = sharejs.Doc
Request = require('../../share/communication').Request

class OtProcessor
    ###
    Подключение к серверу с OT
    Объекту этого класса необходимо хранить в себе все созданные документы, чтобы
    вызывать у них обработчик пришедших операций
    ###
    
    constructor: (@_transportSend, @_errorCallback) ->
        ###
        Инициализирует модуль
        @param _transportSend: function, функция для отправки сообщений на сервер
        @param _errorCallback: function, будет вызвана в случае возникновения ошибки
        ###
        @_docs = {}
        @_removeCallbacks = {}
        @_connections = {}
        @_groupIdByCallId = {}

    _getGroupIdByCallId: (callId) ->
        return null if not @_groupIdByCallId[callId]?
        return @_groupIdByCallId[callId]

    processOp: (msg, subscriptionCallId) =>
        ###
        Обрабатывает пришедшую операцию
        @param msg: ShareJS message
        @param subscriptionCallId: string
        ###
        serverDocId = msg['docId']
        groupId = @_getGroupIdByCallId(subscriptionCallId)
        if not groupId?
            console.warn "OT processor got operation for doc #{serverDocId}, call id #{subscriptionCallId} which is not present"
            return
        if not msg['op']
            return console.warn "Got operation of unexpected type", msg
        if @_docs[groupId]?.byServerId[serverDocId]?
            doc = @_docs[groupId].byServerId[serverDocId]
            msg['doc'] = doc.name
        else
            console.warn "OT processor got operation for doc #{serverDocId}, group id #{groupId} which is not present"
            return
        doc._onOpReceived(msg)

    _removeDoc: (groupId, docId) =>
        ###
        Удаляет документ из памяти документ указанной группы, если у него не осталось
        неотправленных операций.
        Вызывает соответствующий callback.
        @param groupId: string
        @param docId: string
        ###
        return if groupId not of @_removeCallbacks
        group = @_docs[groupId]
        doc = group.byId[docId]
        return if doc.hasUnsentOps()
        delete group.byId[docId]
        delete group.byServerId[doc.serverId] if doc.serverId?
        for own gId of @_docs[groupId].byId
            # do not remove group if docs are left
            return
        @_removeGroup(groupId)

    _removeGroup: (groupId) ->
        ###
        Удаляет группу документов
        @param groupId: string
        ###
        delete @_docs[groupId]
        callId = @_connections[groupId].subscriptionCallId
        @_connections[groupId].removeAllListeners()
        delete @_connections[groupId]
        delete @_groupIdByCallId[callId] if callId?
        @_removeCallbacks[groupId]?()
        delete @_removeCallbacks[groupId]

    closeGroup: (groupId, callback) ->
        ###
        Удаляет у себя информацию о группе документов
        @param groupId: string
        ###
        if not @_docs[groupId]?
            throw new Error "ShareJS group of docs #{groupId} not found"
        @_removeCallbacks[groupId] = callback
        @_removeDoc(groupId, docId) for docId of @_docs[groupId].byId

    makeDoc: (docId, docData, groupId) ->
        ###
        Создает ShareJS document из пришедших с сервера данных
        @param docId: string, идентификатор документа, сгенерированный на клиенте
        @param docData: {docId: DOC_ID, v: VERSION, snapshot: SNAPSHOT}
        @param groupId: string, уникальный идентификатор для группы документов
        @return: ShareJS document
        ###
        connection = @_getShareConnection(groupId)
        doc = new Document(connection, docId, docData['v'], DOC_TYPE, docData['snapshot'])
        doc.connection = connection
        doc.serverId = docData['docId']
        @_docs[groupId] ?= {byId: {}, byServerId: {}}
        @_docs[groupId].byId[docId] = doc
        if doc.serverId
            @_docs[groupId].byServerId[doc.serverId] = doc
        return doc

    setGroupSubscriptionCallId: (groupId, subscriptionCallId) ->
        ###
        Устанавливает для документа id подписки, чтобы он мог слать операции
        @param groupId: string, уникальный идентификатор для группы документов
        @param subscriptionCallId: string
        ###
        connection = @_connections[groupId]
        connection.subscriptionCallId = subscriptionCallId
        @_groupIdByCallId[subscriptionCallId] = groupId
        for own id, doc of @_docs[groupId].byId
            doc.subscribed = true
        connection.tryFlushAllOps()

    onSubscribe: (subscriptionCallId, serverId) ->
        groupId = @_groupIdByCallId[subscriptionCallId]
        return if not groupId
        doc = @_docs[groupId].byServerId[serverId]
        return if not doc
        doc.subscribed = true
        @_connections[groupId].tryFlushDocOps(doc.name)

    setDocServerId: (groupId, docId, serverId) ->
        group = @_docs[groupId]
        doc = group.byId[docId]
        doc.serverId = serverId
        group.byServerId[serverId] = doc
        @_connections[groupId].tryFlushDocOps(docId)

    _getServerDocId: (groupId, docId) =>
        @_docs[groupId]?.byId[docId]?.serverId

    _isSubscribed: (groupId, docId) =>
        @_docs[groupId]?.byId[docId]?.subscribed

    _getClientDocId: (groupId, docServerId) =>
        @_docs[groupId]?.byServerId[docServerId]?.name

    _getShareConnection: (groupId) ->
        ###
        Возвращает объект connection, необходимый ShareJS
        @param groupId: string
        @return: Object
        ###
        if groupId not of @_connections
            connection = new ShareJSConnection(groupId, @_getServerDocId, @_isSubscribed, @_getClientDocId, @_transportSend, @_removeDoc, @_errorCallback)
            connection.on('start-send', =>
                @emit('start-send', groupId)
            )
            connection.on('finish-send', =>
                @emit('finish-send', groupId)
            )
            @_connections[groupId] = connection
        return @_connections[groupId]

class ShareJSConnection
    constructor: (@_groupId, @_getServerDocId, @_isSubscribed, @_getClientDocId, @_transportSend, @_docOpProcessed, @_errorCallback) ->
        ###
        @param groupId: string, идентификатор группы документов, нужен для отправки операций на сервер
        @param getServerDocId: function
        @param getClientDocId: function
        @param transportSend: function
        @param docOpProcessed: function, нужна для удаления документов, помеченных на удаление, после отправки
            всех операций
        ###
        @_buffer = {}
        @_count = 0

    send: (op, callback) =>
        doSend = =>
            if not @_count
                @emit('start-send')
            @_count += 1
            serverDocId = @_getServerDocId(@_groupId, op.doc)
            @_send(@subscriptionCallId, serverDocId, op, (args...) =>
                @_count -= 1
                if not @_count
                    @emit('finish-send')
                callback(args...)
            )
        serverDocId = @_getServerDocId(@_groupId, op.doc)
        if serverDocId? and @subscriptionCallId? and @_isSubscribed(@_groupId, op.doc)
            doSend()
        else
            @_buffer[op.doc] ?= []
            @_buffer[op.doc].push(doSend)

    tryFlushDocOps: (docId) ->
        return if not @subscriptionCallId? or not @_getServerDocId(@_groupId, docId) or not @_isSubscribed(@_groupId, docId)
        @_flushBuffer(docId)

    tryFlushAllOps: ->
        return if not @subscriptionCallId?
        for docId of @_buffer
            @_flushBuffer(docId) if @_getServerDocId(@_groupId, docId) and @_isSubscribed(@_groupId, docId)

    _flushBuffer: (docId) ->
        return if not @_buffer[docId]?
        doSend() for doSend in @_buffer[docId]
        delete @_buffer[docId]

    _send: (subscriptionCallId, serverDocId, op, callback) ->
        ###
        Отправляет операцию на сервер
        @param subscriptionCallId: string
        @param serverDocId: string
        @param op: object, отправляемая операция
        @param callback: function, будет вызвана при получении ответа сервера
            callback(error, response)
        ###
        if op.open? and not op.open
            # it's operation to close shareJS Document, just do nothing
            console.warn "Open or close OT operation", op
            return callback null, op
        op.doc = op.docId = serverDocId
        @_transportSend serverDocId, subscriptionCallId, op, (err, res) =>
            @_processOpResponse(err, res, serverDocId, callback)

    _processOpResponse: (err, response, serverDocId, callback) =>
        ###
        Обрабатывает пришедший ответ на операцию
        @param err: object|null
        @param response: ShareJS operation|null
        @param serverDocId: string
        @param callback: function
        @TODO: добавить обработку ошибок, пришедших с сервера
        @TODO: добавить обработку ошибок, возникших на клиенте
        ###
        return @_errorCallback(err) if err
        try
            docId = @_getClientDocId(@_groupId, serverDocId)
            if not docId?
                throw new Error "Got response for unknown doc with group id #{@_groupId} and doc id #{serverDocId}"
            response.doc = docId
            callback?(null, response)
            @_docOpProcessed(@_groupId, docId)
        catch e
            console.error "Got severe error while processing operation response.", new Date(), e.stack, e
            console.error "Response is", response
            @_errorCallback(e)

MicroEvent.mixin(OtProcessor)
MicroEvent.mixin(ShareJSConnection)

module.exports.OtProcessor = OtProcessor
module.exports.instance = null
