_ = require('underscore')
Converter = require('../converter').Converter
Migration = require('./migration').Migration

class CouchConverter extends Converter
    ###
    Класс, представляющий конвертор объектов БД.
    ###
    constructor: (@_factory) ->
        super()
        @_fieldNames =
            _id: 'id'
            _rev: '_rev'
            version: 'version'
            format: 'format'

    toCouch: (model) ->
        ###
        Конвертирует модель в требуемый для сохранения объект.
        @param model: object
        @returns: object
        ###
        doc = {}
        @_copyFields(doc, model, @_fieldNames)
        doc.type = model.getType()
        return doc

    toModel: (doc) ->
        ###
        Строит из докумета БД модель.
        @param doc: object
        @returns object
        ###
        doc = Migration.migrateFormat(doc)
        model  = @_getModelInstance(doc)
        @_copyDefinedFields(model, doc, @_fieldNames)
        return model

    _getModelInstance: (doc) ->
        return new @_factory() if @_factory.isModel
        return @_factory(doc)

    _extendFields: (fields={}) ->
        @_fieldNames = @_extend(@_fieldNames, fields)

module.exports.CouchConverter = CouchConverter
