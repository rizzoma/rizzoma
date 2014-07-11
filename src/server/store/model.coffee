_ = require('underscore')
Model = require('../common/model').Model
StoreError = require('./exceptions').StoreError
IdUtils = require('../utils/id_utils').IdUtils

{
    STORE_ITEM_STATE
    STORE_ITEM_CATEGORY_GADGET
    STORE_ITEM_CATEGORY_BROWSER_EXTENSION
} = require('../../share/constants')

class StoreItemModel extends Model
    ###
    Базовая модель позиции в магазине.
    ###
    constructor: (@_category=null) ->
        @id = IdUtils.getRandomId(32)
        @_title = null
        @_icon = null
        @_description = null
        @_topicUrl = null
        @_weight = 1 #Вес, определет положение позиции в выдаче.
        @_state = STORE_ITEM_STATE.STORE_ITEM_STATE_HIDDEN
        @_itemProperties = {}
        super('store_item')

    getId: () ->
        return @id

    getCategory: () ->
        return @_category

    getTitle: () ->
        return @_title

    setTitle: (value) ->
        return @_setPropertie('_title', value)

    getIcon: () ->
        return @_icon

    setIcon: (value) ->
        return @_setPropertie('_icon', value)

    getDescription: () ->
        return @_description

    setDescription: (value) ->
        return @_setPropertie('_description', value)

    getTopicUrl: () ->
        return @_topicUrl

    setTopicUrl: (value) ->
        return @_setPropertie('_topicUrl', value)

    getWeight: () ->
        return @_weight

    setWeight: (value) ->
        return @_setPropertie('_weight', parseInt(value, 10))

    setState: (value) ->
        value = parseInt(value, 10)
        return [new StoreError("Invalid item state: #{value}"), null]if value not in _.values(STORE_ITEM_STATE)
        return [null, @_setPropertie('_state', value)]

    getState: () ->
        return @_state

    isVisible: () ->
        return @_state == STORE_ITEM_STATE.STORE_ITEM_STATE_VISIBLE

    getInfo: () ->
        return {
            id: @getId()
            title: @getTitle()
            category: @getCategory()
            icon: @getIcon()
            description: @getDescription()
            topicUrl: @getTopicUrl()
            state: @getState()
            weight: @getWeight()
        }

    setItemProperties: (properies) ->
        return false

    _setPropertie: (name, value) ->
        return if not value or @[name] == value
        @[name] = value
        return true

    _setItemPropertiesFiled: (name, value) ->
        return if not value or @_itemProperties[name] == value
        @_itemProperties[name] = value
        return true

class GadgetModel extends StoreItemModel
    ###
    Модель гаджета.
    ###
    constructor: () ->
        super(STORE_ITEM_CATEGORY_GADGET)

    setItemProperties: (properies) ->
        url = properies.url
        return @_setItemPropertiesFiled('url', url)

    getInfo: () ->
        info = super()
        info.url = @_itemProperties.url
        return info


class BrowserExtensionModel extends StoreItemModel
    ###
    Модель браузерного расширения.
    ###
    constructor: () ->
        super(STORE_ITEM_CATEGORY_BROWSER_EXTENSION)

    setItemProperties: (properies) ->
        url = properies.url
        return @_setItemPropertiesFiled('url', url)

    getInfo: () ->
        info = super()
        info.url = @_itemProperties.url
        return info


relation = {}
relation[STORE_ITEM_CATEGORY_GADGET] = GadgetModel
relation[STORE_ITEM_CATEGORY_BROWSER_EXTENSION] = BrowserExtensionModel

storeItemFactory = (category) ->
    category = parseInt(category, 10)
    ItemClass = relation[category]
    return if ItemClass then new ItemClass() else null

module.exports.storeItemFactory = storeItemFactory