{BlipModel} = require('../blip/model')
ftextShareType = sharejs.types.ftext
jsonShareType = sharejs.types.json
{NO_MORE_OPERATIONS, SHOULD_LOAD_NEXT_PART} = require('./constants')

class PlaybackBlipModel extends BlipModel

    _init: (doc, waveId, isRead, title) ->
        super(doc, waveId, isRead, title)
        @_no_more_operations = false
        @_ops = []
        @_playbackPointer = -1

    getOpsCount: () ->
        return @_ops.length

    getLastOpDate: () ->
        return if @_ops.length == 0
        return new Date(@_ops[@_ops.length-1].meta.ts*1000)

    getCurrentDate: () ->
        return if @_ops.length == 0
        if @_playbackPointer < 0
            op = @_ops[0]
        else if @_playbackPointer == @_ops.length-1
            op = @_ops[@_ops.length-1]
        else
            op = @_ops[@_playbackPointer]
        return new Date(op.meta.ts*1000)

    appendOps: (ops) ->
        if not ops or ops.length == 0
            @_no_more_operations = true
            return
        @_ops = ops.concat(@_ops)
        @_playbackPointer += ops.length

    back: () ->
        return if @_playbackPointer < 0
        op = @_ops[@_playbackPointer]
        properType = if ftextShareType.isFormattedTextOperation(op.op[0]) then ftextShareType else jsonShareType
        invertedOp = properType.invert(op.op)
        @_doc._onOpReceived(@_convertOp(invertedOp))
        @_playbackPointer--

    forward: () ->
        return if @_playbackPointer == @_ops.length-1
        @_playbackPointer++
        op = @_ops[@_playbackPointer]
        @_doc._onOpReceived(@_convertOp(op.op))

    getPrevOp: (index) ->
        [err, op, index] = @_getPrevOp(index)
        [nextStepErr, nextStepOp, nextStepIndex] = @_getPrevOp(index)
        return [err, nextStepErr, op, index]

    _getPrevOp: (index) ->
        index = @_playbackPointer if not index?
        if index < 0
            if @_no_more_operations or @_ops.length == 0 or @_ops[0].v == 0
                return [NO_MORE_OPERATIONS, null]
            else
                return [SHOULD_LOAD_NEXT_PART, null]
        return [null, @_ops[index], index-1]

    getNextOp: (index) ->
        [err, op, index] = @_getNextOp(index)
        [nextStepErr, nextStepOp, nextStepIndex] = @_getNextOp(index)
        return [err, nextStepErr, op, index]

    _getNextOp: (index) ->
        index = @_playbackPointer + 1 if not index?
        return [NO_MORE_OPERATIONS, null] if index >= @_ops.length
        return [null, @_ops[index], index+1]

    _convertOp: (op) ->
        return {
            v: @_doc.version
            meta: {}
            doc: @id
            op: op
        }


module.exports = {PlaybackBlipModel}