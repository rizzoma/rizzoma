fs = require('fs')
async = require('async')
Conf = require('../conf').Conf
FileModel = require('./model').FileModel
FileCouchProcessor = require('./couch_processor').FileCouchProcessor
FileStatus = require('../../share/file').FileStatus
logger = Conf.getLogger('file-processor')
FileConverter = require('./converter').FileConverter
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
FileError = require('../../share/file').Error

class FileProcessor
    constructor: ->
        @_init()
        @_storageProcessor = Conf.getStorageProcessor('files')

    _init: ->
        @_started = Date.now()
        @_count = 0
        @_pid = process.pid
        @_uploadedFiles = {}

    unlinkTmpFile: (path) ->
        ###
        Удаляет временный файл, первоначально загруженный пользователем на сервер.
        @param path: string
        ###
        fs.unlink(path, (err) ->
            logger.warn("Error while unlinking local file: #{err}") if err
        )

    getFilesInfo: (fileIds, callback) ->
        ###
        Возвращает данные о файлах.
        @param fileIds: array
        @param callback(err, {id: {status: string, data: object}}, ...): function
        ###
        res = {}
        dbFileIds = []
        for fileId in fileIds
            continue if fileId of res
            if fileId of @_uploadedFiles
                res[fileId] = {status: FileStatus.PROCESSING}
                continue
            res[fileId] = {status: FileStatus.ERROR}
            dbFileIds.push(fileId)
        FileCouchProcessor.getByIds(dbFileIds, (err, files) =>
            return callback(err) if err
            for file in files
                status = file.status
                res[file.id] = {status}
                res[file.id].data = file.getInfo() if status == FileStatus.READY
            callback(null, res)
        )

    getFileLink: (id, callback) =>
        ###
        Возвращает ссылку на файл на внешнем хранилиещ. По ней будет сделан редирект.
        ###
        FileCouchProcessor.getById(id, (err, file) =>
            callback(err, file, if err then null else @_storageProcessor.getLink(file.getStorageFilePath()))
        )


    getThumbnailLink: (id, callback) =>
        ###
        Возвращает ссылку на миниатюру на внешнем хранилиещ. По ней будет сделан редирект.
        ###
        FileCouchProcessor.getById(id, (err, file) =>
            callback(err, file, if err then null else @_storageProcessor.getLink(file.getStorageThumbnailPath()))
        )

    deleteFile: (file, callback) ->
        ###
        Удаляет файл и миниатюру с внешнего хранилища.
        @param file: FileModel
        @param callback: function
        ###
        tasks = [async.apply(@_storageProcessor.deleteFile, file.getStorageFilePath())]
        tasks.push(async.apply(@_storageProcessor.deleteFile, file.getStorageThumbnailPath())) if file.thumbnail
        async.series(tasks, (err, data) ->
            logger.error("Error while deleting file #{file.id} from external store #{err}") if err
            callback(err, data)
        )

    putFile: (user, id, path, name, type, size, callback) ->
        ###
        Загружает файл на внешнее хранилище, выполняет проверку на привышение квоты и сохраняет информацию о файле в бд.
        @param user: UserModel
        @param id: string - id для сохранения в бд, определяется клиентом.
        @param path: string - локальный путь к загруженному файлу
        @param name: string - имя файла
        @param type: string - MIME-тип
        @param size: int
        @param callback: function
        ###
        @_uploadedFiles[id] = yes
        tasks  = [
            async.apply(@_checkQuotaExcess, user, size)
            (callback) =>
                FileConverter.getThumbnail(path, type, {thumbnail: {width: '200', height: '150>'}}, (err, res) =>
                    file = new FileModel(id, user.id, @_getPath(), name, size, type, FileStatus.READY)
                    return callback(null, file, null, null) if err or not res?['thumbnail']
                    file.setTumbnail()
                    [tumbnailPath, tumbnailType] = res['thumbnail']
                    return callback(null, file, tumbnailPath, tumbnailType)

                )
            (file, tumbnailPath, tumbnailType, callback) =>
                @_putFile(file, path, tumbnailPath, tumbnailType, (err) ->
                    callback(err, file, tumbnailPath)
                )
            (file, tumbnailPath, callback) ->
                FileCouchProcessor.save(file, (err) ->
                    callback(err, file, tumbnailPath)
                )
        ]
        async.waterfall(tasks, (err, file, tumbnailPath) =>
            delete @_uploadedFiles[id]
            @unlinkTmpFile(path)
            @unlinkTmpFile(tumbnailPath) if tumbnailPath
            if err
                logger.error("Error while saving file to external store", {err: err, userId: user.id, fileId: id})
                err = 'Error occured. Please try again later.' if err.code != FileError.FILE_UPLOAD_LIMIT_EXCEEDED_ERROR
                return callback(err)
            logger.info("File #{id} sucessfully uploaded by user #{user.id}", {userId: user.id, fileId: id, name: name, type: type, size: size})
            callback(null, file)

        )
    _getPath: ->
        ###
        Генерирует путь к файлу во внешнем хранилище.
        @returns: string
        ###
        "#{@_started}-#{@_pid}/#{@_count++}/"

    _putFile: (file, path, tumbnailPath, tumbnailType, callback) ->
        ###
        Непосредственно загружает файл во внешнее хранилище.
        @param file: FileModel
        @param: string - локальный путь к файлу
        @param: tumbnailPath - локальный путь к миниатюре, если удалось создать
        @param: tumbnailType - MIME-тип миниатюры
        @param callback: function
        ###
        type = file.mimeType
        tasks = [async.apply(@_storageProcessor.putFile, path, file.getStorageFilePath(), type)]
        if file.thumbnail and tumbnailPath
            tasks.push(async.apply(@_storageProcessor.putFile, tumbnailPath, file.getStorageThumbnailPath(), tumbnailType))
        async.series(tasks, callback)

    _checkQuotaExcess: (user, size, callback) =>
        ###
        Проверяет, не привысит ли квоту пользователя загрузка файла.
        @param user: UserMOdel
        @param size: int - размер файла, который собираемся загрузить.
        @param callback: function
        ###
        @getRemainingSpace(user, (err, remainingSpace) ->
            return callback(err) if err
            err =
                msg: "You have reached the upload limit #{user.getUploadSizeLimit() / 1024 / 1024}MB."
                code: FileError.FILE_UPLOAD_LIMIT_EXCEEDED_ERROR
            return callback(if remainingSpace - size < 0 then err else null)
        )

    getRemainingSpace: (user, callback) ->
        ###
        Возвращает дисковое пространство в хранилище, доступное пользователю.
        @param user: UserModel
        @param callback(err, int): function
        ###
        tasks = [
            async.apply(UserCouchProcessor.getById, user.id)
            (user, callback) ->
                FileCouchProcessor.getFileSizeByUserIds(user.getAllIds(), (err, data) ->
                    return callback('Error while trying to get upload quota.') if err
                    try
                        totalUploaded = if data.length < 1 then 0 else data[0].value
                    catch e
                        logger.error("Error while trying to get upload quota: #{e}", {userId: user.id})
                        return callback('Error while trying to get upload quota.')
                    res = user.getUploadSizeLimit() - totalUploaded
                    return callback(null, if res < 0 then 0 else res)
                )
        ]
        async.waterfall(tasks, callback)

exports.FileProcessor = new FileProcessor()
