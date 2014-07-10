Request = require('../../share/communication').Request
FileStatus = require('../../share/file').FileStatus

class FileProcessor
    constructor: (args...) ->
        @_init(args...)

    _init: (@_rootRouter) ->
        exports.instance = @
        @_counter = 0
        @_files = {}
        @_timeout = null

    _hasFiles: (arr) ->
        for item in arr
            return yes if item
        no

    _getRemoteFilesInfo: =>
        fileIds = []
        for own fileId, info of @_files
            continue if info.requested
            fileIds.push(fileId)
            info.requested = yes
        return if not fileIds.length
        request = new Request {fileIds: fileIds}, (err, data) =>
            return console.error(err) if err
            for own fileId, fileInfo of data
                callbacks = @_files[fileId]?['callbacks']
                if callbacks
                    for callback in callbacks
                        ##TODO callback call
                        callback(fileInfo)
                status = fileInfo.status
                # uncomment and process file status change
                delete @_files[fileId]
#                if status is FileStatus.ERROR or status is FileStatus.READY
#                    fileIds = request.args.fileIds
#                    delete fileIds[fileIds.indexOf(fileId)]
#                    delete @_files[fileId]
#                    request.setProperty('wait', @_hasFiles(fileIds))
        request.setProperty('recallOnDisconnect', yes)
        # wait = true to wait file status change
        request.setProperty('wait', no)
        @_rootRouter.handle('network.file.getFilesInfo', request)

    getRandomId: (callback) ->
        request = new Request {}, (curWave) =>
            callback("#{curWave.getModel().getServerId()}-#{window.fileUuid}-#{@_counter++}-#{Math.random()}")
        @_rootRouter.handle('wave.getCurWave', request)

    getFilesInfo: (fileIds, callback) ->

    getFileInfo: (fileId, callback) ->
        @_files[fileId] ||= {}
        @_files[fileId]['callbacks'] ||= []
        @_files[fileId]['callbacks'].push(callback)
        if @_timeout?
            clearTimeout(@_timeout)
            @_timeout = null
        @_timeout = setTimeout(@_getRemoteFilesInfo, 1500)

exports.instance = null
exports.FileProcessor = FileProcessor