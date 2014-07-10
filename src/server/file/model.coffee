Model = require('../common/model').Model

{
    REDIRECT_URL
    THUMBNAIL_REDIRECT_URL
} = require('./constants')

THUMBNAIL_NAME = 'thumbnail'


class FileModel extends Model
    constructor: (@id, @userId, @path, @name, @size, @mimeType, @status, @uploaded = Date.now()) ->
        ###
        Модель файла, прикрепленнного к блипу.
        @param path: string - путь к файлу в хранилище
        @param name: string - имя файла в хранилище
        ###
        super('file')
        @removed = no
        @linkNotFound = no
        @thumbnail = null #флаг, показывающий, есть ли миниатюра у файла.

    getStorageFilePath: () ->
        ###
        Возвращает URL файла в хранилище.
        ###
        return "#{@path}#{encodeURIComponent(@name)}"

    getStorageThumbnailPath: () ->
        ###
        Возвращает URL миниатюры файла в хранилище.
        ###
        return "#{@path}#{encodeURIComponent(THUMBNAIL_NAME)}"

    getInfo: () ->
        ###
        Возвращает информацию о файле дл передачи на клиент.
        @returns: object
        ###
        return {
            userId: @userId
            name: @name
            link: @_getFileLink()
            thumbnail: @_getThumbnailLink()
            mime: @mimeType
            size: @size
            removed: @removed
        }

    setTumbnail: () ->
        ###
        Устанавливает флаг "у файла есть миниатюра".
        ###
        @thumbnail = true

    _getFileLink: () ->
        ###
        Возвращает локальный URL по которому доступен файл.
        ###
        return "#{REDIRECT_URL}#{@id}"

    _getThumbnailLink: () ->
        ###
        Возвращает локальный URL по которому доступна миниатюра файла.
        ###
        return "#{THUMBNAIL_REDIRECT_URL}#{@id}" if @thumbnail

exports.FileModel = FileModel