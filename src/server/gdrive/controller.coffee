async = require('async')
googleapis = require('googleapis')
Conf = require('../conf').Conf
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
WaveController = require('../wave/controller').WaveController
ROLES = require('../wave/constants').ROLES
SuperUser = new (require('../user/model').SuperUserModel)('GDriveSuperUser')
UserModel = require('../user/model').UserModel
DEFAULT_TITLE = 'Untitled topic'

googleConf = Conf.getAuthSourceConf('google')
Logger = Conf.getLogger('gDrive-controller')

gDriveConf = Conf.getGDriveConf()
REFRESH_TOKEN = gDriveConf.gDriveRefreshToken
UPDATE_INTERVAL = gDriveConf.updateInterval * 1000
CACHE_PATH = gDriveConf.cachePath
DOCS_TO_UPDATE = {}

class GDriveController
    constructor: ->
        @_init()
        @_storageProcessor = Conf.getStorageProcessor('files')

    @getOauth2Client: (accessToken, refreshToken) ->
        oauth2Client =
            new googleapis.auth.OAuth2(googleConf.clientID, googleConf.clientSecret, '');
        oauth2Client.credentials =
            access_token: accessToken
            refresh_token: refreshToken
        oauth2Client

    @getRoleByPermission: (permission) ->
        ###
        permission.role || 'owner', 'writer', 'reader'
        permission.additionalRoles = [ 'commenter' ],
        ###
        switch permission.role
            when 'owner', 'writer'
                ROLES.ROLE_EDITOR
            else
                additionalRoles = permission.additionalRoles
                if additionalRoles && additionalRoles.indexOf('commenter') != -1
                    ROLES.ROLE_PARTICIPANT
                else
                    ROLES.ROLE_READER

    _init: ->
        @_gDriveApiClient = null

    _getDriveApiClient: (callback) ->
        return callback(null, @_gDriveApiClient) if @_gDriveApiClient
        options = { cache: { path: CACHE_PATH }}
        googleapis.discover('drive', 'v2').withOpts(options).execute (err, client) ->
            return callback(err) if err
            callback(null, @_gDriveApiClient = client)

    fillUserInfo: (user, gUserId, accessToken, refreshToken, callback) ->
        userData = user.gDrive?.ids?[gUserId] || {}
        userData.accessToken = accessToken
        userData.refreshToken = refreshToken if refreshToken
        tasks = [
            @_getDriveApiClient
            (client, callback) =>
                return callback(null) if userData.permissionId and userData.rootFolderId
                driveAboutCallback = (err, data) ->
                    return callback(err) if err
                    userData.permissionId = data.permissionId
                    userData.rootFolderId = data.rootFolderId
                    callback(null)

                client.drive.about.get().withAuthClient(GDriveController.getOauth2Client(accessToken, refreshToken))
                        .execute(driveAboutCallback)
            (callback) ->
                Logger.warn("User #{user.id} does not have refreshToken") unless userData.refreshToken
                action = (user, callback) ->
                    user.gDrive ||= {}
                    user.gDrive.ids ||= {}
                    user.gDrive.ids[gUserId] = userData
                    callback(null, true, user, false)
                UserCouchProcessor.saveResolvingConflicts(user, action, callback)
        ]
        async.waterfall tasks, (err) ->
            return callback(err) if err
            callback(null, userData.permissionId)

    createWave: (user, gUserProfile, gDrivePermissionId, folderId, accessToken, refreshToken, callback) ->
        ###
        @returns (err, waveUrl)
        ###
        gDriveParentId = user.gDrive.ids[gUserProfile.id].rootFolderId
        tasks = [
            @_getDriveApiClient
            (client, callback) =>
                Logger.info("Inserting file GDrive document for #{user.id}")
                client.drive.files.insert({title: DEFAULT_TITLE, mimeType: 'application/vnd.google-apps.drive-sdk'})
                    .withAuthClient(GDriveController.getOauth2Client(null, REFRESH_TOKEN))
                    .execute (err, arg1) ->
                        callback(err, client, arg1)
            (client, data, callback) ->
                driveDocId = data.id
                email = gUserProfile._json.email
                Logger.info("Adding permissions to GDrive doc #{driveDocId} for user #{email} (#{user.id})")
                body = {role: 'writer', type: 'user', value: email}
                client.drive.permissions.insert({fileId: driveDocId, sendNotificationEmails: no}, body)
                    .withAuthClient(GDriveController.getOauth2Client(null, REFRESH_TOKEN))
                    .execute (err) ->
                        callback(err, client, driveDocId)
            (client, driveDocId, callback) ->
                Logger.info("Move document to My Drive Folder (#{user.id})")
                client.drive.parents.insert({fileId: driveDocId}, {id: folderId || gDriveParentId})
                    .withAuthClient(GDriveController.getOauth2Client(accessToken, refreshToken))
                    .execute (err) ->
                        Logger.warn("Failed to move doc (#{driveDocId}) to root folder for user (#{user.id})") if err
                        callback(null, driveDocId)
            (driveDocId, callback) ->
                Logger.info("Create wave by GDrive id #{driveDocId}")
                WaveController.createWaveByGDrive(user, driveDocId, gDrivePermissionId, '', callback)
        ]
        async.waterfall(tasks, callback)

    openWave: (user, gUserId, gDriveDocId, gDrivePermissionId, accessToken, refreshToken, callback) ->
        ###
        @returns (err, waveUrl)
        ###
        tasks = [
            @_getDriveApiClient
            (client, callback) =>
                client.drive.permissions.get({fileId: gDriveDocId, permissionId: 'me'})
                    .withAuthClient(GDriveController.getOauth2Client(accessToken, refreshToken))
                    .execute (err, data) ->
                        callback(err, data)
            (permission, callback) ->
                WaveController.getWaveByGDriveId gDriveDocId, (err, wave) ->
                    return callback(err) if err
                    callback(null, permission, wave)
            (permission, wave, callback) ->
                return callback(null, permission, wave) unless permission.role in ['owner', 'writer']
                WaveController.addWaveGDrivePermission wave, user, gDrivePermissionId, ->
                    callback(null, permission, wave)
            (permission, wave, callback) ->
                participant = wave.getParticipant(user)
                url = wave.getUrl()
                driveRole = GDriveController.getRoleByPermission(permission)
                if participant and participant.hasRole()
                    return callback(no, url) if driveRole >= participant.role
                    Logger.info("Change participant #{participant.id} role from #{participant.role} to #{driveRole}")
                    WaveController.changeParticipantsRole url, SuperUser, [participant.id], driveRole, (err) ->
                        return callback(err) if err
                        return callback(no, url)
                else
                    Logger.info("Add participant #{user.id} with role #{driveRole}")
                    WaveController.addParticipantsEx url, SuperUser, [user.getNormalizedEmail()], driveRole, no, (err) ->
                        return callback(err) if err
                        callback(null, url)
        ]
        async.waterfall(tasks, callback)

    _executeGDriveDocUpdate: (gDriveDocId, title, tokens, callback) ->
        tasks = [
            @_getDriveApiClient
            (client, callback) ->
#                body = { modifiedDate: (new Date()).toISOString() }
                body = {}
                body.title = title if title
                client.drive.files.patch({fileId: gDriveDocId, fields: 'id,modifiedDate'}, body)
                    .withAuthClient(GDriveController.getOauth2Client(tokens.accessToken, tokens.refreshToken))
                    .execute(callback)
#                client.drive.files.touch({fileId: gDriveDocId, setModifiedDate: true, fields: 'id,modifiedDate'}, body)
#                    .withAuthClient(GDriveController.getOauth2Client(tokens.accessToken, tokens.refreshToken))
#                    .execute( (err, results) ->
#                        console.log('drive files execute results', err, results)
#                        callback(err, results)
#                    )
        ]
        async.waterfall(tasks, callback)

    _getUserByPermissions: (userId, wavePermissions, callback) ->
        if wavePermissions.length
            UserCouchProcessor.getById(userId, callback)
        else
            callback(null, new UserModel(userId))

    _realUpdateGDriveDoc: (waveId, updateObj) -> #(gDriveDocId, wavePermissions, user, title, callback) ->
        return unless updateObj
        wavePermissions = updateObj.gDrivePermissions
        gDriveDocId = updateObj.gDriveDocId
        Logger.info("Starting to update gDriveDoc (#{gDriveDocId}) fo wave (#{waveId})")
        tasks = [
            (callback) =>
                @_getUserByPermissions(updateObj.userId, wavePermissions, callback)
            (user, callback) =>
                permissions = []
                for wavePermission in wavePermissions
                    permissions = permissions.concat(user.getDriveInfoByPermissionId(wavePermission))
                Logger.info("User #{user.id} has #{permissions.length} permission(s) in wave (#{waveId})")
                permissions.push({accessToken: null, refreshToken: REFRESH_TOKEN})
                title = updateObj.title
                updateGDriveDoc = =>
                    return callback("Error") unless permissions.length
                    tokens = permissions.shift()
                    @_executeGDriveDocUpdate gDriveDocId, title, tokens, (err) ->
                        return callback(null) unless err
                        updateGDriveDoc()
                updateGDriveDoc()
        ]
        async.waterfall tasks, (err) ->
            if err
                Logger.warn("Failed to update gDriveDoc (#{gDriveDocId}) for wave (#{waveId})", err)
            else
                Logger.info("Successfully updated gDriveDoc (#{gDriveDocId}) for wave (#{waveId})", err)

    _updateGDriveDoc: (wave, userId, title) ->
        waveId = wave.id
        updateObj = DOCS_TO_UPDATE[waveId] || {}
        updateObj.title = title if title
        updateObj.userId = userId
        updateObj.gDrivePermissions = wave.gDrivePermissions[userId] || []
        if not updateObj.gDriveDocId
            updateObj.gDriveDocId = wave.gDriveId
            setTimeout do(waveId) =>
                f = =>
                    obj = DOCS_TO_UPDATE[waveId]
                    @_realUpdateGDriveDoc(waveId, obj)
                    delete DOCS_TO_UPDATE[waveId]
                f
            , UPDATE_INTERVAL
        DOCS_TO_UPDATE[waveId] = updateObj

    updateWave: (blip, user) ->
        wave = blip.getWave()
        return unless wave.gDriveId
        title = null
        if wave.rootBlipId is blip.id
            title = blip.getTitle() || DEFAULT_TITLE
        @_updateGDriveDoc(wave, user.id, title)


module.exports = new GDriveController()
