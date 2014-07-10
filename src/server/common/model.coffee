_ = require('underscore')
IdUtils = require('../utils/id_utils').IdUtils
DateUtils = require('../utils/date_utils').DateUtils
ACTUAL_FORMAT = require('./db/migration').Migration.getActualFormat()

class Model
    ###
    Представляет базовый класс модели.
    ###
    constructor: (@_type, @format=ACTUAL_FORMAT) ->

    getType: () ->
        return @_type

    getOriginalId: () ->
        return IdUtils.getOriginalId(@id)

    _setTimestampToNow: () ->
        @contentTimestamp = DateUtils.getCurrentTimestamp()

    markAsChanged: (changes, modelFields, processChanges) ->
        ###
        Выполняет действия необходимые при изменении контента модели:
        индексацию и действия заданные в дочерних моделях.
        @param canges: array
        @param modelFields: array
        @param processChanges: function
        ###
        if !!_.intersection(changes, modelFields).length
            processChanges()
            return true
        return false

    @isModel = true

module.exports.Model = Model
