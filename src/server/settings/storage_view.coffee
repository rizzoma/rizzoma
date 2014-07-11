SettingsGroupView = require('./settings_group_view').SettingsGroupView
FileProcessor = require('../file/processor').FileProcessor

class StorageSettingsView extends SettingsGroupView
    ###
    View группа настроек хранилища.
    ###
    getName: () ->
        return 'storage'

    supplementContext: (context, user, profile, auths, callback) ->
        context.uploadSizeLimit = user.getUploadSizeLimit()
        FileProcessor.getRemainingSpace(user, (err, leftSpace) ->
            if not err
                context.usedSize = user.getUploadSizeLimit() - leftSpace
                context.leftSpace = leftSpace
            callback(null, context)
        )


module.exports.StorageSettingsView = new StorageSettingsView()
