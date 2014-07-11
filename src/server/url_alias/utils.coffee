HashUtls = require('../utils/hash_utils').HashUtls
IdUtils = require('../utils/id_utils').IdUtils

DELIMITER = require('../conf').Conf.getGeneratorConf().delimiter

class  UrlAliasUtils
    constructor: () ->

    getId: (id, owner) ->
        ###
        Возвращает внутренний id, пригодный для сохранения в бд.
        @param id: string
        @param owner: string
        ###
        hash = HashUtls.getSHA1Hash(id) #во избежании недопустимых для id в бд символов возьмем хэш
        return IdUtils.formatId(hash, ['a', owner].join(DELIMITER))

module.exports.UrlAliasUtils = new UrlAliasUtils()
