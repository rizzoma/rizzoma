_ = require('underscore')
async = require('async')
crypto = require('crypto')
SettingsGroupView = require('./settings_group_view').SettingsGroupView
{Conf} = require('../conf')
{FileConverter} = require('../file/converter')
{AuthCouchProcessor} = require('../auth/couch_processor')
{UserController} = require('../user/controller')
AuthUtils = require('../auth/utils').AuthUtils

{
    PROFILE_FIELD_NAME
    PROFILE_FIELD_EMAIL
    PROFILE_FIELD_AVATAR
} = require('../../share/constants')

class AccountSettingsView extends SettingsGroupView
    ###
    View группа настроек аккаунта.
    ###
    constructor: () ->
        super()

    getName: () ->
        return 'account'

    supplementContext: (context, user, profile, auths, callback) ->
        return callback(null, context) if not profile
        context.profile = profile
        context.filtered = @_getFilteredProfile(profile)
        return callback(null, context) if not auths
        context.auths = {}
        context.auths[auth.getId()] = auth.getProfile() for auth in auths
        callback(null, context)

    _getFilteredProfile: (profile) ->
        reduce = (iterator) ->
            result = {}
            for authId, auth of profile
                value = iterator(auth)
                continue if not value or value in _.values(result)
                result[authId] = value
            return result
        return {
            names: reduce((auth) -> auth[PROFILE_FIELD_NAME])
            emails: reduce((auth) -> auth[PROFILE_FIELD_EMAIL])
            avatars: reduce((auth) -> auth[PROFILE_FIELD_AVATAR])
        }

    update: (req, res, userDataStrategy) =>
        return if super(req, res)
        tasks = [
            async.apply(userDataStrategy.get, req)
            (user, profile, auths, callback) =>
                name = req.param('account_name')?.trim()
                return callback(null, false, user, auths) if not name
                @_updateAccountName(auths, name, (err, useName) ->
                    callback(err, useName, user, auths)
                )
            (useName, user, auths, callback) =>
                avatar = req.files?.account_avatar
                return callback(null, useName, false, user, auths) if not avatar or not avatar.size
                @_updateAccountAvatar(user, auths, avatar, (err, useAvatar) ->
                    callback(err, useName, useAvatar, user, auths)
                )
            (useName, useAvatar, user, auths, callback) =>
                auth = AuthUtils.getPasswordAuth(auths)
                if useName
                    nameSource = auth.getId()
                else
                    nameSource = req.param('account_name_auth') or null
                emailSource = req.param('account_email_auth') or null
                if useAvatar
                    avatarSource = auth.getId()
                else
                    avatarSource = req.param('account_avatar_auth') or null
                return callback() if not nameSource and not emailSource and not avatarSource
                UserController.changeProfile(user, emailSource, nameSource, avatarSource, (err) =>
                    profile = AuthUtils.convertAuthListToProfile(auths)
                    callback(err, if err then null else @_getFilteredProfile(profile))
                )
        ]
        async.waterfall(tasks, (err, profile) =>
            @_sendResponse(res, err, profile)
        )

    _updateAccountName: (auths, name, callback) ->
        auth = AuthUtils.getPasswordAuth(auths)
        return callback(null, false) if not auth or auth.getName() is name
        action = (auth, callback) ->
            auth.setName(name)
            callback(null, true, auth)
        AuthCouchProcessor.saveResolvingConflicts(auth, action, (err) ->
            callback(err, !err)
        )

    _updateAccountAvatar: (user, auths, avatar, callback) ->
        auth = AuthUtils.getPasswordAuth(auths)
        return callback(null, false) if not auth
        return callback(new Error('Not an image')) if not FileConverter.isImage(avatar.type)
        tasks = [
            (callback) ->
                sizes = {normal: {width: '65', height: '65>^'}}
                FileConverter.getThumbnail(avatar.path, avatar.type, sizes, (err, result) ->
                    return callback(err) if err
                    [path, type] = result.normal
                    callback(null, path, type)
                )
            (path, type, callback) ->
                processor = Conf.getStorageProcessor('avatars')
                hash = crypto.createHash('md5').update("#{user.id}-#{auth.getId()}")
                storagePath = "avatars/#{hash.digest('hex')}"
                processor.putFile(path, storagePath, type, (err) ->
                    url = "#{processor.getLink(storagePath, true)}?#{(new Date()).getTime()}"
                    callback(err, url)
                )
            (url, callback) ->
                action = (auth, callback) ->
                    auth.setAvatar(url)
                    callback(null, true, auth)
                AuthCouchProcessor.saveResolvingConflicts(auth, action, callback)
        ]
        async.waterfall(tasks, (err) ->
            callback(err, !err)
        )

module.exports.AccountSettingsView = new AccountSettingsView()
