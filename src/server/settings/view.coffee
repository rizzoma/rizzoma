{Conf} = require('../conf')
getStrategy = require('./helper').getStrategy
async = require('async')

settingsTemplate = Conf.getTemplate().compileFile('settings/index.html')

class SettingsView
    ###
    Основной view страницы настроек.
    ###
    constructor: () ->
        @_logger = Conf.getLogger('settings-view')
        @_views = [
            require('./notifications_view').NotificationsSettingsView
            require('./password_view').PasswordSettingsView
            require('./account_view').AccountSettingsView
            require('./storage_view').StorageSettingsView
            require('./team_view').TeamSettingsView
        ]

    render: (req, res) =>
        ###
        Отображает страницу.
        ###
        userDataStrategy = getStrategy(req)
        userDataStrategy.get(req, (err, user, profile, auths) =>
            @_getContext(err, req, user, profile, auths, (err, context) =>
                context.userBy = userDataStrategy.getName()
                res.send(settingsTemplate.render(context))
            )
        )

    _getContext: (err, req, user, profile, auths, callback) ->
        context = {}
        context.siteAnalytics = Conf.get('siteAnalytics')
        context.sessionId = req.sessionID
        context.sessionParams = req.session.settingsParams
        delete req.session.settingsParams
        if err
            context.error = if err.toClient then err.toClient() else err
        return callback(null, context) if not user
        tasks = []
        for view in @_views
            tasks.push(do(view) -> (callback) ->
                view.supplementContext(context, user, profile, auths, callback)
            )
        async.parallel(tasks, (err) ->
            callback(null, context)
        )

    route: (req, res) =>
        ###
        Перенаправляет запрос изменения настроек view соответствующей группы.
        ###
        return res.send(400) if not req.params or req.params.length < 2
        userDataStrategy = getStrategy(req)
        for view in @_views
            return if view.route(req, res, userDataStrategy)
        res.send(404)

module.exports.SettingsView = new SettingsView()