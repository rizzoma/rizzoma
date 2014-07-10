async = require('async')

Conf = require('../conf').Conf
GDriveController = require('../gdrive/controller')
passport = require('passport')
app = require('./web_base').app
AuthError = require('../auth/exceptions').AuthError
Logger = Conf.getLogger('gDrive')
waveDriveUrl = Conf.getWaveDriveUrl()


_errorRedirect = (req, res, err) ->
    notice = 'auth_error'
    if err
        Logger.error('Error while authentication: ', err)
        notice = err.code if err instanceof AuthError
    else
        notice = 'auth_canceled'
    url = "/topic/?notice=#{notice}"
    res.redirect(url)

app.get /^\/drive-(open|create)$/, (req, res) ->
    try
        state = JSON.parse(req.query.state)
    catch e
        Logger.warn('Bad request', e)
        return  res.send(400)
    action = state.action

    passport.authenticate('google', {callbackURL: "/drive-#{req.params[0]}"}, (err, user) ->
        oauth = req.oauth
        {accessToken, refreshToken, profile} = oauth
        gUserId = profile?.id
        unless gUserId
            Logger.error("Didn't receive google user id")
            return res.send(500)
        tasks = [
            (callback) ->
                GDriveController.fillUserInfo(user, gUserId, accessToken, refreshToken, callback)
            (gDrivePermissionId, callback) ->
                req.login user, (err) ->
                    return _errorRedirect(req, res, err) if err
                    callback(null, gDrivePermissionId)
            (gDrivePermissionId, callback) ->
                switch action
                    when 'create'
                        folderId = state.folderId
                        GDriveController.createWave(user, profile, gDrivePermissionId, folderId, accessToken,
                                refreshToken, callback)
                    when 'open'
                        gDriveId = state.ids[0]
                        GDriveController.openWave(user, gUserId, gDriveId, gDrivePermissionId, accessToken,
                                refreshToken, callback)
                    else
                        callback("Unknown action")
        ]
        async.waterfall(tasks, (err, waveUrl) ->
            if err
                Logger.error("Drive action (#{action}) failed", {user, err})
                return res.send(500)
            res.redirect("#{waveDriveUrl}#{waveUrl}/#{if action is 'create' then '?enableEditMode=1' else ''}")
        )
    )(req, res, (err) ->
        return _errorRedirect(req, res, err)
    )
