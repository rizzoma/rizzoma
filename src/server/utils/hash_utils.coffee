createHash = require('crypto').createHash

class HashUtls
    ###
    Класс утилит для работы с хэшами.
    ###
    constructor: () ->

    getSHA1Hash: (str) ->
        ###
        Вернет SHA1-хэш строки
        @param str: string
        @returns: string
        ###
        hash = createHash('sha1')
        hash.update(str)
        return hash.digest('hex')

module.exports.HashUtls = new HashUtls()