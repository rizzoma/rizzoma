async = require('async')
Conf = require('../conf').Conf
logger = Conf.getLogger('file-cleaner')
FileCouchProcessor = require('./couch_processor').FileCouchProcessor
FileProcessor = require('./processor').FileProcessor

class FileCleaner
    _setFileAsNotFound: (id, callback) ->
        FileCouchProcessor.getById id, (err, file) =>
            return callback(err) if err
            if file.linkNotFound
                @_deleteFile(file, callback)
            else
                FileCouchProcessor.updateNotFoundFlag file, yes, (err, data) ->
                    return callback(err) if err
                    logger.info "marked #{id} as not found"
                    callback(null)

    _setFileAsFound: (id, callback) ->
        FileCouchProcessor.getById id, (err, file) ->
            return callback(err) if err
            FileCouchProcessor.updateNotFoundFlag file, no, (err, data) ->
                return callback(err) if err
                logger.info "marked #{id} as found"
                callback(null)

    _deleteFile: (file, callback) ->
        FileProcessor.deleteFile file, (err, data) =>
            return callback(err) if err
            FileCouchProcessor.setFileAsRemoved file, (err, res) ->
                return callback(err) if err
                logger.info "file #{file.id} was removed", data
                callback(null)

    _checkFile: (files, lastFileId, lastLinkId, lastFileNotFoundFlag) ->
        return if not lastFileId
        if lastFileId is lastLinkId
            files.push({fileId: lastFileId, found: yes}) if lastFileNotFoundFlag
        else
            files.push({fileId: lastFileId, found: no})

    _getFilesForProcessing: (files) ->
        lastFileId = null
        lastLinkId = null
        prevFileId = null
        currentId = null
        lastFileNotFoundFlag = no
        filesToProcess = [] # {fileId: string, found: boolean}
        for file in files
            currentId = file.key
            if prevFileId isnt currentId
                @_checkFile(filesToProcess, lastFileId, lastLinkId, lastFileNotFoundFlag)
                lastFileId = null
            prevFileId = currentId
            value = file.value
            if value.type is 'link'
                lastLinkId = currentId
            else
                lastFileId = currentId
                lastFileNotFoundFlag = file.value.linkNotFound
        @_checkFile(filesToProcess, lastFileId, lastLinkId, lastFileNotFoundFlag)
        return filesToProcess

    _processFiles: (file, callback) =>
        logger.info "processing file #{file.fileId}"
        if file.found
            @_setFileAsFound file.fileId, (err, res) ->
                if err
                    logger.error "Failed to set file as found #{file.fileId}", err
                callback(null) # always return good result to process all the files
        else
            @_setFileAsNotFound file.fileId, (err, res) ->
                if err
                    logger.error "Failed to set file as not found/deleted #{file.fileId}", err
                callback(null)

    run: (callback) ->
        logger.info "FileCleaner started #{(new Date()).toUTCString()}"
        FileCouchProcessor.getFilesForCompare (err, files) =>
            logger.error(err) if err
            return callback(err) if err
            filesToProcess = @_getFilesForProcessing(files)
            async.mapSeries filesToProcess, @_processFiles, (err, res) ->
                logger.info "FileCleaner finished #{(new Date()).toUTCString()}"
                logger.error(err) if err
                return callback(err) if err
                callback(null)

exports.FileCleaner = FileCleaner