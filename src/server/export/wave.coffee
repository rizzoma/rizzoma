Conf = require('../conf').Conf
ExportMarkupNode = require('./common').ExportMarkupNode

class WaveExportMarkupBuilder

    constructor: (@_wave, @_users, @_blips, @_files, @_params) ->

    _getUserById: (id) ->
        for user in @_users
            return user if user.isEqual(id)
        return null

    _getUserInfoById: (id, needFullInfo) ->
        if not id or not (user = @_getUserById(id))
            user = {name: '(unknown)', email: '(unknown)'}
        info = {name: user.name}
        if user.avatar
            info.avatar = user.avatar
        if needFullInfo
            info.email = user.email
        return info

    _getContainerBlip: ->
        for blip in @_blips
            if blip.isContainer
                return blip
        return null

    _getBlipById: (id) ->
        for blip in @_blips
            if blip.id is id
                return blip
        return null

    _getWaveUrl: ->
        return "#{Conf.get('baseUrl')}#{Conf.getWaveUrl()}#{@_wave.getUrl()}/"

    _getWaveTitle: ->
        return @_getBlipById(@_wave.rootBlipId)?.getTitle()

    _getRootNode: ->
        root = new ExportMarkupNode('topic',
            url: @_getWaveUrl()
            title: @_getWaveTitle()
        )
        container = @_getContainerBlip()
        root.nodes = if container then container.getExportMarkup().nodes[0].nodes else []
        return root
        
    _injectThread: (node) ->
        replies = node.nodes
        node.folded = replies[0].folded
        for reply in replies
            delete reply.folded

    _injectReply: (node) ->
        blip = @_getBlipById(node.id)
        return if not blip
        for key, value of blip.getExportMarkup()
            node[key] = value
        node.author = @_getUserInfoById(node.author, @_params.needFullUserInfo)
        # Это свойство нужно для определения свернутости группы блипов и будет удалено позже:
        node.folded = blip.isFoldedByDefault

    _getFileUrl: (url) ->
        return if url then "#{Conf.get('baseUrl')}#{url}" else null

    _injectFile: (node) ->
        if node.id not of @_files
            return
        file = @_files[node.id]
        delete node.id
        if not file.data
            return
        node.name = file.data.name
        preview = @_getFileUrl(file.data.thumbnail)
        if preview
            node.preview = preview
        node.url = @_getFileUrl(file.data.link)

    _injectRecipient: (node) ->
        node.user = @_getUserInfoById(node.user, @_params.needFullUserInfo)

    _injectStuff: (node) ->
        if node.type is 'reply'
            @_injectReply(node)
        if node.type is 'file'
            @_injectFile(node)
        if node.type in ['recipient', 'task']
            @_injectRecipient(node)
        children = node.nodes
        if not children
            return
        for child in children
            @_injectStuff(child)
        # Обязательно делать после обработки нижележащих нод,
        # чтобы информация о блипах загрузилась:
        if node.type is 'thread'
            @_injectThread(node)

    build: ->
        root = @_getRootNode()
        @_injectStuff(root)
        return root

exports.WaveExportMarkupBuilder = WaveExportMarkupBuilder
