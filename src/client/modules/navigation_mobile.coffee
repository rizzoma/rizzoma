BaseModule = require('../../share/base_module').BaseModule
NavigationPanel = require('../navigation/mobile').NavigationPanel
Request = require('../../share/communication').Request

class Navigation extends BaseModule
    constructor: (@_rootRouter) ->
        throw new Error('Module Navigation should be inited once') if module.exports.instance?
        module.exports.instance = @
        super(@_rootRouter)
        @_panelContainer = $('#navigation-panel')[0]
        @_panel = new NavigationPanel(@_panelContainer)
        
    updateTopicsUnreadCount: (request, args, callback) =>
        @_panel.updateTopicsUnreadCount(args.waveId,
                                        args.unreadCount,
                                        args.totalCount)

    updateBlipIsRead: (request, args, callback) =>
        @_panel.updateBlipIsRead(args.waveId, args.blipId, args.isRead)
        
    findNextUnreadTopic: (request) ->

    updateTaskInfo: (request) ->
        @_panel.getTasksPanel()?.updateTaskInfo(request.args.taskInfo)

module.exports =
    Navigation: Navigation
    instance: null
