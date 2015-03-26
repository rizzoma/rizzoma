{BlipModel} = require('../blip/model')
ftextShareType = sharejs.types.ftext
jsonShareType = sharejs.types.json

class PlaybackBlipModel extends BlipModel


    _init: (doc, waveId, isRead, title) ->
        super(doc, waveId, isRead, title)
        @_ops = []
        @_playbackPointer = -1

    getLastOpDate: () ->
        return if @_ops.length == 0
        return new Date(@_ops[@_ops.length-1].meta.ts*1000)

    appendOps: (ops) ->
        return if not ops.length
        @_ops = ops.concat(@_ops)
        @_playbackPointer += ops.length

    getCurrentDate: () ->
        return new Date(@_ops[@_playbackPointer].meta.ts*1000)

    back: () ->
        return [@_ops.length, null] if @_playbackPointer < 0
        op = @_ops[@_playbackPointer]
        properType = if ftextShareType.isFormattedTextOperation(op.op[0]) then ftextShareType else jsonShareType
        invertedOp = properType.invert(op.op)
        @_doc._onOpReceived(@_convertOp(invertedOp))
        @_playbackPointer--
        if @_playbackPointer < 0
            return [@_ops.length, null]
        else
            return [-1, @_ops[@_playbackPointer].meta.ts]

    forward: () ->
        return [true, null] if @_playbackPointer == @_ops.length-1
        @_playbackPointer++
        op = @_ops[@_playbackPointer]
        @_doc._onOpReceived(@_convertOp(op.op))
        if @_playbackPointer == @_ops.length-1
            return [true, op.meta.ts]
        else
            return [false, op.meta.ts]

    _convertOp: (op) ->
        return {
            v: @_doc.version
            meta: {}
            doc: @id
            op: op
        }


module.exports = {PlaybackBlipModel}