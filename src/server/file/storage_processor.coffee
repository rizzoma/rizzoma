NotImplementedError = require('../../share/exceptions').NotImplementedError

class StorageProcessor
    ###
    Интерфейс процессара, работающего с API внешнего хранилища файлов.
    ###
    putFile: () ->
        ###
        Загружает файл на хранилище.
        ###
        throw new NotImplementedError()

    deleteFile: () ->
        ###
        Удаляет файл с хранилища.
        ###
        throw new NotImplementedError()

    getLink: (notProtected=false) ->
        ###
        Возвращает ссылку к файлу
        @protected: boolean - вернуть защищенную ссылку (если поддерживается API), если передан
        ###

module.exports.StorageProcessor = StorageProcessor
