{BlipModel} = require('./model')
FText = sharejs.types.ftext
MicroEvent = require('../utils/microevent')
{ModelType, ModelField, ParamsField} = require('../editor/model')

class BlipViewModelBase
    @Events:
        DESTROYED: 'destroyed'

    constructor: (args...) ->
        @_init args...

    _init: (@_waveViewModel, blipProcessor, blipData, container, parentBlip, isRead, waveId, timestamp, title) ->
        # TODO: save parent inside model
        @__parentBlip = parentBlip
        @_initModel(blipData, waveId, isRead, title)
        @__initView(@_waveViewModel, blipProcessor, @_model, timestamp, container, @__parentBlip?.getView(), isRead)
        blipData.on('remoteop', @_processRemoteChanges)
        @_blipData = blipData

    _initModel: (blipData, waveId, isRead, title) ->
        @__model = @_model = new BlipModel(blipData, waveId, isRead, title)

    __initView: (waveViewModel, blipProcessor, model, timestamp, container, parentBlip, isRead) ->
        throw new Error('not implemented')

    _processRemoteChanges: (ops, oldSnapshot, meta) =>
        contentOps = []
        for op in ops
            if FText.isFormattedTextOperation(op)
                if op.paramsi? or op.paramsd?
                    params = op.paramsi || op.paramsd
                    for paramName of params
                        if paramName is 'lastSent' or paramName is 'lastSenderId'
                            needLastSentUpdate = true
                contentOps.push op
                continue
            if op.p.length is 0 and op.oi?.pluginData?.message?.lastSent
                needLastSentUpdate = true
                continue
            if op.p.length is 1 and op.p[0] is 'pluginData' and op.oi?.message
                needLastSentUpdate = true
                continue
            if op.p.length is 2 and op.p[0] is 'pluginData' and op.p[1] is 'message'
                needLastSentUpdate = true
                continue
            root = op.p.shift()
            switch root
                when 'contributors' then @__view.applyParticipantOp op
                when 'isFoldedByDefault' then @__view.applyisFoldedByDefaultOp op
                else console.warn("Got unknown operation", op)
        if contentOps.length
            @__view.applyOps(contentOps, false, meta)
            @emit('remote-ops', contentOps)
        @__view.updateLastSent?() if needLastSentUpdate

    applyUndoRedoOps: (ops) ->
        @__view.applyOps(ops, true)
        @emit('undo-redo-ops', ops)

    getView: -> @__view

    getModel: -> @_model

    getWaveViewModel: -> @_waveViewModel

    getServerId: -> @__model.getServerId()

    setServerId: (serverId) ->
        @_model.serverId = serverId
        require('../ot/processor').instance.setDocServerId(@_waveViewModel.getId(), @_model.id, serverId)
        @emit('set-server-id', serverId)
        @removeListeners('set-server-id')

    insertGadget: (url) ->
        @__view.getEditor()?.insertGadget(url)

    setEditable: (editable) -> @__view.setEditable(editable)

    focus: -> @__view.focus()

    unfoldToRoot: ->
        # TODO: shold be implemented here or unfold in wave
        @__view.unfoldToRootBlip()

    getContainer: -> @__view.getContainer()

    getNearestServerId: ->
        ###
        Возвращает serverId блипа. Если такого нет, возвращает serverId ближайшего
        родителя.
        @return: string|null
        ###
        return null if not @__parentBlip
        serverId = @__model.getServerId()
        return serverId if serverId
        return @__parentBlip.getNearestServerId()

    destroy: ->
        @_blipData.removeListener('remoteop', @_processRemoteChanges)
        @emit(@constructor.Events.DESTROYED, @)
        @removeAllListeners()
        for childBlipId, childBlip of @__model.getChildBlips()
            childBlip.destroy()
        @__model.destroy()
        @__view.destroy()
        delete @__parentBlip
        delete @_waveViewModel
        @_isClosed = true

    isClosed: -> @_isClosed

    getParent: ->
        @__parentBlip

    getChildIndex: (child) ->
        childId = child.getModel().getServerId()
        for block, index in @_model.getSnapshotContent()
            id = block[ModelField.PARAMS][ParamsField.ID]
            return index if childId is id
        null

    getNextUnread: (startIndex) ->
        return @ unless @__view.isRead()
        content = @_model.getSnapshotContent()
        return null if startIndex > content.length
        for i in [startIndex...content.length]
            block = content[i]
            params = block[ModelField.PARAMS]
            blockType = params[ParamsField.TYPE]
            continue if blockType isnt ModelType.BLIP
            id = params[ParamsField.ID]
            child = @__view.getChildBlipByServerId(id)
            continue unless child
            return child unless child.getView().isRead()
            unread = child.getNextUnread(0)
            return unread if unread
        null

    getCursorIndex: ->
        editor = @__view.getEditor()
        return null unless editor
        contentIndex = editor.getCurrentIndex()
        return null unless contentIndex?
        length = 0
        for block, index in @_model.getSnapshotContent()
            length += block.t.length
            return index if length >= contentIndex
        null

    markAsReadRecursively: ->
        childBlips = @__view.getChildBlips()
        for id, child of childBlips
            child.markAsReadRecursively()
        @__view.setReadState(yes, no) unless @__view.isRead()

MicroEvent.mixin(BlipViewModelBase)
module.exports = BlipViewModelBase
