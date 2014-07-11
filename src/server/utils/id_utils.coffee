crypto = require('crypto')
Conf = require('../conf').Conf

DEFAULT_ID_LENGTH = 32

class IdUtils
    constructor: () ->
        conf = Conf.getGeneratorConf()
        @_delimiter = conf['delimiter']
        @_base = conf['base']
        @_prefix = conf['prefix']

    _getParts: (id) ->
        return id.split(@_delimiter)

    getOriginalId: (id) ->
        ###
        Возвращает числовую часть id в десятичной системы счисления.
        @param id: string
        @returns: string
        ###
        return null if typeof(id) != 'string'
        parts = @_getParts(id)
        return parseInt(parts.slice(-1)[0], @_base)

    parseId: (id) ->
        ###
        Разбирает id вида "prefix_type_id_extension1_extension2_..." на составляющие компоненты.
        @param id: string
        @returns: object
        ###
        parts = @_getParts(id)
        return {
            id: parts.splice(-1)[0]
            prefix: parts.shift()
            type: parts.shift()
            extensions: parts.join(@_delimiter)
        }

    getId: (type, sourceId) ->
        return @formatId(sourceId.toString(@_base), type)

    formatId: (id, type) ->
        return [@_prefix, type, id].join(@_delimiter)

    getRandomId: (length=DEFAULT_ID_LENGTH) ->
        return crypto.randomBytes(length).toString('hex')

module.exports.IdUtils = new IdUtils()
