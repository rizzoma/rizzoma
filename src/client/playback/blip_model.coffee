{BlipModel} = require('../blip/model')
ftextShareType = sharejs.types.ftext
jsonShareType = sharejs.types.json

class PlaybackBlipModel extends BlipModel


    _init: (doc, waveId, isRead, title) ->
        super(doc, waveId, isRead, title)
        @_ops = []
        @_playbackPointer = -1

    appendOps: (ops) ->
        return if not ops.length
        @_ops = ops.concat(@_ops)
        @_playbackPointer += ops.length

    back: () ->
        return @_ops.length if @_playbackPointer < 0
        op = @_ops[@_playbackPointer]
        properType = if ftextShareType.isFormattedTextOperation(op.op[0]) then ftextShareType else jsonShareType
        invertedOp = properType.invert(op.op)
        @_doc._onOpReceived(@_convertOp(invertedOp))
        @_playbackPointer--
        return -1

    forward: () ->
        return if @_playbackPointer == @_ops.length-1
        op = @_ops[@_playbackPointer+1]
        @_doc._onOpReceived(@_convertOp(op.op))
        @_playbackPointer++

    _convertOp: (op) ->
        return {
            v: @_doc.version
            meta: {}
            doc: @id
            op: op
        }


module.exports = {PlaybackBlipModel}