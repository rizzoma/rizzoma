_ = require('underscore')

class Converter
    ###
    Базовый класс конверторов.
    ###
    constructor: () ->
        ###
        Добавляемся к переданному классу модели.
        ###

    _extend: (src, des={}) ->
        return _.extend(src, des)

    _copyFields: (src, dst, correspondence) ->
        for srcField, dstField of correspondence
            src[srcField] = dst[dstField]

    _copyDefinedFields: (src, dst, correspondence) ->
        for dstField, srcField of correspondence
            if not _.isUndefined(dst[dstField])
                src[srcField] = dst[dstField]        

module.exports.Converter = Converter
