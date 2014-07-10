{ModelField, ModelType, ParamsField}  = require('../editor/model')
FText = sharejs.types.ftext
clone = (o) -> JSON.parse(JSON.stringify(o))

# Количество миллисекунд, после которого закрывается старая группа undo-операций
# и открывается новая
UNDO_GROUP_TIMEOUT = 3000
UNDO_OPERATION_LIMIT = 200

OP_TYPE =
    BLIP_INSERT: 0
    BLIP_DELETE: 1
    TEXT_INSERT: 2
    TEXT_DELETE: 3
    OTHER: 4
    EMPTY: 5

class Op
    @isTextOp: (op) -> op[ModelField.PARAMS][ParamsField.TYPE] is ModelType.TEXT

    @isBlipOp: (op) -> op[ModelField.PARAMS][ParamsField.TYPE] is ModelType.BLIP

    @getOpType: (op) ->
        switch
            when op.ti? and @isBlipOp(op) then OP_TYPE.BLIP_INSERT
            when op.ti? and @isTextOp(op) then OP_TYPE.TEXT_INSERT
            when op.td? and @isTextOp(op) then OP_TYPE.TEXT_DELETE
            else OP_TYPE.OTHER

    @getOpsType: (ops) ->
        ###
        Возвращает OP_TYPE.TEXT_INSERT, если все указанные операции являются операциями
                вставки текста.
        Возвращает OP_TYPE.TEXT_DELETE, если все указанные операции являются операциями
                вставки текста.
        Возвращает OP_TYPE.OTHER иначе
        ###
        return OP_TYPE.EMPTY if not ops.length
        firstOpType = @getOpType(ops[0])
        return OP_TYPE.OTHER if firstOpType is OP_TYPE.OTHER
        return OP_TYPE.BLIP_INSERT if firstOpType is OP_TYPE.BLIP_INSERT
        for op in ops[1..]
            opType = @getOpType(op)
            return OP_TYPE.OTHER if opType is OP_TYPE.OTHER or opType isnt firstOpType
        firstOpType

class BlipUndoRedo
    constructor: (@_blipViewModel, blipView) ->
        @_undoOps = []
        @_redoOps = []
        blipView.on('ops', @_addAndMergeUndoOps)
        @_blipViewModel.on('remote-ops', @_transformUndoRedoOps)

    _shouldMergeOps: (ops) ->
        ###
        Возвращает true, если указанные операции стоит объединить с последними
        сделанными для отмены
        @param ops: [ShareJS operations]
        @return: boolean
        ###
        return false if @_undoOps.length is 0
        curTime = (new Date()).getTime()
        return false if curTime > @_lastUndoGroupStartTime + UNDO_GROUP_TIMEOUT
        type = Op.getOpsType(ops)
        return false if type isnt OP_TYPE.TEXT_INSERT and type isnt OP_TYPE.TEXT_DELETE
        return false if type isnt @_lastUndoGroupType
        lastOps = @_undoOps[@_undoOps.length - 1]
        lastOp = lastOps[0]
        return true if not lastOp
        if type is OP_TYPE.TEXT_INSERT
            delta = lastOp.td.length
        else
            delta = -lastOp.ti.length
        return false if ops[0].p != lastOp.p + delta
        return true

    _shouldSkipOps: (ops) -> Op.getOpsType(ops) is OP_TYPE.BLIP_INSERT

    _addAndMergeUndoOps: (ops) =>
        if @_shouldSkipOps(ops)
            return @_transformUndoRedoOps(ops)
        @_redoOps = []
        if @_shouldMergeOps(ops)
            @_mergeUndoOps(ops)
        else
            @_addUndoOps(ops)
            @_lastUndoGroupType = Op.getOpsType(ops)
            @_lastUndoGroupStartTime = (new Date()).getTime()

    _addUndoOps: (ops) =>
        ###
        Добавляет новую группу undo-операций
        @param ops: [ShareJS operations]
        ###
        @_undoOps.push(FText.invert(ops))
        if @_undoOps.length > UNDO_OPERATION_LIMIT
            @_undoOps.shift()

    _mergeUndoOps: (ops) ->
        ###
        Сливает указанные операции с последней группой undo-операций
        @param ops: [ShareJS operations]
        ###
        lastOps = @_undoOps[@_undoOps.length-1]
        lastOps[0...0] = FText.invert(ops)

    _transformUndoRedoOps: (ops) =>
        @_transformOps(ops, @_undoOps)
        @_transformOps(ops, @_redoOps)

    _transformOps: (ops, blocks) ->
        ops = clone(ops)
        blocks.reverse()
        for block, i in blocks
            blocks[i] = FText.transform(block, ops, 'right')
            ops = FText.transform(ops, block, 'left')
        blocks.reverse()

    _addRedoOps: (ops) =>
        @_redoOps.push(FText.invert(ops))

    _applyUndoRedo: (ops, invertAction) ->
        ###
        Применяет операцию undo или redo, содержит общую логику по ожиданию
        загрузки блипов
        @param ops: @_undoOps || @_redoOps
        @param invertAction: @_addRedoOps || @_addUndoOps
        ###
        block = ops.pop()
        return if not block
        return @_applyUndoRedo(ops, invertAction) if not block.length
        @_blipViewModel.getModel().submitOps(block)
        @_blipViewModel.applyUndoRedoOps(block)
        invertAction(block)

    undo: ->
        ###
        Отменяет последнюю совершенную пользователем операцию, которую
        еще можно отменить
        ###
        @_applyUndoRedo(@_undoOps, @_addRedoOps)
        @_lastUndoGroupStartTime = 0

    redo: ->
        ###
        Повторяет последнюю отмененную операцию, если после нее не было простого
        ввода текста.
        ###
        @_applyUndoRedo(@_redoOps, @_addUndoOps)
        @_lastUndoGroupStartTime = 0

    hasUndoOps: ->
        ###
        Возвращает true, если есть undo-операции
        ###
        @_undoOps.length > 0

    hasRedoOps: ->
        ###
        Возвращает true, если есть redo-операции
        ###
        @_redoOps.length > 0

    destroy: ->
        delete @_undoOps
        delete @_redoOps
        @_blipViewModel.getView().removeListener('ops', @_addAndMergeUndoOps)
        @_blipViewModel.removeListener('remote-ops', @_transformUndoRedoOps)
        delete @_blipViewModel

module.exports = {BlipUndoRedo}
