_ = require('underscore')
async = require('async')
im = require('imagemagick')
File = require('../../share/file')

###
{
  srcPath: undefined,
  srcData: null,
  srcFormat: null,
  dstPath: undefined,
  quality: 0.8,
  format: 'jpg',
  progressive: false,
  width: 0,
  height: 0,
  strip: true,
  filter: 'Lagrange',
  sharpening: 0.2,
  customArgs: []
}
###
Conf = require('../conf').Conf
logger = Conf.getLogger('file-converter')

class FileConverter

    getThumbnail: (path, type, sizes={} ,callback) =>
        ###
        Создает миниатюру для файла, если возможно.
        @param path: string - путь по которому находится оригинальный файл.
        @param type: sring - MIME-type фала
        @param sizes: {name: {width: string, height: string}} - словарь названий и размеров (указываются в фармате image magic)
        @param callback: function(err, {name: [path: string, type: string]}) - ключ название, значение [руть, тип] к миниатюре данного размера
        ###
        return callback(null, {}) if _.isEmpty(sizes)
        return callback(null, {}) if not @isImage(type)
        tasks = {}
        for own sizeName, size of sizes
            tasks[sizeName] = do(sizeName, size) =>
                return (callback) =>
                    [dst, thumbnailType] = @_getThumbnailPathAndType(path, sizeName, type)
                    src = if type == File.GIF_TYPE then "#{path}[0]" else path
                    options =
                        srcPath: src
                        dstPath: dst
                        height: size.height
                        width: size.width
                    im.resize(options, (err) ->
                        logger.error("Error while resizing #{err}") if err
                        callback(err, [dst, thumbnailType])
                    )
        async.parallel(tasks, callback)

    _getThumbnailPathAndType: (path, sizeName, type) ->
        ###
        Вощвращает путь к файлу в локальной фс.
        @param path: string
        @param sizeName: string
        @param type: string
        @returns: [path: string, type: string]
        ###
        path = "#{path}#{sizeName}"
        return ["#{path}.jpg", File.JPEG_TYPE] if type == File.JPEG_TYPE
        return ["#{path}.png", File.PNG_TYPE]

    isImage: (type) ->
        return type in File.BrowserSupportedImageTypes


exports.FileConverter = new FileConverter()