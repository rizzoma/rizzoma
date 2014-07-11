params = require('../../share/model')
ExportMarkupNode = require('./common').ExportMarkupNode
PERFORMED_TASK = require('../task/constants').PERFORMED_TASK

class BlipExportMarkupBuilder

    _PAIRS: [
        ['url', params.TextLevelParams.URL],
        ['bold', params.TextLevelParams.BOLD],
        ['italic', params.TextLevelParams.ITALIC],
        ['struckthrough', params.TextLevelParams.STRUCKTHROUGH],
        ['underlined', params.TextLevelParams.UNDERLINED],
        ['bgColor', params.TextLevelParams.BG_COLOR]
    ]

    constructor: (id, timestamp, authorId) ->
        @_root = new ExportMarkupNode('reply',
            id: id
            timestamp: new Date(timestamp * 1000)
            author: authorId
            nodes: []
        )
        @_prev = null
        @_last = null
        
    _pushToLast: (node) ->
        @_last.nodes.push(node)

    _getLastList: (subtype, level) ->
        nodes = @_root.nodes
        if not nodes.length
            return null
        last = nodes[nodes.length - 1]
        if last.type isnt 'list'
            return null
        if last.subtype isnt subtype or last.level isnt level
            return null
        return last
        
    _getListStartValue: (subtype, level) ->
        for node in @_root.nodes.slice(0).reverse()
            if node.type isnt 'list' or node.subtype isnt subtype or node.level < level
                return 1
            if node.level is level
                return node.start + node.nodes.length
        return 1

    _handleListItem: (subtype, level) ->
        list = @_getLastList(subtype, level)
        if not list
            list = new ExportMarkupNode('list',
                subtype: subtype
                level: level
                nodes: []
            )
            if subtype is 'ordered'
                list.start = @_getListStartValue(subtype, level)
            @_root.nodes.push(list)
        node = new ExportMarkupNode('listItem', {nodes: []})
        list.nodes.push(node)
        @_last = node
        
    _handleLine: (block) ->
        level = block.params[params.LineLevelParams.BULLETED]
        if not isNaN(level)
            @_handleListItem('unordered', level)
            return
        level = block.params[params.LineLevelParams.NUMBERED]
        if not isNaN(level)
            @_handleListItem('ordered', level)
            return
        node = new ExportMarkupNode('paragraph', {nodes: []})
        @_root.nodes.push(node)
        @_last = node

    _getTextNode: (block) ->
        node = null
        current = node
        addTextNode = ->
            subnode = new ExportMarkupNode('text')
            if node is null
                node = subnode
            if current
                current.nodes = [subnode]
            return subnode
        for pair in @_PAIRS
            [attr, param] = pair
            if param of block.params
                subnode = addTextNode()
                subnode[attr] = block.params[param]
                current = subnode
        subnode = addTextNode()
        subnode.value = block.t
        return node

    _compareNodes: (a, b) ->
        for pair in @_PAIRS
            [attr, param] = pair
            if a[attr] isnt b[attr]
                return false
        return true
    
    _putTextNode: (nodes, node) ->
        if not nodes.length
            nodes.push(node)
            return
        last = nodes[nodes.length - 1]
        if last.type isnt 'text' or last.value
            nodes.push(node)
            return
        if not @_compareNodes(last, node)
            nodes.push(node)
            return
        @_putTextNode(last.nodes, node.nodes[0])
    
    _handleText: (block) ->
        node = @_getTextNode(block)
        @_putTextNode(@_last.nodes, node)

    _handleThreadBegin: () ->
        if @_last.type is 'thread'
            return
        node = new ExportMarkupNode('thread',
            folded: false
            nodes: []
        )
        @_last.nodes.push(node)
        @_prev = @_last
        @_last = node
        
    _handleThreadEnd: () ->
        if not @_last or @_last.type isnt 'thread'
            return
        @_last = @_prev
        
    _handleBlip: (block) ->
        node = new ExportMarkupNode('reply',
            id: block.params[params.ParamsField.ID]
        )
        @_last.nodes.push(node)

    _handleAttachment: (block) ->
        node = new ExportMarkupNode('attachment',
            url: block.params[params.ParamsField.URL]
        )
        @_last.nodes.push(node)

    _handleFile: (block) ->
        node = new ExportMarkupNode('file',
            id: block.params[params.ParamsField.ID]
        )
        @_last.nodes.push(node)

    _handleRecipient: (block) ->
        node = new ExportMarkupNode('recipient',
            user: block.params[params.ParamsField.ID]
        )
        @_last.nodes.push(node)

    _handleTask: (block) ->
        attrs =
            user: block.params.recipientId
            completed: block.params.status is PERFORMED_TASK
        if 'deadlineDate' of block.params
            attrs.deadline = new Date(block.params.deadlineDate)
            attrs.daylong = true
        if 'deadlineDatetime' of block.params
            attrs.deadline = new Date(block.params.deadlineDatetime * 1000)
        node = new ExportMarkupNode('task', attrs)
        @_last.nodes.push(node)

    _handleTag: (block) ->
        node = new ExportMarkupNode('tag',
            value: block.params[params.ParamsField.TAG]
        )
        @_last.nodes.push(node)

    _handleGadget: (block) ->
        node = new ExportMarkupNode('gadget',
            url: block.params[params.ParamsField.URL]
        )
        @_last.nodes.push(node)

    handleBlock: (type, block) =>
        if type is params.ModelType.BLIP
            @_handleThreadBegin()
            @_handleBlip(block)
        else
            @_handleThreadEnd()
        if type is params.ModelType.LINE
            @_handleLine(block)
        if type is params.ModelType.TEXT
            @_handleText(block)
        if type is params.ModelType.ATTACHMENT
            @_handleAttachment(block)
        if type is params.ModelType.FILE
            @_handleFile(block)
        if type is params.ModelType.RECIPIENT
            @_handleRecipient(block)
        if type is params.ModelType.TASK_RECIPIENT
            @_handleTask(block)
        if type is params.ModelType.TAG
            @_handleTag(block)
        if type is params.ModelType.GADGET
            @_handleGadget(block)

    build: ->
        return @_root

exports.BlipExportMarkupBuilder = BlipExportMarkupBuilder
