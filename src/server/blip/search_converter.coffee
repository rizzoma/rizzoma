ltx = require('ltx')

class BlipSearchConverter
    ###
    Конвертор, преобразующий блип для поискового индекса.
    ###
    constructor: () ->

    fromFieldsToIndexHeader: (fields) ->
        xml = new ltx.Element('sphinx:schema')
        for field in fields
            elementName = "sphinx:#{field.elementName}"
            delete field['elementName']
            xml.c(elementName, field).up()
        return xml
        
    fromFieldsToIndex: (id, fields) ->
        xml = new ltx.Element('sphinx:document', {id: id})
        for field in fields
            xml.c(field.name).t(field.value or '').up()
        return xml
        
module.exports.BlipSearchConverter = new BlipSearchConverter()
