{MindMapNodeBlockBase} = require('./base')
{addClass} = require('../utils')

getMindMapNode = (args...) ->
    {MindMapNode} = require('../node')
    getMindMapNode = (args...) ->
        return new MindMapNode(args...)
    return getMindMapNode(args...)

class VirtualMindMapNodeBlock extends MindMapNodeBlockBase
    constructor: (@_mindmap, @_parent, @_content) ->
        super(@_mindmap, @_parent)

    _createDOMNodes: ->
        super()
        addClass(@_container, 'virtual')

    _getContent: -> @_content

    _getParagraphNode: (id, paragraphBlocks) ->
        return getMindMapNode(@_mindmap, null, paragraphBlocks, @, [])

    _updateParagraphNode: (node, paragraphBlocks) ->
        node.setTextBlocks(paragraphBlocks)

    isRoot: -> false


module.exports = {VirtualMindMapNodeBlock}
