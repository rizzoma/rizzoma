{MindMapThreadBase} = require('./base')
{VirtualMindMapNodeBlock} = require('../nodeblock/virtual')
{VIRTUAL_THREAD_LEFT_OFFSET, VIRTUAL_THREAD_TOP_OFFSET} = require('../const')

class VirtualMindMapThread extends MindMapThreadBase
    constructor: (@_mindmap, @_parent, content) ->
        super(@_mindmap, @_parent)
        @_createArrow()
        @_setContent(content)

    _createThreadContainer: (className) ->
        className += ' virtual'
        super(className)

    _setContent: (content) ->
        ###
        Устанавливает содержимое виртуального треда
        @param content: [blip data]
        ###
        @_blocks = []
        for data in content
            block = new VirtualMindMapNodeBlock(@_mindmap, @, data)
            @_blocks.push(block)
            @_blockContainer.appendChild(block.getContainer())

    isRoot: -> false

    _getSelfTopOffset: -> VIRTUAL_THREAD_TOP_OFFSET

    _getSelfLeftOffset: -> VIRTUAL_THREAD_LEFT_OFFSET


module.exports = {VirtualMindMapThread}