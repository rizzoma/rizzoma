PluginModel = require('../blip/plugin_model').PluginModel
GTAG_NODE = 'TAG'
GTAG_ATTR = '__TAG'
TAGS_EXISTS_TAG = "blipWithTags"

class GTagModel extends PluginModel
    ###
    Класс, представляющий базовую модель блипа.
    ###
    constructor: (blip) ->
        ###
        @param _blip: BlipModel
        ###
        super(blip)

    getName: () ->
        ###
        Возвращает имя плагина.
        ###
        return 'gtag'

    @getSearchIndexHeader: () ->
        ###
        Возвращает индексируемые поля для заголовка индекса.
        @returns: array
        ###
        return [
            {elementName: 'field', name: 'gtags'}
        ]

    getSearchIndex: () ->
        ###
        Возвращает индексируемые поля для индекса.
        @returns: array
        ###
        gtags = @_blip.getTypedContentBlocksParam(GTAG_NODE, GTAG_ATTR)
        gtags.push(TAGS_EXISTS_TAG) if gtags.length
        gtags = gtags.join(' ')
        return [{name: 'gtags', value: gtags}]

    getTextParams: () ->
        params = {}
        params[GTAG_NODE] = {attr: GTAG_ATTR, decorator: (text) -> return "##{text}"}
        return params

module.exports =
    GTagModel: GTagModel
    TAGS_EXISTS_TAG: TAGS_EXISTS_TAG
