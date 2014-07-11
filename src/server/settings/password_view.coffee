async = require('async')
SettingsGroupView = require('./settings_group_view').SettingsGroupView
{AuthCouchProcessor} = require('../auth/couch_processor')
AuthUtils = require('../auth/utils').AuthUtils

{MIN_PASS_LENGTH} = require('../auth/password/views')

class PasswordSettingsView extends SettingsGroupView
    ###
    View группа настроек пароля.
    ###
    constructor: () ->
        super()

    getName: () ->
        return 'password'

    supplementContext: (context, user, profile, auths, callback) ->
        context.hasAuthByPassword = true if auths and AuthUtils.getPasswordAuth(auths) isnt null
        callback(null, context)

    update: (req, res, userDataStrategy) =>
        return if super(req, res)
        tasks = [
            async.apply(userDataStrategy.get, req)
            (user, profile, auths, callback) =>
                oldPassword = req.param('old_password')?.trim()
                newPassword = req.param('new_password')?.trim()
                return callback() if not oldPassword and not newPassword
                authId = req.param('auth_id')
                auth = AuthUtils.getPasswordAuth(auths, authId)
                return callback() if not auth
                return callback(new Error('Old password is wrong')) if not auth.isPasswordValid(oldPassword)
                return callback(new Error('New password is not set')) if not newPassword
                return callback(new Error("New password must be at least #{MIN_PASS_LENGTH} symbols long")) if newPassword.length < MIN_PASS_LENGTH
                action = (auth, callback) ->
                    auth.setPassword(newPassword)
                    callback(null, true, auth)
                AuthCouchProcessor.saveResolvingConflicts(auth, action, callback)
        ]
        async.waterfall(tasks, (err) =>
            @_sendResponse(res, err)
        )

module.exports.PasswordSettingsView = new PasswordSettingsView()
