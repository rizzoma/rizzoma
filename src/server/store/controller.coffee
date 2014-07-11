async = require('async')
StoreItemCouchProcessor = require('./couch_processor').StoreItemCouchProcessor
UserCouchProcessor = require('../user/couch_processor').UserCouchProcessor
storeItemFactory = require('./model').storeItemFactory
StoreError = require('./exceptions').StoreError

class StoreController
    constructor: () ->

    addItem: (category, title, icon, description, topicUrl, weight, itemProperties, callback) ->
        ###
        Добавляет позицию.
        @param category: int
        @param title: string
        @param icon: string
        @param description: string
        @param description: string
        @param weight: int
        @param itemProperties: object
        @param callback: function
        ###
        item = storeItemFactory(category)
        return callback(new StoreError("Invalid item category #{category}")) if not item
        @_editItem(item, title, icon, description, topicUrl, weight, itemProperties, callback)

    changeItemState: (id, state, callback) ->
        ###
        Активирует/деактивирует показ позиции.
        @param id: string
        @param state: int
        @param callback: function
        ###
        StoreItemCouchProcessor.getById(id, (err, item) =>
            return callback(err) if err
            action = (item, callback) ->
                [err, changed] = item.setState(state)
                callback(err, changed, item, false)
            @_saveItem(item, action, callback)
        )

    editItem: (id, title, icon, description, topicUrl, weight, itemProperties, callback) ->
        ###
        Изменяет свойства позиции.
        @param id: string
        @param title: string
        @param icon: string
        @param description: string
        @param description: string
        @param weight: int
        @param itemProperties: object
        @param callback: function
        ###
        StoreItemCouchProcessor.getById(id, (err, item) =>
            return callback(err) if err
            @_editItem(item, title, icon, description, topicUrl, weight, itemProperties, callback)
        )

    _editItem: (item, title, icon, description, topicUrl, weight, itemProperties, callback) ->
        action = (item, callback) ->
            changed = false
            changed = item.setTitle(title) or changed
            changed = item.setIcon(icon) or changed
            changed = item.setDescription(description) or changed
            changed = item.setTopicUrl(topicUrl) or changed
            changed = item.setWeight(weight) or changed
            changed = item.setItemProperties(itemProperties) or changed
            callback(null, changed, item, false)
        @_saveItem(item, action, callback)

    _saveItem: (item, action, callback) ->
        StoreItemCouchProcessor.saveResolvingConflicts(item, action, (err) ->
            callback(err, if err then null else item.getInfo())
        )

    getFullItemList: (state, callback) ->
        ###
        Возвращает полный список позиций в той или иной категории.
        Позиции отсартированы  по убыванию веса.
        @param state: int - если не задан, будут возвращены позиции со всеми статусами.
        @param category: int - если не задан, будут возвращены позиции всех категорий.
        ###
        StoreItemCouchProcessor.getItemsByCategory(state, (err, items) ->
            return callback(err) if err
            callback(null, (item.getInfo() for item in items))
        )

    getItemsInfo: (ids, callback) ->
        ###
        Возвращает информацию о позиция.
        @param ids: array
        @param callback: function
        ###
        StoreItemCouchProcessor.getByIdsAsDict(ids, (err, items) =>
            return callback(err) if err
            infoById = {}
            for own id, item of items when item.isVisible()
                infoById[id] = item.getInfo()
            callback(null, infoById)
        )

module.exports.StoreController = new StoreController()
