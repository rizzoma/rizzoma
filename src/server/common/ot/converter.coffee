Converter = require('../converter').Converter

class OtConverter extends Converter
    ###
    Базовый конвертор моделей в OT-документы.
    ###
    constructor: () ->
        super()

    toClient: (model) ->
        ###
        Преобразуетй модель в документ для передачи sharejs на стороне клиента.
        ###
        otDoc = 
            v: model.version
            meta: {}
        return otDoc       


class DocumentOtConverter extends OtConverter
    constructor: () ->
        super()

    toClient: (model) ->
        doc = super(model)
        doc.open = true
        doc.snapshot = {}
        @_copyFields(doc.snapshot, model, @_snapshotFields)
        doc.meta.ts = model.contentTimestamp
        return doc

    toOt: (model) ->
        doc = {id: model.id, version: model.version}
        @_copyFields(doc, model, @_snapshotFields)
        return doc

module.exports =
    OtConverter: OtConverter
    DocumentOtConverter: DocumentOtConverter
