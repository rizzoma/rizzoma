BaseModule = require('../../share/base_module').BaseModule
Response = require('../common/communication').ServerResponse
FileProcessor = require('./processor').FileProcessor

class FileModule extends BaseModule
    ###
    Модуль предоставляющей API для загрузки файлов.
    ###
    constructor: (args...) ->
        super(args..., Response)

    getFilesInfo: (request, args, callback) ->
        ###
        Обрабатывает запрос информации о файлах для их отображения в топике.
        @param request: Request
        ###
        FileProcessor.getFilesInfo(args.fileIds, callback)
    @::v('getFilesInfo', ['fileIds'])

module.exports.FileModule = FileModule
